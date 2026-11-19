import Arguments
import Foundation

enum IgnoreCommand: RunnableArgumentCommand {
    static let name = "ignore"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Merge missing default entries into .gitignore, keeping everything already there."),
            flag(
                "dry-run",
                help: "List the default entries .gitignore is missing without writing."
            ),
            example(
                "gm ignore",
                description: "Append missing defaults under a '# gm defaults' heading."
            ),
            example(
                "gm ignore --dry-run",
                description: "Show which defaults are missing."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let directory = GitManagerCLI.currentDirectory

        if try invocation.flag("dry-run") {
            let missing = try GitignoreDefaults.missing(in: directory)
            guard !missing.isEmpty else {
                GitManagerRenderer.success(".gitignore already contains all default entries.")
                return
            }
            GitManagerRenderer.output(
                "Missing from .gitignore:\n" + missing.map { "  \($0)" }.joined(separator: "\n")
            )
            return
        }

        switch try GitignoreDefaults.merge(in: directory) {
        case .created(let count):
            GitManagerRenderer.success("Created .gitignore with \(count) entries.")
        case .merged(let entries):
            GitManagerRenderer.success(
                "Merged \(entries.count) missing .gitignore entries: \(entries.joined(separator: ", "))."
            )
        case .unchanged:
            GitManagerRenderer.success(".gitignore already contains all default entries.")
        }
    }
}
