import Foundation

public struct GitManagerReconciliationResult: Sendable, Codable, Hashable {
    public let state: GitManagerRepositoryState
    public let trackedMatchesUpstream: Bool?
    public let upstreamDiffStat: String
    public let recommendation: GitManagerReconciliationRecommendation
    public let applied: GitManagerReconciliationAppliedAction?

    public init(
        state: GitManagerRepositoryState,
        trackedMatchesUpstream: Bool?,
        upstreamDiffStat: String,
        recommendation: GitManagerReconciliationRecommendation,
        applied: GitManagerReconciliationAppliedAction?
    ) {
        self.state = state
        self.trackedMatchesUpstream = trackedMatchesUpstream
        self.upstreamDiffStat = upstreamDiffStat
        self.recommendation = recommendation
        self.applied = applied
    }
}

public enum GitManagerReconciliationAppliedAction: String, Sendable, Codable, Hashable {
    case hardResetToUpstream = "hard-reset-to-upstream"
}

public enum GitManagerReconciliationRecommendation: String, Sendable, Codable, Hashable {
    case pull
    case push
    case resetHardUpstream
    case inspectLocalChanges
    case inspectDivergence
    case configureUpstream
    case alreadyClean
    case unknown

    public var summary: String {
        switch self {
        case .pull:
            return "Local branch is behind and clean. Pull is the safe next action."

        case .push:
            return "Local branch is ahead. Push is the safe next action."

        case .resetHardUpstream:
            return "Working tree already matches upstream. Reset local HEAD to upstream."

        case .inspectLocalChanges:
            return "Local changes differ from upstream. Inspect, save, stash, or discard them before pulling."

        case .inspectDivergence:
            return "Local and upstream histories have diverged. Inspect manually before syncing."

        case .configureUpstream:
            return "No upstream is configured for this branch."

        case .alreadyClean:
            return "Repository is already clean and up to date."

        case .unknown:
            return "Could not determine a safe reconciliation action."
        }
    }

    public var commands: [String] {
        switch self {
        case .pull:
            return [
                "gm pull",
            ]

        case .push:
            return [
                "gm push",
            ]

        case .resetHardUpstream:
            return [
                "gm reset --hard-upstream",
            ]

        case .inspectLocalChanges:
            return [
                "gm changes",
                "gm changes --stat",
                "gm changes --diff",
                "gm save \"message\"",
                "git stash push -u",
            ]

        case .inspectDivergence:
            return [
                "git log --left-right --oneline HEAD...@{u}",
                "gm changes --stat",
            ]

        case .configureUpstream:
            return [
                "git branch --set-upstream-to origin/<branch>",
            ]

        case .alreadyClean:
            return []

        case .unknown:
            return [
                "gm status",
                "gm changes --stat",
            ]
        }
    }
}

public enum GitManagerReconciler {
    public static func reconcile(
        at directory: URL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        ),
        fetch: Bool = false,
        apply: Bool = false,
        cleanUntracked: Bool = false
    ) async throws -> GitManagerReconciliationResult {
        let state = try await GitManagerRepositoryInspector.state(
            at: directory,
            fetch: fetch
        )

        guard let root = state.root else {
            return GitManagerReconciliationResult(
                state: state,
                trackedMatchesUpstream: nil,
                upstreamDiffStat: "",
                recommendation: .unknown,
                applied: nil
            )
        }

        guard state.upstreamDisplay != nil else {
            return GitManagerReconciliationResult(
                state: state,
                trackedMatchesUpstream: nil,
                upstreamDiffStat: "",
                recommendation: .configureUpstream,
                applied: nil
            )
        }

        let trackedMatchesUpstream = try await trackedWorkingTreeMatchesUpstream(
            at: root
        )

        let upstreamDiffStat = try await diffStatAgainstUpstream(
            at: root
        )

        let recommendation = recommendation(
            state: state,
            trackedMatchesUpstream: trackedMatchesUpstream
        )

        var applied: GitManagerReconciliationAppliedAction?

        if apply {
            guard recommendation == .resetHardUpstream else {
                throw GitManagerError.unsafeSync(
                    "Refusing --apply because the safe action is not a hard reset to upstream."
                )
            }

            try await GitManagerAction.hardResetToUpstream(
                cleanUntracked: cleanUntracked,
                at: directory
            )

            applied = .hardResetToUpstream
        }

        return GitManagerReconciliationResult(
            state: state,
            trackedMatchesUpstream: trackedMatchesUpstream,
            upstreamDiffStat: upstreamDiffStat,
            recommendation: recommendation,
            applied: applied
        )
    }
}

private extension GitManagerReconciler {
    static func trackedWorkingTreeMatchesUpstream(
        at root: URL
    ) async throws -> Bool {
        let result = try await GitRepo.git(
            root,
            [
                "diff",
                "--quiet",
                "@{u}",
            ]
        )

        return result.code == 0
    }

    static func diffStatAgainstUpstream(
        at root: URL
    ) async throws -> String {
        try await GitRepo.gitOut(
            root,
            [
                "diff",
                "--stat",
                "@{u}",
            ]
        )
    }

    static func recommendation(
        state: GitManagerRepositoryState,
        trackedMatchesUpstream: Bool
    ) -> GitManagerReconciliationRecommendation {
        let ahead = state.ahead ?? 0
        let behind = state.behind ?? 0

        if ahead == 0,
           behind == 0,
           !state.hasTrackedChanges,
           !state.hasUntracked {
            return .alreadyClean
        }

        if ahead > 0,
           behind > 0 {
            return .inspectDivergence
        }

        if behind > 0,
           !state.hasTrackedChanges,
           !state.hasUntracked {
            return .pull
        }

        if ahead > 0,
           behind == 0,
           !state.hasTrackedChanges,
           !state.hasUntracked {
            return .push
        }

        if behind > 0,
           state.hasTrackedChanges,
           trackedMatchesUpstream {
            return .resetHardUpstream
        }

        if state.hasTrackedChanges || state.hasUntracked {
            return .inspectLocalChanges
        }

        return .unknown
    }
}
