import Arguments
import Foundation
import Interfaces

@main
enum GitManagerCLICommand: ArgumentCommand {
    static let name = "gm"
    static let aliases = [
        "gcm",
    ]

    static let defaultChild = HelpCommand.self

    static let children: [ArgumentCommandType] = [
        HelpCommand.self,
        StatusCommand.self,
        ChangesCommand.self,
        DiffCommand.self,
        FetchCommand.self,
        IncomingCommand.self,
        OutgoingCommand.self,
        ConflictsCommand.self,
        RebaseCommand.self,
        ReconcileCommand.self,
        ScanCommand.self,
        SaveCommand.self,
        CommitCommand.self,
        PullCommand.self,
        PushCommand.self,
        SyncCommand.self,
        ResetCommand.self,
        RawCommand.self,
        InitCommand.self,
    ]

    static func main() async {
        await ArgumentProgram.main(
            command: Self.self,
            errorHandler: { error in
                GitManagerCLI.writeError(
                    error
                )

                return 1
            }
        )
    }
}
