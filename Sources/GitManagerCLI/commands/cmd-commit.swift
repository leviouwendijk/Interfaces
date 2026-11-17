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
        ] + GitManagerCLI.stagingComponents() + [
            example(
                "gm commit update git manager --push",
                description: "Commit and push."
            ),
            example(
                "gm commit -o Sources/gm -o Package.swift fix staging --push",
                description: "Stage and commit only the given paths."
            ),
            example(
                "gm commit -x compiled.pkl regenerate specs",
                description: "Stage everything except the given path."
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

        let staging = try GitManagerCLI.staging(
            from: invocation
        )

        GitManagerCLI.renderStaging(
            staging
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
            staging: staging,
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
