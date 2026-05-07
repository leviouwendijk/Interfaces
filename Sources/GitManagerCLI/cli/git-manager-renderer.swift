import ANSI
import Foundation
import Interfaces

enum GitManagerRenderer {
    static func states(
        _ states: [GitManagerRepositoryState],
        porcelain: Bool
    ) {
        if porcelain {
            for state in states {
                self.state(
                    state,
                    porcelain: true
                )
            }

            return
        }

        guard !states.isEmpty else {
            print(
                "No repositories found.".ansi(.yellow)
            )

            return
        }

        let nameWidth = max(
            12,
            states.map(\.displayName.count).max() ?? 12
        )

        let branchWidth = max(
            8,
            states.map { ($0.branch ?? "-").count }.max() ?? 8
        )

        print("")
        print(
            "repositories".ansi(
                .bold,
                .brightWhite
            )
        )

        for state in states {
            let changes = GitManagerChangeSummary(
                porcelain: state.porcelain
            )

            let name = state.displayName.padded(
                to: nameWidth
            )

            let branch = (state.branch ?? "-").padded(
                to: branchWidth
            )

            let ahead = String(
                state.ahead ?? 0
            )
            .leftPadded(
                to: 3
            )

            let behind = String(
                state.behind ?? 0
            )
            .leftPadded(
                to: 3
            )

            let dirty = changes.trackedCount > 0 ? "dirty" : "clean"
            let untracked = changes.untrackedCount > 0 ? "untracked" : ""

            print(
                "\(name)  \(branch)  +\(ahead) -\(behind)  \(dirty.padded(to: 6))  \(untracked.padded(to: 9))  \(styled(state.classification))"
            )
        }

        print("")
    }

    static func state(
        _ state: GitManagerRepositoryState,
        porcelain: Bool
    ) {
        let summary = GitManagerChangeSummary(
            porcelain: state.porcelain
        )

        print("")
        print(
            state.displayName.ansi(
                .bold,
                .brightWhite
            )
        )

        print(
            row(
                "path",
                state.root?.path ?? state.directory.path
            )
        )

        print(
            row(
                "branch",
                state.branch ?? "unknown"
            )
        )

        print(
            row(
                "upstream",
                state.upstreamDisplay ?? "none"
            )
        )

        if let ahead = state.ahead {
            print(
                row(
                    "ahead",
                    "\(ahead)"
                )
            )
        }

        if let behind = state.behind {
            print(
                row(
                    "behind",
                    "\(behind)"
                )
            )
        }

        print(
            row(
                "tracked",
                state.hasTrackedChanges ? "dirty" : "clean"
            )
        )

        print(
            row(
                "untracked",
                state.hasUntracked ? "yes" : "no"
            )
        )

        print(
            row(
                "state",
                styled(
                    state.classification
                )
            )
        )

        if summary.hasChanges {
            print("")
            print(
                "changes".ansi(
                    .bold,
                    .brightWhite
                )
            )

            if !summary.modified.isEmpty {
                printChangeGroup(
                    title: "modified",
                    paths: summary.modified,
                    color: .yellow
                )
            }

            if !summary.deleted.isEmpty {
                printChangeGroup(
                    title: "deleted",
                    paths: summary.deleted,
                    color: .red
                )
            }

            if !summary.added.isEmpty {
                printChangeGroup(
                    title: "added",
                    paths: summary.added,
                    color: .green
                )
            }

            if !summary.renamed.isEmpty {
                printChangeGroup(
                    title: "renamed",
                    paths: summary.renamed,
                    color: .cyan
                )
            }

            if !summary.untracked.isEmpty {
                printChangeGroup(
                    title: "untracked",
                    paths: summary.untracked,
                    color: .brightBlack
                )
            }
        }

        if porcelain {
            let raw = state.porcelain.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            print("")
            print(
                "porcelain".ansi(
                    .bold,
                    .brightWhite
                )
            )

            if raw.isEmpty {
                print(
                    "  <empty>".ansi(.brightBlack)
                )
            } else {
                print(raw)
            }
        }

        print("")
    }

    static func command(
        _ text: String
    ) {
        print(
            "Running ".ansi(.brightBlack)
                + text.ansi(.green)
        )
    }

    static func output(
        _ text: String
    ) {
        let trimmed = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            return
        }

        print(trimmed)
    }

    static func success(
        _ text: String
    ) {
        print(
            text.ansi(.green)
        )
    }
}

private extension GitManagerRenderer {
    static func row(
        _ key: String,
        _ value: String
    ) -> String {
        "\(key.padded(to: 10).ansi(.brightBlack)) \(value)"
    }

    static func printChangeGroup(
        title: String,
        paths: [String],
        color: ANSIColor,
        limit: Int = 12
    ) {
        guard !paths.isEmpty else {
            return
        }

        print(
            "  \(title.padded(to: 10).ansi(color)) \(paths.count)"
        )

        for path in paths.prefix(limit) {
            print(
                "    \(path)"
            )
        }

        if paths.count > limit {
            print(
                "    … \(paths.count - limit) more".ansi(.brightBlack)
            )
        }
    }

    static func styled(
        _ classification: GitManagerRepositoryClassification
    ) -> String {
        switch classification {
        case .upToDate:
            return classification.rawValue.ansi(.green)

        case .ahead:
            return classification.rawValue.ansi(.cyan)

        case .behind:
            return classification.rawValue.ansi(.yellow)

        case .diverged:
            return classification.rawValue.ansi(.red)

        case .dirty:
            return classification.rawValue.ansi(.yellow)

        case .untracked:
            return classification.rawValue.ansi(.yellow)

        case .noUpstream:
            return classification.rawValue.ansi(.red)

        case .notGitRepository:
            return classification.rawValue.ansi(.red)

        case .unknown:
            return classification.rawValue.ansi(.brightBlack)
        }
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

    func leftPadded(
        to width: Int
    ) -> String {
        guard count < width else {
            return self
        }

        return String(
            repeating: " ",
            count: width - count
        ) + self
    }
}
