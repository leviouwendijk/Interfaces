import Foundation
import Interfaces
import TestFlows

extension InterfacesFlowSuite {
    static var gitRepoAcquisitionFlow: TestFlow {
        TestFlow(
            "git-repo-acquisition",
            tags: [
                "git",
                "clone",
                "revision",
                "regression",
            ]
        ) {
            Step("clone repository and resolve immutable commit") {
                let fixture = try GitRepoAcquisitionFixture()

                defer {
                    fixture.remove()
                }

                try await fixture.initialize()

                let expected = try await GitRepo.resolveCommit(
                    "HEAD",
                    at: fixture.source
                )

                try await GitRepo.clone(
                    fixture.source,
                    to: fixture.clone
                )

                let actual = try await GitRepo.resolveCommit(
                    "HEAD",
                    at: fixture.clone
                )

                try Expect.equal(
                    actual,
                    expected,
                    "cloned repository resolves the same immutable HEAD commit"
                )
            }
        }
    }
}

private struct GitRepoAcquisitionFixture {
    let root: URL
    let source: URL
    let clone: URL

    init() throws {
        root = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "interfaces-git-acquisition-\(UUID().uuidString)",
                isDirectory: true
            )

        source = root.appendingPathComponent(
            "source",
            isDirectory: true
        )

        clone = root.appendingPathComponent(
            "clone",
            isDirectory: true
        )

        try FileManager.default.createDirectory(
            at: source,
            withIntermediateDirectories: true
        )
    }

    func initialize() async throws {
        _ = try await GitRepo.gitOut(
            source,
            [
                "init",
                "-q",
            ]
        )

        try Data(
            "fixture\n".utf8
        ).write(
            to: source.appendingPathComponent(
                "fixture.txt",
                isDirectory: false
            ),
            options: .atomic
        )

        _ = try await GitRepo.gitOut(
            source,
            [
                "add",
                "fixture.txt",
            ]
        )

        _ = try await GitRepo.gitOut(
            source,
            [
                "-c",
                "user.name=Interfaces Test",
                "-c",
                "user.email=interfaces@example.invalid",
                "-c",
                "commit.gpgSign=false",
                "commit",
                "-q",
                "-m",
                "fixture",
            ]
        )
    }

    func remove() {
        try? FileManager.default.removeItem(
            at: root
        )
    }
}
