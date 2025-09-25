import Foundation

public extension Shell {
    struct Result: Sendable {
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

        public var prettyCommandLine: String {
            let q: (String) -> String = { s in
                s.isEmpty ? "''" : "'" + s.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
            }
            return ([launchedPath] + argv).map(q).joined(separator: " ")
        }

        public var shortSummary: String {
            let code = exitCode.map(String.init) ?? "-"
            return "✓ exit=\(code)  time=\(String(format: "%.3fs", duration))"
        }
    }
}
