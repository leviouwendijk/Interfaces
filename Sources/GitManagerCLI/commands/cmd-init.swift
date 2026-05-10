import Arguments
import Foundation
import Interfaces

enum InitCommand: RunnableArgumentCommand {
    static let name = "init"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Initialize a git repository and merge default .gitignore entries without overwriting existing ones."),
            example(
                "gm init",
                description: "Run git init and merge missing default .gitignore entries."
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

        let mergeResult = try mergeGitignore(
            at: directory
        )

        switch mergeResult {
        case .created(let count):
            GitManagerRenderer.success(
                "Created .gitignore with \(count) entries."
            )

        case .merged(let count):
            GitManagerRenderer.success(
                "Merged \(count) missing .gitignore entries."
            )

        case .unchanged:
            GitManagerRenderer.success(
                ".gitignore already contains all default entries."
            )
        }

        GitManagerRenderer.success(
            "Initialized repository."
        )
    }
}

private extension InitCommand {
    enum GitignoreMergeResult {
        case created(Int)
        case merged(Int)
        case unchanged
    }

    static let defaultGitignoreEntries = [
        ".DS_Store",
        ".build/",
        ".index-build/",
        ".swiftpm/",
        "DerivedData/",
        "*.xcodeproj/project.xcworkspace/xcuserdata/",
        "*.xcodeproj/xcuserdata/",
        "*.xcworkspace/xcuserdata/",
        "xcuserdata/",
        ".env",
        ".env.*",
        ".env/*",
        "compiled.pkl",
        "/compiled.pkl",
        "**/compiled.pkl"
    ]

    static func mergeGitignore(
        at directory: URL
    ) throws -> GitignoreMergeResult {
        let file = directory.appendingPathComponent(
            ".gitignore"
        )

        let fileManager = FileManager.default

        guard fileManager.fileExists(
            atPath: file.path
        ) else {
            let content = defaultGitignoreEntries.joined(
                separator: "\n"
            ) + "\n"

            try content.write(
                to: file,
                atomically: true,
                encoding: .utf8
            )

            return .created(
                defaultGitignoreEntries.count
            )
        }

        let existing = try String(
            contentsOf: file,
            encoding: .utf8
        )

        let existingEntries = Set(
            existing
                .split(
                    separator: "\n",
                    omittingEmptySubsequences: false
                )
                .map(String.init)
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
                .filter {
                    !$0.isEmpty
                }
        )

        let missing = defaultGitignoreEntries.filter {
            !existingEntries.contains($0)
        }

        guard !missing.isEmpty else {
            return .unchanged
        }

        var updated = existing

        if !updated.hasSuffix("\n") {
            updated += "\n"
        }

        if !updated.hasSuffix("\n\n") {
            updated += "\n"
        }

        updated += "# gm defaults\n"
        updated += missing.joined(
            separator: "\n"
        )
        updated += "\n"

        try updated.write(
            to: file,
            atomically: true,
            encoding: .utf8
        )

        return .merged(
            missing.count
        )
    }
}
