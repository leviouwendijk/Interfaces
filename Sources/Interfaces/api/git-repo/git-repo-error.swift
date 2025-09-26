import Foundation

extension GitRepo {
    public enum Error: Swift.Error, LocalizedError, Sendable {
        case noUpstreamConfigured
        case invalidRevListOutput(raw: String)

        public var errorDescription: String? {
            switch self {
            case .noUpstreamConfigured:
                return "No upstream configured for the current branch."
            case .invalidRevListOutput(let raw):
                return "Unexpected output from `git rev-list --left-right --count HEAD...@{u}`: \(raw)"
            }
        }
    }

    enum RemoteError: Swift.Error, LocalizedError, Sendable {
        case noOrigin
        case headNotResolvable(String)
        case fileMissing(String)
        case processFailed(Int32, String)
        case badURL(String)

        public var errorDescription: String? {
            switch self {
            case .noOrigin:
                return "No 'origin' remote configured."
            case .headNotResolvable(let s):
                return "Could not resolve origin/HEAD: \(s)"
            case .fileMissing(let p):
                return "Remote file not found: \(p)"
            case .processFailed(let code, let err):
                return "git exited with \(code): \(err)"
            case .badURL(let u):
                return "Invalid URL: \(u)"
            }
        }
    }
}
