import Arguments
import Foundation
import Interfaces

enum ScanCommand: RunnableArgumentCommand {
    static let name = "scan"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Find git repositories below a root and show their state."),
            opt(
                "root",
                short: "r",
                as: String.self,
                help: "Root directory. Defaults to current directory."
            ),
            opt(
                "depth",
                short: "d",
                as: Int.self,
                default: 4,
                help: "Maximum scan depth."
            ),
            flag(
                "porcelain",
                help: "Also show raw git status --porcelain output."
            ),
            flag(
                "no-fetch",
                help: "Do not fetch before checking divergence."
            ),
            example(
                "gm scan --root ~/main/programming",
                description: "Scan git repos below ~/main/programming."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let root = try invocation.value(
            "root",
            as: String.self
        )

        let depth = try invocation.value(
            "depth",
            as: Int.self
        ) ?? 4

        let porcelain = try invocation.flag(
            "porcelain"
        )

        let fetch = try !invocation.flag(
            "no-fetch"
        )

        let repos = try GitManagerRepositoryScanner.repositories(
            under: GitManagerCLI.expandedPath(
                root ?? GitManagerCLI.currentDirectory.path
            ),
            maxDepth: depth
        )

        let states = try await GitManagerRepositoryInspector.states(
            at: repos,
            fetch: fetch
        )

        GitManagerRenderer.states(
            states,
            porcelain: porcelain
        )
    }
}
