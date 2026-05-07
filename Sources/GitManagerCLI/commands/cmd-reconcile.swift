import Arguments
import Foundation
import Interfaces

enum ReconcileCommand: RunnableArgumentCommand {
    static let name = "reconcile"
    static let aliases = [
        "rec",
    ]

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Diagnose dirty/ahead/behind states and suggest or apply a safe next action."),
            flag(
                "all",
                help: "Scan repositories under a root directory and reconcile each one."
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
                "fetch",
                help: "Fetch before reconciling."
            ),
            flag(
                "stat",
                help: "Show git diff --stat @{u} when local tracked files differ from upstream."
            ),
            flag(
                "apply",
                help: "Apply only safe automatic reconciliations."
            ),
            flag(
                "clean",
                help: "With --apply, also remove untracked files when doing a safe hard reset."
            ),
            example(
                "gm reconcile",
                description: "Diagnose current repo and suggest the next command."
            ),
            example(
                "gm reconcile --stat",
                description: "Also show the diff stat against upstream."
            ),
            example(
                "gm reconcile --apply",
                description: "Run the safe reconciliation for the current repo."
            ),
            example(
                "gm reconcile --all --fetch",
                description: "Dry-run reconciliation for all repos below ~/main/programming."
            ),
            example(
                "gm reconcile --all --fetch --apply",
                description: "Apply only safe reconciliations for all repos below ~/main/programming."
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

        let root = try invocation.value(
            "root",
            as: String.self
        )

        let depth = try invocation.value(
            "depth",
            as: Int.self
        ) ?? 5

        let fetch = try invocation.flag(
            "fetch"
        )

        let stat = try invocation.flag(
            "stat"
        )

        let apply = try invocation.flag(
            "apply"
        )

        let clean = try invocation.flag(
            "clean"
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

            try await reconcileTargets(
                targets,
                fetch: fetch,
                apply: apply,
                clean: clean
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

            try await reconcileTargets(
                targets,
                fetch: fetch,
                apply: apply,
                clean: clean
            )

            return
        }

        let result = try await GitManagerReconciler.reconcile(
            at: GitManagerCLI.currentDirectory,
            fetch: fetch,
            apply: apply,
            cleanUntracked: clean
        )

        renderResult(
            result,
            stat: stat
        )
    }
}

private extension ReconcileCommand {
    static func reconcileTargets(
        _ targets: [GitManagerRepositoryInspectionTarget],
        fetch: Bool,
        apply: Bool,
        clean: Bool
    ) async throws {
        guard !targets.isEmpty else {
            print(
                "No repositories found."
            )

            return
        }

        let nameWidth = GitManagerRenderer.repositoryNameWidth(
            for: targets
        )

        GitManagerRenderer.reconciliationHeader()

        try await withThrowingTaskGroup(
            of: GitManagerReconciliationResult.self
        ) { group in
            for target in targets {
                group.addTask {
                    try await GitManagerReconciler.reconcile(
                        at: target.directory,
                        fetch: fetch,
                        apply: apply,
                        cleanUntracked: clean
                    )
                }
            }

            for try await result in group {
                GitManagerRenderer.reconciliationLine(
                    result,
                    nameWidth: nameWidth
                )
            }
        }

        GitManagerRenderer.repositoryFooter()
    }

    static func renderResult(
        _ result: GitManagerReconciliationResult,
        stat: Bool
    ) {
        GitManagerRenderer.state(
            result.state,
            porcelain: false
        )

        print(
            "reconcile".ansi(
                .bold,
                .brightWhite
            )
        )

        if let trackedMatchesUpstream = result.trackedMatchesUpstream {
            print(
                row(
                    "tracked == upstream",
                    trackedMatchesUpstream ? "yes" : "no"
                )
            )
        }

        print(
            row(
                "recommendation",
                result.recommendation.rawValue
            )
        )

        print("")
        print(
            result.recommendation.summary
        )

        if stat,
           !result.upstreamDiffStat.trimmingCharacters(
                in: .whitespacesAndNewlines
           )
           .isEmpty {
            print("")
            print(
                "diff against upstream".ansi(
                    .bold,
                    .brightWhite
                )
            )

            GitManagerRenderer.output(
                result.upstreamDiffStat
            )
        }

        if let applied = result.applied {
            print("")
            GitManagerRenderer.success(
                "Applied: \(applied.rawValue)"
            )

            return
        }

        if !result.recommendation.commands.isEmpty {
            print("")
            print(
                "next".ansi(
                    .bold,
                    .brightWhite
                )
            )

            for command in result.recommendation.commands {
                print(
                    "  \(command)"
                )
            }
        }

        if result.recommendation.safeAppliedAction != nil {
            print("")
            print(
                "To perform this through gm:".ansi(.brightBlack)
            )
            print(
                "  gm reconcile --apply"
            )
        }
    }

    static func row(
        _ key: String,
        _ value: String
    ) -> String {
        "\(key.padded(to: 22).ansi(.brightBlack)) \(value)"
    }
}

private extension String {
    func padded(
        to width: Int
    ) -> String {
        guard count < width else {
            return self
        }

        return self + String(
            repeating: " ",
            count: width - count
        )
    }
}
