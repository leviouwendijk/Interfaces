import Foundation
import Interfaces
import TestFlows

extension InterfacesFlowSuite {
    static var gitManagerDiffFlow: TestFlow {
        TestFlow(
            "git-manager-diff",
            tags: [
                "git",
                "diff",
                "observe",
                "regression",
            ]
        ) {
            Step(
                "observe working diff with literal path filter"
            ) {
                let fixture =
                    try await GitManagerDiffFixture
                        .make()

                defer {
                    fixture.remove()
                }

                try fixture.write(
                    "alpha.txt",
                    """
                    alpha
                    working
                    """
                )

                try fixture.write(
                    "beta.txt",
                    """
                    beta
                    ignored-by-filter
                    """
                )

                let result =
                    try await GitManagerDiff.observe(
                        .init(
                            scope: .working,
                            paths: [
                                "alpha.txt",
                            ]
                        ),
                        at: fixture.root
                    )

                try Expect.equal(
                    result.hasChanges,
                    true,
                    "filtered working diff reports changes"
                )

                try Expect.equal(
                    result.sections.count,
                    1,
                    "working request returns one section"
                )

                let section =
                    try requireDiffSection(
                        .working,
                        in: result
                    )

                try Expect.equal(
                    section.changedPaths,
                    [
                        "alpha.txt",
                    ],
                    "literal path filter excludes unrelated file"
                )

                try Expect.equal(
                    section.insertions,
                    1,
                    "working diff insertion count"
                )

                try Expect.equal(
                    section.deletions,
                    0,
                    "working diff deletion count"
                )

                try Expect.contains(
                    section.patch,
                    "+working",
                    "working patch contains inserted content"
                )

                try Expect.equal(
                    section.truncated,
                    false,
                    "normal patch is not truncated"
                )
            }

            Step(
                "separate staged and working sections"
            ) {
                let fixture =
                    try await GitManagerDiffFixture
                        .make()

                defer {
                    fixture.remove()
                }

                try fixture.write(
                    "alpha.txt",
                    """
                    alpha
                    staged-change
                    """
                )

                try fixture.write(
                    "beta.txt",
                    """
                    beta
                    working-change
                    """
                )

                _ = try await GitRepo.gitOut(
                    fixture.root,
                    [
                        "add",
                        "alpha.txt",
                    ]
                )

                let result =
                    try await GitManagerDiff.observe(
                        .init(
                            scope: .both
                        ),
                        at: fixture.root
                    )

                try Expect.equal(
                    result.sections.count,
                    2,
                    "both returns working and staged sections"
                )

                let working =
                    try requireDiffSection(
                        .working,
                        in: result
                    )

                let staged =
                    try requireDiffSection(
                        .staged,
                        in: result
                    )

                try Expect.equal(
                    working.changedPaths,
                    [
                        "beta.txt",
                    ],
                    "working section excludes staged-only file"
                )

                try Expect.equal(
                    staged.changedPaths,
                    [
                        "alpha.txt",
                    ],
                    "staged section excludes unstaged-only file"
                )

                try Expect.contains(
                    working.patch,
                    "+working-change",
                    "working patch contains working change"
                )

                try Expect.contains(
                    staged.patch,
                    "+staged-change",
                    "staged patch contains staged change"
                )
            }

            Step(
                "bound patch output without mutating repository"
            ) {
                let fixture =
                    try await GitManagerDiffFixture
                        .make()

                defer {
                    fixture.remove()
                }

                let body =
                    (0..<200)
                        .map {
                            "generated-line-\($0)"
                        }
                        .joined(
                            separator: "\n"
                        )
                    + "\n"

                try fixture.write(
                    "alpha.txt",
                    body
                )

                let beforeHead =
                    try await GitRepo.gitOut(
                        fixture.root,
                        [
                            "rev-parse",
                            "HEAD",
                        ]
                    )

                let beforeStatus =
                    try await GitRepo.gitOut(
                        fixture.root,
                        [
                            "status",
                            "--porcelain",
                        ]
                    )

                let result =
                    try await GitManagerDiff.observe(
                        .init(
                            scope: .working,
                            maxPatchBytes: 128
                        ),
                        at: fixture.root
                    )

                let section =
                    try requireDiffSection(
                        .working,
                        in: result
                    )

                try Expect.equal(
                    section.truncated,
                    true,
                    "oversized patch reports truncation"
                )

                try requireDiffFlow(
                    section.patchByteCount > 128,
                    "original patch byte count must exceed requested budget"
                )

                try requireDiffFlow(
                    Data(
                        section.patch.utf8
                    ).count <= 128,
                    "returned patch must respect byte budget"
                )

                let afterHead =
                    try await GitRepo.gitOut(
                        fixture.root,
                        [
                            "rev-parse",
                            "HEAD",
                        ]
                    )

                let afterStatus =
                    try await GitRepo.gitOut(
                        fixture.root,
                        [
                            "status",
                            "--porcelain",
                        ]
                    )

                try Expect.equal(
                    afterHead,
                    beforeHead,
                    "diff observation does not move HEAD"
                )

                try Expect.equal(
                    afterStatus,
                    beforeStatus,
                    "diff observation does not change working state"
                )
            }

            Step(
                "reject parent traversal path"
            ) {
                let fixture =
                    try await GitManagerDiffFixture
                        .make()

                defer {
                    fixture.remove()
                }

                var rejected = false

                do {
                    _ = try await GitManagerDiff.observe(
                        .init(
                            paths: [
                                "../outside.txt",
                            ]
                        ),
                        at: fixture.root
                    )
                } catch GitManagerDiffError.invalidPath {
                    rejected = true
                }

                try Expect.equal(
                    rejected,
                    true,
                    "parent traversal path is rejected before Git execution"
                )
            }
        }
    }
}

