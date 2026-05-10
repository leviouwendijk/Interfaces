import Arguments
import Foundation
import Interfaces

enum RebaseCommand: RunnableArgumentCommand {
    static let name = "rebase"

    static let aliases = [
        "rb",
    ]

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Rebase local commits on top of upstream, or continue/abort an active rebase."),
            flag(
                "fetch",
                help: "Fetch before starting the rebase."
            ),
            flag(
                "continue",
                help: "Continue an active rebase after conflicts have been resolved."
            ),
            flag(
                "abort",
                help: "Abort the active rebase."
            ),
            flag(
                "skip",
                help: "Skip the current commit during an active rebase."
            ),
            opt(
                "onto",
                as: String.self,
                help: "Rebase onto this ref. Defaults to @{u}."
            ),
            example(
                "gm rebase --fetch",
                description: "Fetch and rebase local commits on top of upstream."
            ),
            example(
                "gm rebase --continue",
                description: "Continue an active rebase."
            ),
            example(
                "gm rebase --abort",
                description: "Abort an active rebase."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let fetch = try invocation.flag(
            "fetch"
        )

        let continueRebase = try invocation.flag(
            "continue"
        )

        let abort = try invocation.flag(
            "abort"
        )

        let skip = try invocation.flag(
            "skip"
        )

        let onto = try invocation.value(
            "onto",
            as: String.self
        )?
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let selectedActions = [
            continueRebase,
            abort,
            skip,
        ]
        .filter { $0 }
        .count

        guard selectedActions <= 1 else {
            throw GitManagerError.unsafeSync(
                "Use only one of --continue, --abort, or --skip."
            )
        }

        let root = try await requireRoot()

        if fetch,
           !continueRebase,
           !abort,
           !skip {
            GitManagerRenderer.command(
                "git fetch <default-remote> <default-branch>"
            )

            _ = try await GitRepo.fetchDefaultRemote(
                root,
                purpose: .stateCheck
            )
        }

        if continueRebase {
            try await runGit(
                [
                    "rebase",
                    "--continue",
                ],
                display: "git rebase --continue",
                at: root
            )

            try await renderState(
                at: root
            )

            return
        }

        if abort {
            try await runGit(
                [
                    "rebase",
                    "--abort",
                ],
                display: "git rebase --abort",
                at: root
            )

            try await renderState(
                at: root
            )

            return
        }

        if skip {
            try await runGit(
                [
                    "rebase",
                    "--skip",
                ],
                display: "git rebase --skip",
                at: root
            )

            try await renderState(
                at: root
            )

            return
        }

        let target = (onto?.isEmpty == false)
            ? onto!
            : "@{u}"

        try await runGit(
            [
                "rebase",
                target,
            ],
            display: "git rebase \(target)",
            at: root
        )

        try await renderState(
            at: root
        )
    }
}

private extension RebaseCommand {
    static func runGit(
        _ arguments: [String],
        display: String,
        at root: URL
    ) async throws {
        GitManagerRenderer.command(
            display
        )

        GitManagerRenderer.output(
            try await GitManagerAction.raw(
                arguments,
                at: root
            )
        )
    }

    static func renderState(
        at root: URL
    ) async throws {
        let state = try await GitManagerRepositoryInspector.state(
            at: root,
            fetch: false
        )

        GitManagerRenderer.state(
            state,
            porcelain: false
        )
    }

    static func requireRoot() async throws -> URL {
        let state = try await GitManagerRepositoryInspector.state(
            at: GitManagerCLI.currentDirectory,
            fetch: false
        )

        guard let root = state.root else {
            throw GitManagerError.notGitRepository(
                GitManagerCLI.currentDirectory.path
            )
        }

        return root
    }
}
