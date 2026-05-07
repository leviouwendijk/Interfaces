import Arguments
import Foundation
import Interfaces

enum PullCommand: RunnableArgumentCommand {
    static let name = "pull"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Pull from the default upstream using --ff-only."),
            example(
                "gm pull",
                description: "Fast-forward pull the current branch."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
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
