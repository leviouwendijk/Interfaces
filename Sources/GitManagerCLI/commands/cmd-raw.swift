import Arguments
import Foundation
import Interfaces

enum RawCommand: RunnableArgumentCommand {
    static let name = "raw"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Pass raw arguments to git in the current repo."),
            arg(
                "arguments",
                as: String.self,
                arity: .variadic,
                help: "Arguments passed to git."
            ),
            example(
                "gm raw log --oneline -5",
                description: "Run git log --oneline -5."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let arguments = try invocation.values(
            "arguments",
            as: String.self
        )

        guard !arguments.isEmpty else {
            throw GitManagerError.unsafeSync(
                "raw requires git arguments."
            )
        }

        GitManagerRenderer.command(
            "git \(arguments.joined(separator: " "))"
        )

        let output = try await GitManagerAction.raw(
            arguments,
            at: GitManagerCLI.currentDirectory
        )

        GitManagerRenderer.output(
            output
        )
    }
}
