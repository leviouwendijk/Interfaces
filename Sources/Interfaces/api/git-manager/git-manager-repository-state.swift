import Foundation

public struct GitManagerRepositoryState: Sendable, Codable, Hashable {
    public let directory: URL
    public let root: URL?
    public let label: String?
    public let branch: String?
    public let remote: String?
    public let upstreamBranch: String?
    public let localHead: String?
    public let remoteHead: String?
    public let ahead: Int?
    public let behind: Int?
    public let hasTrackedChanges: Bool
    public let hasUntracked: Bool
    public let porcelain: String
    public let classification: GitManagerRepositoryClassification

    public var displayName: String {
        label ?? root?.lastPathComponent ?? directory.lastPathComponent
    }

    public var upstreamDisplay: String? {
        guard let remote,
              let upstreamBranch
        else {
            return nil
        }

        return "\(remote)/\(upstreamBranch)"
    }

    public init(
        directory: URL,
        root: URL?,
        label: String?,
        branch: String?,
        remote: String?,
        upstreamBranch: String?,
        localHead: String?,
        remoteHead: String?,
        ahead: Int?,
        behind: Int?,
        hasTrackedChanges: Bool,
        hasUntracked: Bool,
        porcelain: String,
        classification: GitManagerRepositoryClassification
    ) {
        self.directory = directory
        self.root = root
        self.label = label
        self.branch = branch
        self.remote = remote
        self.upstreamBranch = upstreamBranch
        self.localHead = localHead
        self.remoteHead = remoteHead
        self.ahead = ahead
        self.behind = behind
        self.hasTrackedChanges = hasTrackedChanges
        self.hasUntracked = hasUntracked
        self.porcelain = porcelain
        self.classification = classification
    }
}
