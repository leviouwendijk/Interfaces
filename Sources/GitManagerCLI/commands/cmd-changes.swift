import Arguments
import Foundation
import Interfaces

enum ChangesCommand: RunnableArgumentCommand {
    static let name = "changes"
    static let aliases = [
        "ch",
    ]

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Show local changes and optional git diff output."),
            flag(
                "porcelain",
                help: "Also show raw git status --porcelain output."
            ),
            flag(
                "stat",
                help: "Show git diff --stat output."
            ),
            flag(
                "diff",
                help: "Show git diff output."
            ),
            flag(
                "cached",
                help: "Use staged changes for --stat or --diff."
            ),
            flag(
                "upstream",
                help: "Compare working tree against @{u} instead of HEAD."
            ),
            opt(
                "against",
                as: String.self,
                help: "Compare working tree against a specific ref, for example origin/master."
            ),
            example(
                "gm changes",
                description: "Show grouped local changes relative to HEAD."
            ),
            example(
                "gm changes --stat",
                description: "Show grouped local changes and diff stat relative to HEAD."
            ),
            example(
                "gm changes --diff",
                description: "Show grouped local changes and full diff relative to HEAD."
            ),
            example(
                "gm changes --upstream --stat",
                description: "Show diff stat against @{u}."
            ),
            example(
                "gm changes --against origin/master --diff",
                description: "Show diff against origin/master."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let porcelain = try invocation.flag(
            "porcelain"
        )

        let showStat = try invocation.flag(
            "stat"
        )

        let showDiff = try invocation.flag(
            "diff"
        )

        let cached = try invocation.flag(
            "cached"
        )

        let upstream = try invocation.flag(
            "upstream"
        )

        let against = try invocation.value(
            "against",
            as: String.self
        )

        let comparisonRef = try comparisonReference(
            upstream: upstream,
            against: against
        )

        let state = try await GitManagerRepositoryInspector.state(
            at: GitManagerCLI.currentDirectory,
            fetch: false
        )

        GitManagerRenderer.state(
            state,
            porcelain: porcelain
        )

        if let comparisonRef {
            print(
                "comparison".ansi(
                    .bold,
                    .brightWhite
                )
            )
            print(
                row(
                    "against",
                    comparisonRef
                )
            )
            print("")
        }

        if showStat {
            GitManagerRenderer.output(
                try await GitManagerAction.raw(
                    diffArguments(
                        stat: true,
                        cached: cached,
                        comparisonRef: comparisonRef
                    ),
                    at: GitManagerCLI.currentDirectory
                )
            )
        }

        if showDiff {
            GitManagerRenderer.output(
                try await GitManagerAction.raw(
                    diffArguments(
                        stat: false,
                        cached: cached,
                        comparisonRef: comparisonRef
                    ),
                    at: GitManagerCLI.currentDirectory
                )
            )
        }

        if !state.hasTrackedChanges,
           !state.hasUntracked {
            GitManagerRenderer.success(
                "Working tree clean."
            )
        }
    }
}

private extension ChangesCommand {
    static func comparisonReference(
        upstream: Bool,
        against: String?
    ) throws -> String? {
        if upstream,
           let against,
           !against.trimmingCharacters(
                in: .whitespacesAndNewlines
           )
           .isEmpty {
            throw GitManagerError.unsafeSync(
                "Use either --upstream or --against, not both."
            )
        }

        if upstream {
            return "@{u}"
        }

        let trimmed = against?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if let trimmed,
           !trimmed.isEmpty {
            return trimmed
        }

        return nil
    }

    static func diffArguments(
        stat: Bool,
        cached: Bool,
        comparisonRef: String?
    ) -> [String] {
        var arguments = [
            "diff",
        ]

        if stat {
            arguments.append(
                "--stat"
            )
        }

        if cached {
            arguments.append(
                "--cached"
            )
        }

        if let comparisonRef {
            arguments.append(
                comparisonRef
            )
        }

        return arguments
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
