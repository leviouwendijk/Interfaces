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
