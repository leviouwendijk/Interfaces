import Arguments
import Foundation
import Interfaces

enum ResetCommand: RunnableArgumentCommand {
    static let name = "reset"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Dangerous upstream alignment operations."),
            flag(
                "hard-upstream",
                help: "Reset local branch to @{u}. Required."
            ),
            flag(
                "clean",
                help: "Also remove untracked files."
            ),
            example(
                "gm reset --hard-upstream",
                description: "Make local branch match upstream."
            ),
            example(
                "gm reset --hard-upstream --clean",
                description: "Also remove untracked files."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        guard try invocation.flag(
            "hard-upstream"
        ) else {
            throw GitManagerError.resetRequiresHardUpstream
        }

        let clean = try invocation.flag(
            "clean"
        )

        GitManagerRenderer.command(
            "git reset --hard @{u}"
        )

        if clean {
            GitManagerRenderer.command(
                "git clean -fdx"
            )
        }

        try await GitManagerAction.hardResetToUpstream(
            cleanUntracked: clean,
            at: GitManagerCLI.currentDirectory
        )

        GitManagerRenderer.success(
            "Reset to upstream."
        )
    }
}
