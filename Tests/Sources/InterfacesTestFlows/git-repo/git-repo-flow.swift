import Foundation
import Interfaces
import TestFlows

extension InterfacesFlowSuite {
    static var gitRepoFlow: TestFlow {
        TestFlow(
            "git-repo",
            tags: [
                "git",
                "process",
                "regression",
            ]
        ) {
            Step("execute git in requested working directory") {
                let fixture = try GitRepoFixture()

                defer {
                    fixture.remove()
                }

                let initialize = try await GitRepo.git(
                    fixture.root,
                    [
                        "init",
                        "-q",
                    ]
                )

                try Expect.equal(
                    initialize.code,
                    0,
                    "git init succeeds"
                )

                let result = try await GitRepo.git(
                    fixture.root,
                    [
                        "rev-parse",
                        "--show-toplevel",
                    ]
                )

                try Expect.equal(
                    result.code,
                    0,
                    "rev-parse succeeds"
                )

                let reportedRoot = URL(
                    fileURLWithPath: result.out
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                )
                .standardizedFileURL

                try Expect.equal(
                    reportedRoot.path,
                    fixture.root.standardizedFileURL.path,
                    "git executes in supplied working directory"
                )
            }

            Step("apply noninteractive git environment") {
                let fixture = try GitRepoFixture()

                defer {
                    fixture.remove()
                }

                let result = try await GitRepo.git(
                    fixture.root,
                    [
                        "var",
                        "GIT_EDITOR",
                    ]
                )

                try Expect.equal(
                    result.code,
                    0,
                    "git var succeeds"
                )

                try Expect.equal(
                    result.out
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ),
                    "true",
                    "GIT_EDITOR remains noninteractive"
                )
            }

            Step("nonzero git exit remains a normal result") {
                let fixture = try GitRepoFixture()

                defer {
                    fixture.remove()
                }

                _ = try await GitRepo.git(
                    fixture.root,
                    [
                        "init",
                        "-q",
                    ]
                )

                let result = try await GitRepo.git(
                    fixture.root,
                    [
                        "rev-parse",
                        "--verify",
                        "refs/heads/definitely-missing",
                    ]
                )

                try Expect.true(
                    result.code != 0,
                    "nonzero git status is returned"
                )
            }
            Step("timeout remains a returned git failure") {
                let fixture = try GitRepoFixture()

                defer {
                    fixture.remove()
                }

                _ = try await GitRepo.git(
                    fixture.root,
                    [
                        "init",
                        "-q",
                    ]
                )

                let result = try await GitRepo.git(
                    fixture.root,
                    [
                        "-c",
                        "alias.wait=!printf before; sleep 2",
                        "wait",
                    ],
                    timeout: 0.1
                )

                try Expect.true(
                    result.code != 0,
                    "timed out git command returns nonzero status"
                )

                try Expect.contains(
                    result.out,
                    "before",
                    "stdout emitted before timeout is preserved"
                )

                try Expect.contains(
                    result.err,
                    "Timed out after",
                    "timeout remains visible in stderr"
                )
            }
        }
    }
}

private struct GitRepoFixture {
    let root: URL

    init() throws {
        root = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "interfaces-git-repo-\(UUID().uuidString)",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
    }

    func remove() {
        try? FileManager.default.removeItem(
            at: root
        )
    }
}