private enum GitManagerDiffFlowFailure:
    Error
{
    case assertion(String)
}

private func requireDiffFlow(
    _ condition: Bool,
    _ message: String
) throws {
    guard condition else {
        throw GitManagerDiffFlowFailure
            .assertion(
                message
            )
    }
}

private func requireDiffSection(
    _ scope: GitManagerDiffScope,
    in result: GitManagerDiffResult
) throws -> GitManagerDiffSection {
    guard let section =
        result.sections.first(
            where: {
                $0.scope == scope
            }
        )
    else {
        throw GitManagerDiffFlowFailure
            .assertion(
                "Missing \(scope.rawValue) diff section."
            )
    }

    return section
}

private struct GitManagerDiffFixture {
    let root: URL

    init() throws {
        root =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "interfaces-git-manager-diff-\(UUID().uuidString)",
                    isDirectory: true
                )

        try FileManager.default
            .createDirectory(
                at: root,
                withIntermediateDirectories:
                    true
            )
    }

    static func make() async throws -> Self {
        let fixture = try Self()

        do {
            try await fixture.initialize()
            return fixture
        } catch {
            fixture.remove()
            throw error
        }
    }

    func initialize() async throws {
        _ = try await GitRepo.gitOut(
            root,
            [
                "init",
                "-q",
            ]
        )

        try write(
            "alpha.txt",
            """
            alpha
            """
        )

        try write(
            "beta.txt",
            """
            beta
            """
        )

        _ = try await GitRepo.gitOut(
            root,
            [
                "add",
                "alpha.txt",
                "beta.txt",
            ]
        )

        _ = try await GitRepo.gitOut(
            root,
            [
                "-c",
                "user.name=Agentic Test",
                "-c",
                "user.email=agentic@example.invalid",
                "commit",
                "-q",
                "-m",
                "initial",
            ]
        )
    }

    func write(
        _ relativePath: String,
        _ content: String
    ) throws {
        let normalizedContent =
            content.hasSuffix("\n")
            ? content
            : content + "\n"

        try Data(
            normalizedContent.utf8
        ).write(
            to:
                root.appendingPathComponent(
                    relativePath,
                    isDirectory: false
                ),
            options:
                .atomic
        )
    }

    func remove() {
        try? FileManager.default
            .removeItem(
                at: root
            )
    }
}
