import Arguments
import Foundation
import Interfaces

enum PushCommand: RunnableArgumentCommand {
    static let name = "push"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Push to the default upstream."),
            example(
                "gm push",
                description: "Push the current branch."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        GitManagerRenderer.command(
            "git push -u <default-remote> <default-branch>"
        )

        let output = try await GitManagerAction.push(
            at: GitManagerCLI.currentDirectory
        )

        GitManagerRenderer.output(
            output
        )
    }
}
