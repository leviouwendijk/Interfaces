import Arguments
import Foundation
import Interfaces

enum StatusCommand: RunnableArgumentCommand {
    static let name = "status"
    static let aliases = [
        "s",
    ]

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Show classified git repository state."),
            flag(
                "all",
                help: "Scan git repositories under a root directory."
            ),
            flag(
                "sbm",
                help: "Use sbm metadata repositories."
            ),
            opt(
                "root",
                short: "r",
                as: String.self,
                help: "Root directory for --all scanning. Defaults to ~/main/programming."
            ),
            opt(
                "depth",
                short: "d",
                as: Int.self,
                default: 5,
                help: "Maximum scan depth for --all or --root."
            ),
            flag(
                "porcelain",
                help: "Also show raw git status --porcelain output."
            ),
            flag(
                "fetch",
                help: "Fetch before checking divergence."
            ),
            flag(
                "sorted",
                help: "Wait for all repositories, then render a sorted table."
            ),
            opt(
                "sort",
                as: String.self,
                help: "Sort key for --sorted: name, path, state, dirty, ahead, behind."
            ),
            example(
                "gm status",
                description: "Show current repo state."
            ),
            example(
                "gm status --sbm",
                description: "Show state for sbm metadata repos."
            ),
            example(
                "gm status --all",
                description: "Scan git repos under ~/main/programming and stream aligned rows."
            ),
            example(
                "gm status --all --fetch",
                description: "Fetch first with progress, then stream aligned rows."
            ),
            example(
                "gm status --all --fetch --sorted --sort dirty",
                description: "Fetch first, wait for all repos, sort dirty/problem repos first, then render."
            ),
            example(
                "gm status --all --root ~/main/programming/libraries/swiftlibs --depth 3",
                description: "Scan git repos under a specific root."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let all = try invocation.flag(
            "all"
        )

        let sbm = try invocation.flag(
            "sbm"
        )

        let porcelain = try invocation.flag(
            "porcelain"
        )

        let fetch = try invocation.flag(
            "fetch"
        )

        let root = try invocation.value(
            "root",
            as: String.self
        )

        let depth = try invocation.value(
            "depth",
            as: Int.self
        ) ?? 5

        let sorted = try invocation.flag(
            "sorted"
        )

        let sort = try invocation.value(
            "sort",
            as: String.self
        )

        if all,
           sbm {
            throw GitManagerError.unsafeSync(
                "Use either --all or --sbm, not both."
            )
        }

        if sbm {
            let targets = try GitManagerSBMMetadataStore.repositories().map {
                GitManagerRepositoryInspectionTarget(
                    directory: $0.projectRootURL,
                    label: $0.binary
                )
            }

            try await renderTargets(
                targets,
                fetch: fetch,
                porcelain: porcelain,
                sorted: sorted || sort != nil,
                sort: sort
            )

            return
        }

        if all || root != nil {
            let scanRoot = GitManagerCLI.expandedPath(
                root ?? "~/main/programming"
            )

            let repos = try GitManagerRepositoryScanner.repositories(
                under: scanRoot,
                maxDepth: depth
            )

            let targets = repos.map {
                GitManagerRepositoryInspectionTarget(
                    directory: $0
                )
            }

            try await renderTargets(
                targets,
                fetch: fetch,
                porcelain: porcelain,
                sorted: sorted || sort != nil,
                sort: sort
            )

            return
        }

        let target = GitManagerRepositoryInspectionTarget(
            directory: GitManagerCLI.currentDirectory
        )

        if fetch {
            let progress = GitManagerFetchProgressRenderer(
                enabled: true
            )

            await progress.begin(
                count: 1
            )

            try await prefetchTarget(
                target,
                progress: progress
            )

            await progress.end()
        }

        let state = try await GitManagerRepositoryInspector.state(
            at: GitManagerCLI.currentDirectory,
            fetch: false
        )

        GitManagerRenderer.state(
            state,
            porcelain: porcelain
        )
    }
}

