import Arguments
import Foundation
import Interfaces

enum DiffCommand: RunnableArgumentCommand {
    static let name = "diff"

    static let aliases = [
        "d",
    ]

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Explain local, incoming, and outgoing differences without dumping a full patch by default."),
            flag(
                "fetch",
                help: "Fetch before showing the diff dashboard."
            ),
            flag(
                "patch",
                help: "Show raw git diff patch."
            ),
            flag(
                "stat",
                help: "Show diff stat."
            ),
            flag(
                "name-only",
                help: "Only show changed file names."
            ),
            flag(
                "cached",
                help: "Use staged changes for local patch/stat/name-only."
            ),
            opt(
                "against",
                as: String.self,
                help: "Compare working tree against a specific ref. Defaults to HEAD for local patch/stat/name-only."
            ),
            example(
                "gm diff",
                description: "Show a difference dashboard."
            ),
            example(
                "gm diff --fetch",
                description: "Fetch, then show local/incoming/outgoing summaries."
            ),
            example(
                "gm diff --patch",
                description: "Show local raw patch against HEAD."
            ),
            example(
                "gm diff --against @{u} --stat",
                description: "Show stat comparing working tree against upstream."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let fetch = try invocation.flag(
            "fetch"
        )

        let patch = try invocation.flag(
            "patch"
        )

        let stat = try invocation.flag(
            "stat"
        )

        let nameOnly = try invocation.flag(
            "name-only"
        )

        let cached = try invocation.flag(
            "cached"
        )

        let against = try invocation.value(
            "against",
            as: String.self
        )?
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

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

        if patch || stat || nameOnly || against?.isEmpty == false {
            try await renderExplicitDiff(
                patch: patch,
                stat: stat,
                nameOnly: nameOnly,
                cached: cached,
                against: against,
                at: root
            )

            return
        }

        try await renderDashboard(
            at: root
        )
    }
}

private extension DiffCommand {
    static func renderDashboard(
        at root: URL
    ) async throws {
        print(
            "diff dashboard".ansi(
                .bold,
                .brightWhite
            )
        )

        print(
            row(
                "local",
                "working tree vs HEAD"
            )
        )

        print(
            row(
                "incoming",
                "HEAD..@{u}"
            )
        )

        print(
            row(
                "outgoing",
                "@{u}..HEAD"
            )
        )

        print("")

        print(
            "local changes".ansi(
                .bold,
                .brightWhite
            )
        )

        GitManagerRenderer.output(
            try await GitManagerAction.raw(
                [
                    "diff",
                    "--stat",
                ],
                at: root
            )
        )

        let cached = try await GitManagerAction.raw(
            [
                "diff",
                "--cached",
                "--stat",
            ],
            at: root
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if !cached.isEmpty {
            print("")
            print(
                "staged changes".ansi(
                    .bold,
                    .brightWhite
                )
            )

            GitManagerRenderer.output(
                cached
            )
        }

        print("")
        print(
            "incoming commits".ansi(
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
                    "--max-count=20",
                    "HEAD..@{u}",
                ],
                at: root
            )
        )

        print("")
        print(
            "outgoing commits".ansi(
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
                    "--max-count=20",
                    "@{u}..HEAD",
                ],
                at: root
            )
        )

        print("")
        print(
            "next".ansi(
                .bold,
                .brightWhite
            )
        )

        print("  gm changes --diff        # local patch")
        print("  gm incoming --stat       # remote changes not yet local")
        print("  gm outgoing --stat       # local commits not yet remote")
        print("  gm diff --patch          # raw local patch")
        print("  gm diff --against @{u}   # current files compared with upstream")
    }

    static func renderExplicitDiff(
        patch: Bool,
        stat: Bool,
        nameOnly: Bool,
        cached: Bool,
        against: String?,
        at root: URL
    ) async throws {
        let comparisonRef = (against?.isEmpty == false)
            ? against
            : nil

        print(
            "comparison".ansi(
                .bold,
                .brightWhite
            )
        )

        if let comparisonRef {
            print(
                row(
                    "meaning",
                    "working tree compared with \(comparisonRef)"
                )
            )
        } else if cached {
            print(
                row(
                    "meaning",
                    "staged changes compared with HEAD"
                )
            )
        } else {
            print(
                row(
                    "meaning",
                    "working tree compared with HEAD"
                )
            )
        }

        print("")

        var arguments = [
            "diff",
        ]

        if cached {
            arguments.append(
                "--cached"
            )
        }

        if stat {
            arguments.append(
                "--stat"
            )
        }

        if nameOnly {
            arguments.append(
                "--name-status"
            )
        }

        if let comparisonRef {
            arguments.append(
                comparisonRef
            )
        }

        if !patch,
           !stat,
           !nameOnly {
            arguments.append(
                "--stat"
            )
        }

        GitManagerRenderer.output(
            try await GitManagerAction.raw(
                arguments,
                at: root
            )
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
