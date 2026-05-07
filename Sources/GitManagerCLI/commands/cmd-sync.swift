import Arguments
import Foundation
import Interfaces

enum SyncCommand: RunnableArgumentCommand {
    static let name = "sync"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Classify repo state and run the safe obvious sync action."),
            example(
                "gm sync",
                description: "Pull if behind, push if ahead, refuse if dirty or diverged."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let result = try await GitManagerAction.sync(
            at: GitManagerCLI.currentDirectory
        )

        GitManagerRenderer.state(
            result.state,
            porcelain: false
        )

        switch result.action {
        case .none:
            GitManagerRenderer.success(
                result.output
            )

        case .pull:
            GitManagerRenderer.command(
                "git pull --ff-only <default-remote> <default-branch>"
            )
            GitManagerRenderer.output(
                result.output
            )

        case .push:
            GitManagerRenderer.command(
                "git push -u <default-remote> <default-branch>"
            )
            GitManagerRenderer.output(
                result.output
            )
        }
    }
}
