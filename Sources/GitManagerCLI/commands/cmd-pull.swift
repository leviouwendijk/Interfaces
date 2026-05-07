import Arguments
import Foundation
import Interfaces

enum PullCommand: RunnableArgumentCommand {
    static let name = "pull"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Pull from the default upstream using --ff-only."),
            flag(
                "force",
                help: "Attempt pull even when local changes are present."
            ),
            example(
                "gm pull",
                description: "Fast-forward pull the current branch."
            ),
            example(
                "gm changes --stat",
                description: "Inspect local changes before pulling."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let force = try invocation.flag(
            "force"
        )

        let state = try await GitManagerRepositoryInspector.state(
            at: GitManagerCLI.currentDirectory,
            fetch: false
        )

        if !force,
           state.hasTrackedChanges || state.hasUntracked {
            GitManagerRenderer.state(
                state,
                porcelain: false
            )

            throw GitManagerError.unsafeSync(
                """
                Refusing pull because local changes are present.

                Inspect:
                    gm changes
                    gm changes --stat
                    gm changes --diff

                Then choose one:
                    gm save "message"          # commit locally
                    git stash push -u          # temporarily stash tracked + untracked files
                    git restore <path>         # discard a tracked file
                    git clean -fd <path>       # remove untracked files
                    gm pull --force            # bypass this preflight
                """
            )
        }

        GitManagerRenderer.command(
            "git pull --ff-only <default-remote> <default-branch>"
        )

        let output = try await GitManagerAction.pull(
            at: GitManagerCLI.currentDirectory
        )

        GitManagerRenderer.output(
            output
        )
    }
}
