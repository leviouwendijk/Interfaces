import Foundation

public enum GitManagerRepositoryInspector {
    public static func state(
        at directory: URL,
        label: String? = nil,
        fetch: Bool = true
    ) async throws -> GitManagerRepositoryState {
        guard let root = try await root(
            at: directory
        ) else {
            return GitManagerRepositoryState(
                directory: directory,
                root: nil,
                label: label,
                branch: nil,
                remote: nil,
                upstreamBranch: nil,
                localHead: nil,
                remoteHead: nil,
                ahead: nil,
                behind: nil,
                hasTrackedChanges: false,
                hasUntracked: false,
                porcelain: "",
                classification: .notGitRepository
            )
        }

        let branch = try? await currentBranch(
            at: root
        )

        let hasTrackedChanges = try await GitRepo.isDirty(
            root,
            includeUntracked: false
        )

        let hasUntracked = try await GitRepo.hasUntracked(
            root
        )

        let porcelain = try await GitRepo.gitOut(
            root,
            [
                "status",
                "--porcelain",
            ]
        )

        let upstream = try? await GitRepo.defaultRemoteAndBranch(
            root
        )

        if fetch,
           upstream != nil {
            _ = try? await GitRepo.fetchDefaultRemote(
                root,
                purpose: .stateCheck
            )
        }

        let localHead = try? await GitRepo.head(
            root,
            .local
        )

        let remoteHead = try? await GitRepo.head(
            root,
            .remote
        )

        let divergence = try? await divergence(
            at: root
        )

        let classification = classification(
            upstream: upstream,
            divergence: divergence,
            hasTrackedChanges: hasTrackedChanges,
            hasUntracked: hasUntracked
        )

        return GitManagerRepositoryState(
            directory: directory,
            root: root,
            label: label,
            branch: branch,
            remote: upstream?.remote,
            upstreamBranch: upstream?.branch,
            localHead: localHead,
            remoteHead: remoteHead,
            ahead: divergence?.ahead,
            behind: divergence?.behind,
            hasTrackedChanges: hasTrackedChanges,
            hasUntracked: hasUntracked,
            porcelain: porcelain,
            classification: classification
        )
    }

    public static func states(
        at directories: [URL],
        fetch: Bool = true
    ) async throws -> [GitManagerRepositoryState] {
        var states: [GitManagerRepositoryState] = []
        states.reserveCapacity(
            directories.count
        )

        for directory in directories {
            states.append(
                try await state(
                    at: directory,
                    fetch: fetch
                )
            )
        }

        return states
    }
}

private extension GitManagerRepositoryInspector {
    static func root(
        at directory: URL
    ) async throws -> URL? {
        let result = try await GitRepo.git(
            directory,
            [
                "rev-parse",
                "--show-toplevel",
            ]
        )

        guard result.code == 0 else {
            return nil
        }

        let path = result.out
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !path.isEmpty else {
            return nil
        }

        return URL(
            fileURLWithPath: path
        )
    }

    static func currentBranch(
        at root: URL
    ) async throws -> String {
        let branch = try await GitRepo.gitOut(
            root,
            [
                "branch",
                "--show-current",
            ]
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if !branch.isEmpty {
            return branch
        }

        return try await GitRepo.gitOut(
            root,
            [
                "rev-parse",
                "--short",
                "HEAD",
            ]
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    static func divergence(
        at root: URL
    ) async throws -> GitRepo.Divergence {
        let out = try await GitRepo.gitOut(
            root,
            [
                "rev-list",
                "--left-right",
                "--count",
                "HEAD...@{u}",
            ]
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let parts = out
            .split {
                $0 == " " || $0 == "\t"
            }
            .compactMap {
                Int($0)
            }

        guard parts.count == 2 else {
            throw GitRepo.Error.invalidRevListOutput(
                raw: out
            )
        }

        return .init(
            ahead: parts[0],
            behind: parts[1]
        )
    }

    static func classification(
        upstream: (remote: String, branch: String)?,
        divergence: GitRepo.Divergence?,
        hasTrackedChanges: Bool,
        hasUntracked: Bool
    ) -> GitManagerRepositoryClassification {
        guard upstream != nil else {
            return .noUpstream
        }

        if hasTrackedChanges {
            return .dirty
        }

        if hasUntracked {
            return .untracked
        }

        guard let divergence else {
            return .unknown
        }

        if divergence.ahead == 0,
           divergence.behind == 0 {
            return .upToDate
        }

        if divergence.ahead > 0,
           divergence.behind == 0 {
            return .ahead
        }

        if divergence.ahead == 0,
           divergence.behind > 0 {
            return .behind
        }

        if divergence.ahead > 0,
           divergence.behind > 0 {
            return .diverged
        }

        return .unknown
    }
}
