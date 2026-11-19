import Arguments
import Foundation
import Interfaces

enum InitCommand: RunnableArgumentCommand {
    static let name = "init"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Initialize a git repository and write the default .gitignore when there is none. An existing .gitignore is left alone; use gm ignore."),
            example(
                "gm init",
                description: "Run git init and create .gitignore if it is missing."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let directory = GitManagerCLI.currentDirectory

        GitManagerRenderer.command(
            "git init"
        )

        let result = try await GitRepo.git(
            directory,
            [
                "init",
            ]
        )

        guard result.code == 0 else {
            throw GitManagerError.unsafeSync(
                result.err.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            )
        }

        GitManagerRenderer.output(
            result.out
        )

        if try GitignoreDefaults.exists(in: directory) {
            let missing = try GitignoreDefaults.missing(in: directory)
            if !missing.isEmpty {
                GitManagerRenderer.output(
                    ".gitignore left unchanged; it is missing \(missing.count) default entries. Run gm ignore to merge them."
                )
            }
        } else if case .created(let count) = try GitignoreDefaults.merge(in: directory) {
            GitManagerRenderer.success(
                "Created .gitignore with \(count) entries."
            )
        }

        GitManagerRenderer.success(
            "Initialized repository."
        )
    }
}