private extension StatusCommand {
    static func renderTargets(
        _ targets: [GitManagerRepositoryInspectionTarget],
        fetch: Bool,
        porcelain: Bool,
        sorted: Bool,
        sort: String?
    ) async throws {
        guard !targets.isEmpty else {
            GitManagerRenderer.states(
                [],
                porcelain: porcelain
            )

            return
        }

        if fetch {
            let progress = GitManagerFetchProgressRenderer(
                enabled: true
            )

            await progress.begin(
                count: targets.count
            )

            try await prefetchTargets(
                targets,
                progress: progress
            )

            await progress.end()
        }

        if sorted {
            let states = try await GitManagerRepositoryInspector.states(
                at: targets,
                fetch: false
            )

            GitManagerRenderer.states(
                sortedStates(
                    states,
                    sort: sort
                ),
                porcelain: porcelain
            )

            return
        }

        let nameWidth = GitManagerRenderer.repositoryNameWidth(
            for: targets
        )

        GitManagerRenderer.repositoryHeader()

        try await GitManagerRepositoryInspector.streamStates(
            at: targets,
            fetch: false,
            maxConcurrent: 8
        ) { state in
            if porcelain {
                GitManagerRenderer.state(
                    state,
                    porcelain: true
                )
            } else {
                GitManagerRenderer.stateLine(
                    state,
                    nameWidth: nameWidth
                )
            }
        }

        GitManagerRenderer.repositoryFooter()
    }

    static func prefetchTargets(
        _ targets: [GitManagerRepositoryInspectionTarget],
        progress: GitManagerFetchProgressRenderer,
        maxConcurrent: Int = 8
    ) async throws {
        let limit = max(
            1,
            maxConcurrent
        )

        try await withThrowingTaskGroup(
            of: Void.self
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
                    try await prefetchTarget(
                        target,
                        progress: progress
                    )
                }
            }

            for _ in 0..<limit {
                enqueueNext()
            }

            while try await group.next() != nil {
                active -= 1

                enqueueNext()
            }
        }
    }

    static func prefetchTarget(
        _ target: GitManagerRepositoryInspectionTarget,
        progress: GitManagerFetchProgressRenderer
    ) async throws {
        let state = try await GitManagerRepositoryInspector.state(
            at: target.directory,
            label: target.label,
            fetch: false
        )

        guard let root = state.root else {
            await progress.skipped(
                target,
                reason: "not-git-repository"
            )

            return
        }

        guard state.upstreamDisplay != nil else {
            await progress.skipped(
                target,
                reason: "no-upstream"
            )

            return
        }

        await progress.fetching(
            target
        )

        _ = try? await GitRepo.fetchDefaultRemote(
            root,
            purpose: .stateCheck
        )

        await progress.fetched(
            target
        )
    }

    static func sortedStates(
        _ states: [GitManagerRepositoryState],
        sort: String?
    ) -> [GitManagerRepositoryState] {
        let key = StatusSortKey(
            rawValue: sort ?? "name"
        ) ?? .name

        return states.sorted {
            compare(
                $0,
                $1,
                key: key
            )
        }
    }

    static func compare(
        _ lhs: GitManagerRepositoryState,
        _ rhs: GitManagerRepositoryState,
        key: StatusSortKey
    ) -> Bool {
        switch key {
        case .name:
            return lhs.displayName.localizedStandardCompare(
                rhs.displayName
            ) == .orderedAscending

        case .path:
            return lhs.directory.path.localizedStandardCompare(
                rhs.directory.path
            ) == .orderedAscending

        case .state:
            let lhsRank = stateRank(
                lhs.classification
            )
            let rhsRank = stateRank(
                rhs.classification
            )

            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }

            return lhs.displayName < rhs.displayName

        case .dirty:
            let lhsRank = dirtyRank(
                lhs
            )
            let rhsRank = dirtyRank(
                rhs
            )

            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }

            return lhs.displayName < rhs.displayName

        case .ahead:
            let lhsAhead = lhs.ahead ?? 0
            let rhsAhead = rhs.ahead ?? 0

            if lhsAhead != rhsAhead {
                return lhsAhead > rhsAhead
            }

            return lhs.displayName < rhs.displayName

        case .behind:
            let lhsBehind = lhs.behind ?? 0
            let rhsBehind = rhs.behind ?? 0

            if lhsBehind != rhsBehind {
                return lhsBehind > rhsBehind
            }

            return lhs.displayName < rhs.displayName
        }
    }

    static func stateRank(
        _ classification: GitManagerRepositoryClassification
    ) -> Int {
        switch classification {
        case .dirty:
            return 0

        case .untracked:
            return 1

        case .diverged:
            return 2

        case .behind:
            return 3

        case .ahead:
            return 4

        case .noUpstream:
            return 5

        case .notGitRepository:
            return 6

        case .unknown:
            return 7

        case .upToDate:
            return 8
        }
    }

    static func dirtyRank(
        _ state: GitManagerRepositoryState
    ) -> Int {
        if state.hasTrackedChanges {
            return 0
        }

        if state.hasUntracked {
            return 1
        }

        return 2
    }
}

private enum StatusSortKey: String {
    case name
    case path
    case state
    case dirty
    case ahead
    case behind
}
