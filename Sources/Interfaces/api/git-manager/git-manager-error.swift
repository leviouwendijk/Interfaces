import Foundation

public enum GitManagerError: Error, LocalizedError, Sendable {
    case missingDirectory(String)
    case missingCommitMessage
    case notGitRepository(String)
    case noUpstream(String)
    case unsafeSync(String)
    case resetRequiresHardUpstream
    case gitFailed(command: [String], code: Int32, stderr: String)

    public var errorDescription: String? {
        switch self {
        case .missingDirectory(let path):
            return "Missing directory: \(path)"

        case .missingCommitMessage:
            return "Missing commit message."

        case .notGitRepository(let path):
            return "Not a git repository: \(path)"

        case .noUpstream(let repo):
            return "\(repo) has no upstream configured."

        case .unsafeSync(let message):
            return message

        case .resetRequiresHardUpstream:
            return "Refusing reset without --hard-upstream."

        case .gitFailed(let command, let code, let stderr):
            let rendered = command.joined(separator: " ")
            return "git \(rendered) exited with \(code): \(stderr)"
        }
    }
}
