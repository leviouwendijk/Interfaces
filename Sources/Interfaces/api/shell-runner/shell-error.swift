import Foundation
import plate

public extension Shell {
    enum Error: Swift.Error, Sendable, LocalizedError {
        case launchFailure(String)
        case timedOut(after: TimeInterval, pid: pid_t)
        case nonZeroExit(
            code: Int,
            stdoutPreview: String,
            stderrPreview: String,
            result: Result,
            context: RunContext
        )

        public var errorDescription: String? {
            switch self {
            case .launchFailure(let m):
                return "Shell launch failure: \(m)"
            case .timedOut(let t, let pid):
                return "Shell timeout after \(t)s (pid \(pid))."
            case .nonZeroExit(let c, let outPrev, let errPrev, _, _):
                let body = errPrev.isEmpty ? outPrev : errPrev
                return "Shell exited with code \(c). Output: \(body)"
            }
        }

        public func pretty(maxPreviewBytes: Int = 4000) -> String {
            switch self {
            case .launchFailure, .timedOut:
                return self.errorDescription ?? String(describing: self)

            case .nonZeroExit(let code, _, _, let result, let ctx):
                func clamp(_ s: String) -> String {
                    if s.utf8.count <= maxPreviewBytes { return s }
                    let end = s.index(s.startIndex, offsetBy: maxPreviewBytes, limitedBy: s.endIndex) ?? s.endIndex
                    return String(s[..<end]) + "… [truncated]"
                }

                let kv = { (k: String, v: String) in "    \(k): \(v)\n" }
                var out = ""
                out += "✗ Exit code: \(code)\n"
                out += kv("PID", "\(ctx.pid)")
                out += kv("Duration", String(format: "%.3fs", ctx.duration))
                out += kv("Exec", "\(ctx.exec)")
                out += kv("CWD", ctx.cwd ?? "(nil)")
                out += kv("Inherit env", String(ctx.inheritEnvironment))
                out += kv("Timeout", ctx.timeout.map { "\($0)s" } ?? "(nil)")
                out += kv("Expected exit codes", ctx.expectedExitCodes.sorted().map(String.init).joined(separator: ","))
                out += kv("Tee stdout", String(ctx.teeToStdout))
                out += kv("Tee stderr", String(ctx.teeToStderr))
                out += kv("Redactions", ctx.redactions.isEmpty ? "(none)" : ctx.redactions.joined(separator: ","))
                out += "\n— Launcher & Args —\n"
                out += "  \(ctx.commandLine)\n"
                out += "\n— Environment (redacted values) —\n"
                if ctx.env.isEmpty {
                    out += "  (empty)\n"
                } else {
                    for key in ctx.env.keys.sorted() {
                        // out += "  \(key)=\(ctx.env[key]!)\n"
                        out += "  \(key)=<redacted>\n"
                    }
                }
                out += "\n— Stdout —\n"
                out += clamp(result.stdoutText()) + "\n"
                out += "\n— Stderr —\n"
                out += clamp(result.stderrText()) + "\n"
                return out
            }
        }
    }
}
