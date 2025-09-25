import Foundation

public struct Shell: Sendable {
    public enum Exec: Sendable {
        case env, sh, bash, zsh
        case path(String)

        var launchPathAndArgsPrefix: (path: String, args: [String]) {
            switch self {
            case .env:   return ("/usr/bin/env", [])
            case .sh:    return ("/bin/sh",   ["-lc"])
            case .bash:  return ("/bin/bash", ["-lc"])
            case .zsh:   return ("/bin/zsh",  ["-lc"])
            case .path(let p): return (p, [])
            }
        }
    }

    public struct Options: Sendable {
        public var cwd: URL? = nil
        public var inheritEnvironment: Bool = true
        public var env: [String:String] = [:]
        public var stdin: Data? = nil
        public var timeout: TimeInterval? = nil
        public var expectedExitCodes: Set<Int> = [0]
        public var teeToStdout: Bool = false
        public var teeToStderr: Bool = false
        public var redactions: [String] = []
        // callbacks
        public var onStdoutChunk: (@Sendable (Data) -> Void)? = nil
        public var onStderrChunk: (@Sendable (Data) -> Void)? = nil

        public init() {}
    }

    public enum ExitStatus: Sendable, Equatable {
        case exited(Int)
        case signaled(Int)
    }

    public struct Result: Sendable {
        public let status: ExitStatus
        public let pid: pid_t
        public let launchedPath: String
        public let argv: [String]
        public let duration: TimeInterval
        public let stdout: Data
        public let stderr: Data

        public var exitCode: Int? { if case .exited(let c) = status { return c } else { return nil } }
        public func stdoutText(_ enc: String.Encoding = .utf8) -> String {
            String(data: stdout, encoding: enc) ?? String(decoding: stdout, as: UTF8.self)
        }
        public func stderrText(_ enc: String.Encoding = .utf8) -> String {
            String(data: stderr, encoding: enc) ?? String(decoding: stderr, as: UTF8.self)
        }
    }

    public enum Error: Swift.Error, Sendable, LocalizedError {
        case launchFailure(String)
        case timedOut(after: TimeInterval, pid: pid_t)
        case nonZeroExit(code: Int, stderrPreview: String, result: Result)

        public var errorDescription: String? {
            switch self {
            case .launchFailure(let m):          return "Shell launch failure: \(m)"
            case .timedOut(let t, let pid):      return "Shell timeout after \(t)s (pid \(pid))."
            case .nonZeroExit(let c, let prev, _): return "Shell exited with code \(c). Stderr: \(prev)"
            }
        }
    }

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

        if case .exited(let code) = status, !options.expectedExitCodes.contains(code) {
            let preview = result.stderrText().prefix(400)
            throw Error.nonZeroExit(code: code, stderrPreview: String(preview), result: result)
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
