import Foundation

public struct GitManagerRepositoryInspectionTarget: Sendable, Codable, Hashable {
    public let directory: URL
    public let label: String?

    public init(
        directory: URL,
        label: String? = nil
    ) {
        self.directory = directory
        self.label = label
    }

    public var displayName: String {
        label ?? directory.lastPathComponent
    }
}

public enum GitManagerRepositoryInspectionProgressPhase: String, Sendable, Codable, Hashable {
    case fetching
    case fetched
}

public struct GitManagerRepositoryInspectionProgress: Sendable, Codable, Hashable {
    public let target: GitManagerRepositoryInspectionTarget
    public let phase: GitManagerRepositoryInspectionProgressPhase

    public init(
        target: GitManagerRepositoryInspectionTarget,
        phase: GitManagerRepositoryInspectionProgressPhase
    ) {
        self.target = target
        self.phase = phase
    }
}

public enum GitManagerRepositoryInspector {
    public static func state(
        at directory: URL,
        label: String? = nil,
        fetch: Bool = true,
        progress: (@Sendable (GitManagerRepositoryInspectionProgress) async -> Void)? = nil
    ) async throws -> GitManagerRepositoryState {
        let target = GitManagerRepositoryInspectionTarget(
            directory: directory,
            label: label
        )

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
            await progress?(
                GitManagerRepositoryInspectionProgress(
                    target: target,
                    phase: .fetching
                )
            )

            _ = try? await GitRepo.fetchDefaultRemote(
                root,
                purpose: .stateCheck
            )

            await progress?(
                GitManagerRepositoryInspectionProgress(
                    target: target,
                    phase: .fetched
                )
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
        fetch: Bool = true,
        progress: (@Sendable (GitManagerRepositoryInspectionProgress) async -> Void)? = nil
    ) async throws -> [GitManagerRepositoryState] {
        try await states(
            at: directories.map {
                GitManagerRepositoryInspectionTarget(
                    directory: $0
                )
            },
            fetch: fetch,
            progress: progress
        )
    }

    public static func states(
        at targets: [GitManagerRepositoryInspectionTarget],
        fetch: Bool = true,
        progress: (@Sendable (GitManagerRepositoryInspectionProgress) async -> Void)? = nil
    ) async throws -> [GitManagerRepositoryState] {
        var states: [GitManagerRepositoryState] = []
        states.reserveCapacity(
            targets.count
        )

        for target in targets {
            states.append(
                try await state(
                    at: target.directory,
                    label: target.label,
                    fetch: fetch,
                    progress: progress
                )
            )
        }

        return states
    }

    public static func streamStates(
        at directories: [URL],
        fetch: Bool = true,
        maxConcurrent: Int = 8,
        progress: (@Sendable (GitManagerRepositoryInspectionProgress) async -> Void)? = nil,
        onState: @escaping @Sendable (GitManagerRepositoryState) -> Void
    ) async throws {
        try await streamStates(
            at: directories.map {
                GitManagerRepositoryInspectionTarget(
                    directory: $0
                )
            },
            fetch: fetch,
            maxConcurrent: maxConcurrent,
            progress: progress,
            onState: onState
        )
    }

    public static func streamStates(
        at targets: [GitManagerRepositoryInspectionTarget],
        fetch: Bool = true,
        maxConcurrent: Int = 8,
        progress: (@Sendable (GitManagerRepositoryInspectionProgress) async -> Void)? = nil,
        onState: @escaping @Sendable (GitManagerRepositoryState) -> Void
    ) async throws {
        let limit = max(
            1,
            maxConcurrent
        )

        try await withThrowingTaskGroup(
            of: GitManagerRepositoryState.self
        ) { group in
            var iterator = targets.makeIterator()
            var active = 0

            func enqueueNext() {
                guard active < limit,
                      let target = iterator.next()
                else {
                    return
                }

                active += 1

                group.addTask {
                    try await state(
                        at: target.directory,
                        label: target.label,
                        fetch: fetch,
                        progress: progress
                    )
                }
            }

            for _ in 0..<limit {
                enqueueNext()
            }

            while let state = try await group.next() {
                active -= 1

                onState(
                    state
                )

                enqueueNext()
            }
        }
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
