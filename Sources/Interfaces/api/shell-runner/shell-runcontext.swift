import Foundation

public extension Shell {
    struct RunContext: Sendable {
        public let exec: Shell.Exec
        public let launchPath: String
        public let argv: [String]
        public let cwd: String?
        public let inheritEnvironment: Bool
        public let env: [String: String]
        public let timeout: TimeInterval?
        public let expectedExitCodes: Set<Int>
        public let teeToStdout: Bool
        public let teeToStderr: Bool
        public let redactions: [String]
        public let duration: TimeInterval
        public let pid: pid_t

        @inlinable public var commandLine: String {
            let q: (String) -> String = { s in s.isEmpty ? "''" : "'" + s.replacingOccurrences(of: "'", with: "'\"'\"'") + "'" }
            return ([launchPath] + argv).map(q).joined(separator: " ")
        }
    }
}
