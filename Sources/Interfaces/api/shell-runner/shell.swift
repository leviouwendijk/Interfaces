import Foundation

public struct Shell: Sendable {
    // public enum Error: Swift.Error, Sendable, LocalizedError {
    //     case launchFailure(String)
    //     case timedOut(after: TimeInterval, pid: pid_t)
    //     case nonZeroExit(code: Int, stdoutPreview: String, stderrPreview: String, result: Result)

    //     public var errorDescription: String? {
    //         switch self {
    //         case .launchFailure(let m): return "Shell launch failure: \(m)"
    //         case .timedOut(let t, let pid): return "Shell timeout after \(t)s (pid \(pid))."
    //         case .nonZeroExit(let c, let outPrev, let errPrev, _):
    //             let body = errPrev.isEmpty ? outPrev : errPrev
    //             return "Shell exited with code \(c). Output: \(body)"
    //         }
    //     }
    // }

    public let exec: Exec
    public init(_ exec: Exec = .zsh) { self.exec = exec }

    @discardableResult
    public func run(
        _ programOrLauncher: String,
        _ args: [String] = [],
        options: Options = .init()
    ) async throws -> Result {
        let (launcher, prefix) = exec.launchPathAndArgsPrefix
        let launchPath: String
        let argv: [String]
        if case .path = exec {
            launchPath = programOrLauncher
            argv = args
        } else {
            launchPath = launcher
            let command = quoteForShell(programOrLauncher, redactions: options.redactions)
                + " " + args.map { quoteForShell($0, redactions: options.redactions) }.joined(separator: " ")
            argv = prefix + [command]
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = argv
        if let cwd = options.cwd { process.currentDirectoryURL = cwd }

        var env = options.inheritEnvironment ? ProcessInfo.processInfo.environment : [:]
        for (k, v) in options.env { env[k] = v }
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let data = options.stdin {
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            try process.run()
            if !data.isEmpty { stdinPipe.fileHandleForWriting.write(data) }
            try? stdinPipe.fileHandleForWriting.close()
        } else {
            try process.run()
        }

        let pid = process.processIdentifier
        let start = Date()

        // Concurrently read stdout/stderr as they arrive (async, no locks).
        async let outData: Data = readAll(
            from: stdoutPipe.fileHandleForReading,
            tee: options.teeToStdout ? .stdout : nil,
            onChunk: options.onStdoutChunk
        )

        async let errData: Data = readAll(
            from: stderrPipe.fileHandleForReading,
            tee: options.teeToStderr ? .stderr : nil,
            onChunk: options.onStderrChunk
        )

        // Await completion (or timeout / cancellation)
        try await waitForExit(process, timeout: options.timeout)

        let duration = Date().timeIntervalSince(start)

        let status: ExitStatus = {
            switch process.terminationReason {
            case .exit:           return .exited(Int(process.terminationStatus))
            case .uncaughtSignal: return .signaled(Int(process.terminationStatus))
            @unknown default:     return .exited(Int(process.terminationStatus))
            }
        }()

        let result = Result(
            status: status,
            pid: pid,
            launchedPath: launchPath,
            argv: argv,
            duration: duration,
            stdout: await outData,
            stderr: await errData
        )

        // if case .exited(let code) = status, !options.expectedExitCodes.contains(code) {
        //     let sErr = result.stderrText()
        //     let sOut = result.stdoutText()
        //     let previewSource = sErr.isEmpty ? sOut : sErr
        //     let preview = String(previewSource.prefix(400))
        //     throw Error.nonZeroExit(code: code, stderrPreview: preview, result: result)
        // }

        if case .exited(let code) = status, !options.expectedExitCodes.contains(code) {
            // Redact env values using the same redactions list
            let redact = { (s: String) -> String in
                options.redactions.reduce(s) { acc, needle in acc.replacingOccurrences(of: needle, with: "‹redacted›") }
            }
            var envShown: [String:String] = [:]
            for (k, v) in env { envShown[k] = redact(v) }

            let ctx = RunContext(
                exec: self.exec,
                launchPath: launchPath,
                argv: argv,
                cwd: options.cwd?.path,
                inheritEnvironment: options.inheritEnvironment,
                env: envShown,
                timeout: options.timeout,
                expectedExitCodes: options.expectedExitCodes,
                teeToStdout: options.teeToStdout,
                teeToStderr: options.teeToStderr,
                redactions: options.redactions,
                duration: duration,
                pid: pid
            )

            let sOut = result.stdoutText()
            let sErr = result.stderrText()

            let outPrev = String(sOut.prefix(400))
            let errPrev = String(sErr.prefix(400))

            throw Error.nonZeroExit(
                code: code,
                stdoutPreview: outPrev,
                stderrPreview: errPrev,
                result: result,
                context: ctx
            )
        }
        return result
    }

    private func readAll(
        from fh: FileHandle,
        tee: Tee?,
        onChunk: (@Sendable (Data) -> Void)?
    ) async -> Data {
        var buffer = Data()
        do {
            while let chunk = try fh.read(upToCount: 64 * 1024), !chunk.isEmpty {
                buffer.append(chunk)
                switch tee {
                case .stdout?: FileHandle.standardOutput.write(chunk)
                case .stderr?: FileHandle.standardError.write(chunk)
                case nil: break
                }
                onChunk?(chunk)
                await Task.yield()
                if Task.isCancelled { break }
            }
        } catch { /* ignore partial read errors */ }
        return buffer
    }

    private enum Tee { case stdout, stderr }

    private func waitForExit(_ process: Process, timeout: TimeInterval?) async throws {
        // Race process termination with timeout and task cancellation
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Swift.Error>) in
                    process.terminationHandler = { _ in cont.resume() }
                }
            }
            if let t = timeout, t > 0 {
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(t * 1_000_000_000))
                    if process.isRunning {
                        process.terminate()
                        // give it a moment; then kill if still alive
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        if process.isRunning { process.kill() }
                    }
                    throw Error.timedOut(after: t, pid: process.processIdentifier)
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 0) // allow cancellation check
                if Task.isCancelled {
                    if process.isRunning {
                        process.terminate()
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        if process.isRunning { process.kill() }
                    }
                    throw CancellationError()
                }
            }

            // First task to finish wins; cancel the others.
            do {
                try await group.next()  // one finishes (or throws)
                group.cancelAll()
                // Drain any thrown timeout/cancel if it fired first
                while let _ = try? await group.next() {}
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }

    private func quoteForShell(_ s: String, redactions: [String]) -> String {
        let redacted = redactions.reduce(s) { acc, needle in acc.replacingOccurrences(of: needle, with: "‹redacted›") }
        if redacted.isEmpty { return "''" }
        return "'" + redacted.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}

private extension Process {
    func kill() {
        #if os(macOS) || os(Linux)
        _ = Darwin.kill(self.processIdentifier, SIGKILL)
        #endif
    }
}

// @inline(__always)
// private func runBlocking<T>(
//     _ body: @escaping () async throws -> T
// ) throws -> T {
//     let sema = DispatchSemaphore(value: 0)
//     var result: Result<T, Error>!

//     Task.detached(priority: .userInitiated) {
//         do {
//             let value = try await body()
//             result = .success(value)
//         } catch {
//             result = .failure(error)
//         }
//         sema.signal()
//     }

//     sema.wait()
//     return try result.get()
// }
