import Darwin
import Foundation
import plate

public enum GitRepo {
    @discardableResult
    public static func git(
        _ cwd: URL,
        _ args: [String],
        timeout: TimeInterval = 60
    ) async throws -> (code: Int32, out: String, err: String) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(
                fileURLWithPath: "/usr/bin/env"
            )
            process.arguments = [
                "git",
            ] + args
            process.currentDirectoryURL = cwd

            var environment = ProcessInfo.processInfo.environment
            environment["GIT_TERMINAL_PROMPT"] = "0"
            environment["GIT_EDITOR"] = "true"
            environment["GIT_PAGER"] = "cat"
            environment["LC_ALL"] = environment["LC_ALL"] ?? "C"

            process.environment = environment

            let stdout = Pipe()
            let stderr = Pipe()

            process.standardInput = FileHandle.nullDevice
            process.standardOutput = stdout
            process.standardError = stderr

            final class State: @unchecked Sendable {
                private let lock = NSLock()

                private var didResume = false
                private var didTimeOut = false
                private var stdoutData = Data()
                private var stderrData = Data()

                func appendStdout(
                    _ data: Data
                ) {
                    guard !data.isEmpty else {
                        return
                    }

                    lock.lock()
                    defer {
                        lock.unlock()
                    }

                    stdoutData.append(
                        data
                    )
                }

                func appendStderr(
                    _ data: Data
                ) {
                    guard !data.isEmpty else {
                        return
                    }

                    lock.lock()
                    defer {
                        lock.unlock()
                    }

                    stderrData.append(
                        data
                    )
                }

                func markTimedOut() {
                    lock.lock()
                    defer {
                        lock.unlock()
                    }

                    didTimeOut = true
                }

                func finish(
                    process: Process,
                    args: [String],
                    timeout: TimeInterval
                ) -> (shouldResume: Bool, code: Int32, out: String, err: String) {
                    lock.lock()
                    defer {
                        lock.unlock()
                    }

                    guard !didResume else {
                        return (
                            false,
                            0,
                            "",
                            ""
                        )
                    }

                    didResume = true

                    let out = String(
                        data: stdoutData,
                        encoding: .utf8
                    ) ?? ""

                    var err = String(
                        data: stderrData,
                        encoding: .utf8
                    ) ?? ""

                    if didTimeOut {
                        let rendered = "git " + args.joined(
                            separator: " "
                        )

                        let timeoutMessage = "Timed out after \(Int(timeout))s: \(rendered)"

                        if err.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .isEmpty {
                            err = timeoutMessage
                        } else {
                            err += "\n\(timeoutMessage)"
                        }
                    }

                    return (
                        true,
                        Int32(
                            process.terminationStatus
                        ),
                        out,
                        err
                    )
                }
            }

            let state = State()

            stdout.fileHandleForReading.readabilityHandler = { handle in
                state.appendStdout(
                    handle.availableData
                )
            }

            stderr.fileHandleForReading.readabilityHandler = { handle in
                state.appendStderr(
                    handle.availableData
                )
            }

            process.terminationHandler = { finishedProcess in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil

                state.appendStdout(
                    stdout.fileHandleForReading.availableData
                )

                state.appendStderr(
                    stderr.fileHandleForReading.availableData
                )

                let result = state.finish(
                    process: finishedProcess,
                    args: args,
                    timeout: timeout
                )

                guard result.shouldResume else {
                    return
                }

                continuation.resume(
                    returning: (
                        result.code,
                        result.out,
                        result.err
                    )
                )
            }

            do {
                try process.run()
            } catch {
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil

                continuation.resume(
                    throwing: error
                )

                return
            }

            DispatchQueue.global(
                qos: .userInitiated
            )
            .asyncAfter(
                deadline: .now() + timeout
            ) {
                guard process.isRunning else {
                    return
                }

                state.markTimedOut()
                process.terminate()

                DispatchQueue.global(
                    qos: .userInitiated
                )
                .asyncAfter(
                    deadline: .now() + 2
                ) {
                    guard process.isRunning else {
                        return
                    }

                    kill(
                        process.processIdentifier,
                        SIGKILL
                    )
                }
            }
        }
    }

    public static func gitOut(
        _ cwd: URL,
        _ args: [String],
        timeout: TimeInterval = 60
    ) async throws -> String {
        let (code, out, err) = try await git(
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

// public enum GitRepo {
//     @discardableResult
//     public static func git(_ cwd: URL, _ args: [String]) async throws -> (code: Int32, out: String, err: String) {
//         let res = try await sh(.zsh, "git", args, cwd: cwd)
//         let out = res.stdoutText()
//         let err = res.stderrText()
//         return (Int32(res.exitCode ?? 0), out, err)
//     }

//     public static func gitOut(_ cwd: URL, _ args: [String]) async throws -> String {
//         let (code, out, err) = try await git(cwd, args)
//         guard code == 0 else { throw RemoteError.processFailed(code, err) }
//         return out
//     }
// }
