import Arguments
import Foundation
import Interfaces

enum ReconcileCommand: RunnableArgumentCommand {
    static let name = "reconcile"
    static let aliases = [
        "rec",
    ]

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Diagnose dirty/ahead/behind states and suggest a safe next action."),
            flag(
                "fetch",
                help: "Fetch before reconciling."
            ),
            flag(
                "stat",
                help: "Show git diff --stat @{u} when local tracked files differ from upstream."
            ),
            flag(
                "apply",
                help: "Apply only the safe reset-to-upstream reconciliation."
            ),
            flag(
                "clean",
                help: "With --apply, also remove untracked files."
            ),
            example(
                "gm reconcile",
                description: "Diagnose current repo and suggest the next command."
            ),
            example(
                "gm reconcile --stat",
                description: "Also show the diff stat against upstream."
            ),
            example(
                "gm reconcile --apply",
                description: "Run the safe reset when working tree already matches upstream."
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

        let apply = try invocation.flag(
            "apply"
        )

        let clean = try invocation.flag(
            "clean"
        )

        let result = try await GitManagerReconciler.reconcile(
            at: GitManagerCLI.currentDirectory,
            fetch: fetch,
            apply: apply,
            cleanUntracked: clean
        )

        GitManagerRenderer.state(
            result.state,
            porcelain: false
        )

        print(
            "reconcile".ansi(
                .bold,
                .brightWhite
            )
        )

        if let trackedMatchesUpstream = result.trackedMatchesUpstream {
            print(
                row(
                    "tracked == upstream",
                    trackedMatchesUpstream ? "yes" : "no"
                )
            )
        }

        print(
            row(
                "recommendation",
                result.recommendation.rawValue
            )
        )

        print("")
        print(
            result.recommendation.summary
        )

        if stat,
           !result.upstreamDiffStat.trimmingCharacters(
                in: .whitespacesAndNewlines
           )
           .isEmpty {
            print("")
            print(
                "diff against upstream".ansi(
                    .bold,
                    .brightWhite
                )
            )

            GitManagerRenderer.output(
                result.upstreamDiffStat
            )
        }

        if let applied = result.applied {
            print("")
            GitManagerRenderer.success(
                "Applied: \(applied.rawValue)"
            )

            return
        }

        if !result.recommendation.commands.isEmpty {
            print("")
            print(
                "next".ansi(
                    .bold,
                    .brightWhite
                )
            )

            for command in result.recommendation.commands {
                print(
                    "  \(command)"
                )
            }
        }

        if result.recommendation == .resetHardUpstream {
            print("")
            print(
                "To perform this through gm:".ansi(.brightBlack)
            )
            print(
                "  gm reconcile --apply"
            )
        }
    }
}

private extension ReconcileCommand {
    static func row(
        _ key: String,
        _ value: String
    ) -> String {
        "\(key.padded(to: 22).ansi(.brightBlack)) \(value)"
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
