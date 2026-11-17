import ANSI
import Arguments
import Foundation
import Interfaces

enum GitManagerCLI {
    static var currentDirectory: URL {
        URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
    }

    static func expandedPath(
        _ value: String
    ) -> URL {
        let expanded = (value as NSString).expandingTildeInPath

        if expanded.hasPrefix("/") {
            return URL(
                fileURLWithPath: expanded
            )
        }

        return currentDirectory.appendingPathComponent(
            expanded
        )
    }

    static func message(
        from invocation: ParsedInvocation,
        parameter: String = "message"
    ) throws -> String {
        let values = try invocation.values(
            ParamName(parameter),
            as: String.self
        )

        let message = values
            .joined(
                separator: " "
            )
            .trimmingCharacters(
                in: CharacterSet.whitespacesAndNewlines
            )

        guard !message.isEmpty else {
            throw GitManagerError.missingCommitMessage
        }

        return message
    }

    static func stagingComponents() -> [CommandComponentLowerable] {
        [
            opt(
                "only",
                short: "o",
                as: String.self,
                take: .repeating,
                help: "Stage only this path (repeatable). Relative to the current directory."
            ),
            opt(
                "exclude",
                short: "x",
                as: String.self,
                take: .repeating,
                help: "Do not stage this path (repeatable). Relative to the current directory."
            ),
            flag(
                "staged",
                help: "Stage nothing; commit what is already staged."
            ),
        ]
    }

    static func staging(
        from invocation: ParsedInvocation
    ) throws -> GitManagerStaging {
        let only = try invocation.values(
            "only",
            as: String.self
        )

        let exclusions = try invocation.values(
            "exclude",
            as: String.self
        )

        if try invocation.flag("staged") {
            guard only.isEmpty,
                  exclusions.isEmpty
            else {
                throw GitManagerError.unsafeSync(
                    "--staged cannot be combined with --only or --exclude."
                )
            }

            return .index
        }

        return .paths(
            only.isEmpty
                ? [GitManagerAction.wholeTreePathspec]
                : only,
            excluding: exclusions
        )
    }

    static func renderStaging(
        _ staging: GitManagerStaging
    ) {
        switch staging {
        case .paths(let paths, let exclusions):
            let pathspecs = paths + exclusions.map {
                "':(exclude)\($0)'"
            }

            GitManagerRenderer.command(
                "git add -- " + pathspecs.joined(
                    separator: " "
                )
            )

        case .index:
            break
        }
    }

    static func writeError(
        _ error: Error
    ) {
        let message = (error as? LocalizedError)?.errorDescription
            ?? String(
                describing: error
            )

        FileHandle.standardError.write(
            Data(
                (message.ansi(.red) + "\n").utf8
            )
        )
    }
}
