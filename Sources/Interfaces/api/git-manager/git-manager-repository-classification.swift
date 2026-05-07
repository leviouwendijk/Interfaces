import Foundation

public enum GitManagerRepositoryClassification: String, Sendable, Codable, Hashable {
    case upToDate = "up-to-date"
    case ahead
    case behind
    case diverged
    case dirty
    case untracked
    case noUpstream = "no-upstream"
    case notGitRepository = "not-git-repository"
    case unknown

    public var isSafeAutomaticSyncCandidate: Bool {
        switch self {
        case .ahead, .behind, .upToDate:
            return true

        case .dirty,
             .untracked,
             .diverged,
             .noUpstream,
             .notGitRepository,
             .unknown:
            return false
        }
    }
}
