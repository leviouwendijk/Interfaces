import Arguments
import Foundation
import Interfaces

enum SaveCommand: RunnableArgumentCommand {
    static let name = "save"
    static let aliases = [
        "sv",
    ]

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Add and commit without pushing."),
            arg(
                "message",
                as: String.self,
                arity: .variadic,
                help: "Commit message."
            ),
            example(
                "gm save checkpoint before sync refactor",
                description: "Create a local commit."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let message = try GitManagerCLI.message(
            from: invocation
        )

        GitManagerRenderer.command(
            "git add ."
        )

        GitManagerRenderer.command(
            "git commit -m \"\(message)\""
        )

        let outputs = try await GitManagerAction.save(
            message: message,
            at: GitManagerCLI.currentDirectory
        )

        for output in outputs {
            GitManagerRenderer.output(
                output
            )
        }

        GitManagerRenderer.success(
            "Saved local commit."
        )
    }
}
