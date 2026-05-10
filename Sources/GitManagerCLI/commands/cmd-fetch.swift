import Arguments
import Foundation
import Interfaces

enum FetchCommand: RunnableArgumentCommand {
    static let name = "fetch"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Fetch the current repository, sbm repositories, or all repositories under a root."),
            flag(
                "all",
                help: "Scan repositories under a root directory and fetch each one."
            ),
            flag(
                "sbm",
                help: "Fetch repositories from sbm metadata."
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
                "lightweight",
                help: "Use a lightweight shallow fetch."
            ),
            example(
                "gm fetch",
                description: "Fetch the current repository."
            ),
            example(
                "gm fetch --all",
                description: "Fetch all repositories below ~/main/programming."
            ),
            example(
                "gm fetch --sbm",
                description: "Fetch sbm metadata repositories."
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

        let lightweight = try invocation.flag(
            "lightweight"
        )

        if all,
           sbm {
            throw GitManagerError.unsafeSync(
                "Use either --all or --sbm, not both."
            )
        }

        let purpose: GitRepo.FetchPurpose = lightweight
            ? .lightweight
            : .stateCheck

        if sbm {
            let targets = try GitManagerSBMMetadataStore.repositories().map {
                GitManagerRepositoryInspectionTarget(
                    directory: $0.projectRootURL,
                    label: $0.binary
                )
            }

            try await fetchTargets(
                targets,
                purpose: purpose
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

            try await fetchTargets(
                targets,
                purpose: purpose
            )

            return
        }

        let target = GitManagerRepositoryInspectionTarget(
            directory: GitManagerCLI.currentDirectory
        )

        try await fetchTargets(
            [
                target,
            ],
            purpose: purpose
        )
    }
}

private extension FetchCommand {
    static func fetchTargets(
        _ targets: [GitManagerRepositoryInspectionTarget],
        purpose: GitRepo.FetchPurpose,
        maxConcurrent: Int = 8
    ) async throws {
        let progress = GitManagerFetchProgressRenderer(
            enabled: true
        )

        await progress.begin(
            count: targets.count
        )

        for target in targets {
            await fetchTarget(
                target,
                purpose: purpose,
                progress: progress
            )
        }

        await progress.end()
    }

    static func fetchTarget(
        _ target: GitManagerRepositoryInspectionTarget,
        purpose: GitRepo.FetchPurpose,
        progress: GitManagerFetchProgressRenderer
    ) async {
        do {
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

            _ = try await GitRepo.fetchDefaultRemote(
                root,
                purpose: purpose
            )

            await progress.fetched(
                target
            )
        } catch {
            await progress.skipped(
                target,
                reason: errorMessage(
                    error
                )
            )
        }
    }

    static func errorMessage(
        _ error: Error
    ) -> String {
        (error as? LocalizedError)?.errorDescription
            ?? String(
                describing: error
            )
    }
}
