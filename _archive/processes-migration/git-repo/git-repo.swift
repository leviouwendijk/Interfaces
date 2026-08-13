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
            process.standardInput = FileHandle.nullDevice

            let token = UUID().uuidString
            let temporaryDirectory = FileManager.default.temporaryDirectory

            let stdoutURL = temporaryDirectory.appendingPathComponent(
                "gm-\(token)-stdout.txt"
            )

            let stderrURL = temporaryDirectory.appendingPathComponent(
                "gm-\(token)-stderr.txt"
            )

            FileManager.default.createFile(
                atPath: stdoutURL.path,
                contents: nil
            )

            FileManager.default.createFile(
                atPath: stderrURL.path,
                contents: nil
            )

            let stdoutHandle: FileHandle
            let stderrHandle: FileHandle

            do {
                stdoutHandle = try FileHandle(
                    forWritingTo: stdoutURL
                )

                stderrHandle = try FileHandle(
                    forWritingTo: stderrURL
                )
            } catch {
                try? FileManager.default.removeItem(
                    at: stdoutURL
                )

                try? FileManager.default.removeItem(
                    at: stderrURL
                )

                continuation.resume(
                    throwing: error
                )

                return
            }

            process.standardOutput = stdoutHandle
            process.standardError = stderrHandle

            final class State: @unchecked Sendable {
                private let lock = NSLock()
                private var didResume = false
                private var didTimeOut = false

                func markTimedOut() {
                    lock.lock()

                    defer {
                        lock.unlock()
                    }

                    didTimeOut = true
                }

                func finish() -> (shouldResume: Bool, didTimeOut: Bool) {
                    lock.lock()

                    defer {
                        lock.unlock()
                    }

                    guard !didResume else {
                        return (
                            false,
                            didTimeOut
                        )
                    }

                    didResume = true

                    return (
                        true,
                        didTimeOut
                    )
                }
            }

            let state = State()

            @Sendable
            func cleanup() {
                try? stdoutHandle.close()
                try? stderrHandle.close()

                try? FileManager.default.removeItem(
                    at: stdoutURL
                )

                try? FileManager.default.removeItem(
                    at: stderrURL
                )
            }

            @Sendable
            func readFile(
                _ url: URL
            ) -> String {
                guard let data = try? Data(
                    contentsOf: url
                ) else {
                    return ""
                }

                return String(
                    data: data,
                    encoding: .utf8
                ) ?? ""
            }

            process.terminationHandler = { finishedProcess in
                try? stdoutHandle.close()
                try? stderrHandle.close()

                let result = state.finish()

                guard result.shouldResume else {
                    cleanup()

                    return
                }

                let out = readFile(
                    stdoutURL
                )

                var err = readFile(
                    stderrURL
                )

                if result.didTimeOut {
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

                cleanup()

                continuation.resume(
                    returning: (
                        Int32(
                            finishedProcess.terminationStatus
                        ),
                        out,
                        err
                    )
                )
            }

            do {
                try process.run()
            } catch {
                let result = state.finish()

                cleanup()

                guard result.shouldResume else {
                    return
                }

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
