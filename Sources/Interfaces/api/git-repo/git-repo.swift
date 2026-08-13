import Darwin
import Foundation
import plate
import Processes

public enum GitRepo {
    @discardableResult
    public static func git(
        _ cwd: URL,
        _ args: [String],
        timeout: TimeInterval = 60
    ) async throws -> (
        code: Int32,
        out: String,
        err: String
    ) {
        let output =
            GitProcessOutputRecorder()

        var environment:
            [String: String?] = [
                "GIT_TERMINAL_PROMPT": "0",
                "GIT_EDITOR": "true",
                "GIT_PAGER": "cat",
            ]

        if ProcessInfo
            .processInfo
            .environment[
                "LC_ALL"
            ] == nil
        {
            environment[
                "LC_ALL"
            ] = "C"
        }

        let timeoutDuration =
            Duration.nanoseconds(
                Int64(
                    max(
                        0,
                        timeout
                    )
                    * 1_000_000_000
                )
            )

        do {
            let result = try await ProcessRunner().run(
                .init(
                    executable: .path(
                        "/usr/bin/env"
                    ),
                    arguments: [
                        "git",
                    ] + args,
                    workingDirectory: cwd,
                    environment:
                        .inheritedUpdating(
                            environment
                        ),
                    input: .none,
                    io: .pipes,
                    outputLimit: .max,
                    timeout: timeoutDuration,
                    terminationPolicy: .init(
                        gracefulShutdownTimeout:
                            .seconds(
                                2
                            ),
                        isolateProcessGroup:
                            true
                    )
                ),
                onStdout: { chunk in
                    await output.appendStdout(
                        chunk
                    )
                },
                onStderr: { chunk in
                    await output.appendStderr(
                        chunk
                    )
                }
            )

            return (
                legacyTerminationStatus(
                    result.exit
                ),
                result.stdoutText,
                result.stderrText
            )
        } catch let error as ProcessError {
            guard case .timedOut =
                error
            else {
                throw error
            }

            let captured =
                await output.snapshot()

            let out = String(
                data: captured.stdout,
                encoding: .utf8
            ) ?? ""

            var err = String(
                data: captured.stderr,
                encoding: .utf8
            ) ?? ""

            let rendered =
                "git "
                + args.joined(
                    separator: " "
                )

            let timeoutMessage =
                "Timed out after \(Int(timeout))s: \(rendered)"

            if err.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty {
                err = timeoutMessage
            } else {
                err +=
                    "\n\(timeoutMessage)"
            }

            return (
                Int32(
                    SIGTERM
                ),
                out,
                err
            )
        }
    }

    public static func gitOut(
        _ cwd: URL,
        _ args: [String],
        timeout: TimeInterval = 60
    ) async throws -> String {
        let (
            code,
            out,
            err
        ) = try await git(
            cwd,
            args,
            timeout: timeout
        )

        guard code == 0 else {
            throw RemoteError.processFailed(
                code,
                err
            )
        }

        return out
    }
}

private extension GitRepo {
    static func legacyTerminationStatus(
        _ exit: ProcessExit
    ) -> Int32 {
        switch exit {
        case .exited(
            let code
        ):
            return code

        case .signaled(
            let signal
        ):
            return signal
        }
    }
}

private actor GitProcessOutputRecorder {
    private var stdout = Data()
    private var stderr = Data()

    func appendStdout(
        _ chunk: Data
    ) {
        stdout.append(
            chunk
        )
    }

    func appendStderr(
        _ chunk: Data
    ) {
        stderr.append(
            chunk
        )
    }

    func snapshot() -> (
        stdout: Data,
        stderr: Data
    ) {
        (
            stdout,
            stderr
        )
    }
}
