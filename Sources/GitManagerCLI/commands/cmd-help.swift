import Arguments
import Foundation

enum HelpCommand: RunnableArgumentCommand {
    static let name = "help"

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        print(
            ArgumentHelpRenderer().render(
                command: try GitManagerCLICommand.spec()
            )
        )
    }
}
