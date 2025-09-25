import Foundation

public extension Shell {
    struct Options: Sendable {
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
}
