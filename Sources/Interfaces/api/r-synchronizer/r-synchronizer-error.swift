import Foundation
import plate

public enum RSynchronizerError: Error, LocalizedError, Sendable, PrettyError {
    case commandFailed(commandLine: String, exitCode: Int)
    case hookFailed(hookLine: String, exitCode: Int)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(_, let code):
            return "rsync failed (exit \(code))"
        case .hookFailed(_, let code):
            return "post-sync hook failed (exit \(code))"
        }
    }

    public func formatted() -> String {
        switch self {
        case .commandFailed(let line, let code):
            return """
            ✖ rsync failed
                \(line)
                exit: \(code)
            """.ansi(.red)

        case .hookFailed(let line, let code):
            return """
            ✖ post-sync hook failed
                \(line)
                exit: \(code)
            """.ansi(.red)
        }
    }
}
