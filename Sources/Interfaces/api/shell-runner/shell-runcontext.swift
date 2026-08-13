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
            let quote: (String) -> String = {
                value in

                value.isEmpty
                    ? "''"
                    : "'"
                        + value.replacingOccurrences(
                            of: "'",
                            with: "'\"'\"'"
                        )
                        + "'"
            }

            let rendered = (
                [
                    launchPath,
                ] + argv
            )
            .map(
                quote
            )
            .joined(
                separator: " "
            )

            return redactions.reduce(
                rendered
            ) {
                accumulated,
                needle in

                guard !needle.isEmpty else {
                    return accumulated
                }

                return accumulated
                    .replacingOccurrences(
                        of: needle,
                        with: "‹redacted›"
                    )
            }
        }
    }
}
