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
            about("Show classified git state."),
            flag(
                "all",
                help: "Use sbm metadata repos instead of only the current repo."
            ),
            opt(
                "root",
                short: "r",
                as: String.self,
                help: "Scan git repos under this root."
            ),
            flag(
                "porcelain",
                help: "Also show raw git status --porcelain output."
            ),
            flag(
                "fetch",
                help: "Fetch before checking divergence."
            ),
            example(
                "gm status",
                description: "Show current repo state."
            ),
            example(
                "gm status --all",
                description: "Show state for sbm metadata repos."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let all = try invocation.flag(
            "all"
        )

        let porcelain = try invocation.flag(
            "porcelain"
        )

        let fetch = try invocation.flag(
            "fetch"
        )

        if let root = try invocation.value(
            "root",
            as: String.self
        ) {
            let repos = try GitManagerRepositoryScanner.repositories(
                under: GitManagerCLI.expandedPath(
                    root
                )
            )

            let states = try await GitManagerRepositoryInspector.states(
                at: repos,
                fetch: fetch
            )

            GitManagerRenderer.states(
                states,
                porcelain: porcelain
            )

            return
        }

        if all {
            var states: [GitManagerRepositoryState] = []

            for metadata in try GitManagerSBMMetadataStore.repositories() {
                states.append(
                    try await GitManagerRepositoryInspector.state(
                        at: metadata.projectRootURL,
                        label: metadata.binary,
                        fetch: fetch
                    )
                )
            }

            GitManagerRenderer.states(
                states,
                porcelain: porcelain
            )

            return
        }

        let state = try await GitManagerRepositoryInspector.state(
            at: GitManagerCLI.currentDirectory,
            fetch: fetch
        )

        GitManagerRenderer.state(
            state,
            porcelain: porcelain
        )
    }
}
