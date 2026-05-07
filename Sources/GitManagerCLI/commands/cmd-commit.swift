import Arguments
import Foundation
import Interfaces

enum CommitCommand: RunnableArgumentCommand {
    static let name = "commit"
    static let aliases = [
        "c",
    ]

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Add, commit, and optionally push."),
            arg(
                "message",
                as: String.self,
                arity: .variadic,
                help: "Commit message."
            ),
            flag(
                "push",
                help: "Push after committing."
            ),
            example(
                "gm commit update git manager --push",
                description: "Commit and push."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let message = try GitManagerCLI.message(
            from: invocation
        )

        let push = try invocation.flag(
            "push"
        )

        GitManagerRenderer.command(
            "git add ."
        )

        GitManagerRenderer.command(
            "git commit -m \"\(message)\""
        )

        if push {
            GitManagerRenderer.command(
                "git push -u <default-remote> <default-branch>"
            )
        }

        let outputs = try await GitManagerAction.commit(
            message: message,
            push: push,
            at: GitManagerCLI.currentDirectory
        )

        for output in outputs {
            GitManagerRenderer.output(
                output
            )
        }

        GitManagerRenderer.success(
            push ? "Committed and pushed." : "Committed."
        )
    }
}
