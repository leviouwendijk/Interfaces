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
                private var stdoutData = Data()
                private var stderrData = Data()
                private var timedOut = false

                func appendStdout(
                    _ data: Data
                ) {
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

                    timedOut = true
                }

                func result(
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

                    let code = Int32(
                        process.terminationStatus
                    )

                    if timedOut {
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
                        code,
                        out,
                        err
                    )
                }
            }

            let state = State()
            let group = DispatchGroup()

            group.enter()
            DispatchQueue.global(
                qos: .userInitiated
            )
            .async {
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                state.appendStdout(
                    data
                )
                group.leave()
            }

            group.enter()
            DispatchQueue.global(
                qos: .userInitiated
            )
            .async {
                let data = stderr.fileHandleForReading.readDataToEndOfFile()
                state.appendStderr(
                    data
                )
                group.leave()
            }

            group.enter()
            DispatchQueue.global(
                qos: .userInitiated
            )
            .async {
                process.waitUntilExit()
                group.leave()
            }

            let timer = DispatchSource.makeTimerSource(
                queue: DispatchQueue.global(
                    qos: .userInitiated
                )
            )

            timer.schedule(
                deadline: .now() + timeout
            )

            timer.setEventHandler {
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

            group.notify(
                queue: DispatchQueue.global(
                    qos: .userInitiated
                )
            ) {
                timer.cancel()

                let result = state.result(
                    process: process,
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
                timer.resume()
            } catch {
                timer.cancel()

                continuation.resume(
                    throwing: error
                )
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
