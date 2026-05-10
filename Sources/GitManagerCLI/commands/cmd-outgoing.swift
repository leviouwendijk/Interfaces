import Arguments
import Foundation
import Interfaces

enum OutgoingCommand: RunnableArgumentCommand {
    static let name = "outgoing"

    static let aliases = [
        "out",
    ]

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Show commits and files that exist locally but not upstream."),
            flag(
                "fetch",
                help: "Fetch before inspecting outgoing commits."
            ),
            flag(
                "stat",
                help: "Show diff stat for outgoing commits."
            ),
            flag(
                "name-only",
                help: "Only show outgoing file paths."
            ),
            opt(
                "limit",
                as: Int.self,
                default: 30,
                help: "Maximum number of commits to show."
            ),
            example(
                "gm outgoing",
                description: "Show local commits not yet upstream."
            ),
            example(
                "gm outgoing --stat",
                description: "Show local commits and diff stat."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let fetch = try invocation.flag(
            "fetch"
        )

        let stat = try invocation.flag(
            "stat"
        )

        let nameOnly = try invocation.flag(
            "name-only"
        )

        let limit = try invocation.value(
            "limit",
            as: Int.self
        ) ?? 30

        let root = try await requireRoot()

        if fetch {
            GitManagerRenderer.command(
                "git fetch <default-remote> <default-branch>"
            )

            _ = try await GitRepo.fetchDefaultRemote(
                root,
                purpose: .stateCheck
            )
        }

        let state = try await GitManagerRepositoryInspector.state(
            at: root,
            fetch: false
        )

        GitManagerRenderer.state(
            state,
            porcelain: false
        )

        print(
            "outgoing".ansi(
                .bold,
                .brightWhite
            )
        )

        print(
            row(
                "meaning",
                "commits reachable from HEAD that are not reachable from @{u}"
            )
        )

        print(
            row(
                "range",
                "@{u}..HEAD"
            )
        )

        print("")

        if nameOnly {
            print(
                "files".ansi(
                    .bold,
                    .brightWhite
                )
            )

            GitManagerRenderer.output(
                try await GitManagerAction.raw(
                    [
                        "diff",
                        "--name-status",
                        "@{u}..HEAD",
                    ],
                    at: root
                )
            )

            return
        }

        print(
            "commits".ansi(
                .bold,
                .brightWhite
            )
        )

        GitManagerRenderer.output(
            try await GitManagerAction.raw(
                [
                    "log",
                    "--oneline",
                    "--decorate",
                    "--max-count=\(limit)",
                    "@{u}..HEAD",
                ],
                at: root
            )
        )

        if stat {
            print("")
            print(
                "diff stat".ansi(
                    .bold,
                    .brightWhite
                )
            )

            GitManagerRenderer.output(
                try await GitManagerAction.raw(
                    [
                        "diff",
                        "--stat",
                        "@{u}..HEAD",
                    ],
                    at: root
                )
            )
        }
    }
}

private extension OutgoingCommand {
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

    static func row(
        _ key: String,
        _ value: String
    ) -> String {
        "\(key.padded(to: 10).ansi(.brightBlack)) \(value)"
    }
}

private extension String {
    func padded(
        to width: Int
    ) -> String {
        guard count < width else {
            return self
        }

        return self + String(
            repeating: " ",
            count: width - count
        )
    }
}
