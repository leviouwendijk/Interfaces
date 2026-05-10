import Arguments
import Foundation
import Interfaces

enum ConflictsCommand: RunnableArgumentCommand {
    static let name = "conflicts"

    static let aliases = [
        "cf",
    ]

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Explain active merge/rebase conflicts and show conflict marker locations."),
            flag(
                "markers",
                help: "Show lines containing conflict markers."
            ),
            flag(
                "patch",
                help: "Show the raw combined conflict diff."
            ),
            example(
                "gm conflicts",
                description: "Show conflicted files and next steps."
            ),
            example(
                "gm conflicts --markers",
                description: "Show conflict marker line numbers."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let markers = try invocation.flag(
            "markers"
        )

        let patch = try invocation.flag(
            "patch"
        )

        let root = try await requireRoot()
        let operation = try await currentOperation(
            at: root
        )

        print("")
        print(
            "operation".ansi(
                .bold,
                .brightWhite
            )
        )

        print(
            row(
                "state",
                operation.rawValue
            )
        )

        print("")

        let conflicted = try await conflictedPaths(
            at: root
        )

        guard !conflicted.isEmpty else {
            print(
                "No conflicted files.".ansi(.green)
            )

            print("")
            print(
                "next".ansi(
                    .bold,
                    .brightWhite
                )
            )

            switch operation {
            case .rebase:
                print("  gm rebase --continue")

            case .merge:
                print("  git commit")

            case .none:
                print("  gm status")
            }

            return
        }

        print(
            "conflicts".ansi(
                .bold,
                .brightWhite
            )
        )

        for path in conflicted {
            print(
                "  \(path)"
            )

            if markers {
                let markerLines = conflictMarkerLines(
                    in: root.appendingPathComponent(
                        path
                    )
                )

                for marker in markerLines {
                    print(
                        "    line \(marker.line): \(marker.text)"
                    )
                }
            }
        }

        print("")
        print(
            "how to read markers".ansi(
                .bold,
                .brightWhite
            )
        )

        print("  <<<<<<< HEAD     current checkout during this operation")
        print("  =======          separator")
        print("  >>>>>>> commit   commit currently being applied or merged")

        print("")
        print(
            "next".ansi(
                .bold,
                .brightWhite
            )
        )

        print("  edit conflicted files")
        print("  remove <<<<<<<, =======, and >>>>>>> marker lines")
        print("  git add <resolved-files>")

        switch operation {
        case .rebase:
            print("  gm rebase --continue")
            print("  gm rebase --abort")

        case .merge:
            print("  git commit")
            print("  git merge --abort")

        case .none:
            print("  gm status")
        }

        if patch {
            print("")
            print(
                "combined diff".ansi(
                    .bold,
                    .brightWhite
                )
            )

            GitManagerRenderer.output(
                try await GitManagerAction.raw(
                    [
                        "diff",
                    ],
                    at: root
                )
            )
        }
    }
}

private extension ConflictsCommand {
    enum GitOperation: String {
        case none
        case merge
        case rebase
    }

    struct MarkerLine {
        let line: Int
        let text: String
    }

    static func currentOperation(
        at root: URL
    ) async throws -> GitOperation {
        let gitDirOutput = try await GitManagerAction.raw(
            [
                "rev-parse",
                "--git-dir",
            ],
            at: root
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let gitDir: URL

        if gitDirOutput.hasPrefix("/") {
            gitDir = URL(
                fileURLWithPath: gitDirOutput
            )
        } else {
            gitDir = root.appendingPathComponent(
                gitDirOutput
            )
        }

        let rebaseMerge = gitDir.appendingPathComponent(
            "rebase-merge"
        )

        let rebaseApply = gitDir.appendingPathComponent(
            "rebase-apply"
        )

        let mergeHead = gitDir.appendingPathComponent(
            "MERGE_HEAD"
        )

        if FileManager.default.fileExists(
            atPath: rebaseMerge.path
        ) || FileManager.default.fileExists(
            atPath: rebaseApply.path
        ) {
            return .rebase
        }

        if FileManager.default.fileExists(
            atPath: mergeHead.path
        ) {
            return .merge
        }

        return .none
    }

    static func conflictedPaths(
        at root: URL
    ) async throws -> [String] {
        let output = try await GitManagerAction.raw(
            [
                "diff",
                "--name-only",
                "--diff-filter=U",
            ],
            at: root
        )

        return output
            .split(
                separator: "\n"
            )
            .map(String.init)
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }
    }

    static func conflictMarkerLines(
        in file: URL
    ) -> [MarkerLine] {
        guard let content = try? String(
            contentsOf: file,
            encoding: .utf8
        ) else {
            return []
        }

        return content
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .enumerated()
            .compactMap { index, line in
                let text = String(line)

                guard text.hasPrefix("<<<<<<<")
                    || text.hasPrefix("=======")
                    || text.hasPrefix(">>>>>>>")
                else {
                    return nil
                }

                return MarkerLine(
                    line: index + 1,
                    text: text
                )
            }
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
