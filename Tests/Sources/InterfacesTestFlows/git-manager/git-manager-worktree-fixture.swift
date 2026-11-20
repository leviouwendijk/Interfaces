import Foundation
import Interfaces

struct GitManagerWorktreeFixture {
    let root: URL
    let worktreesRoot: URL

    static func make() async throws -> GitManagerWorktreeFixture {
        let root = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "interfaces-git-manager-\(UUID().uuidString)",
                isDirectory: true
            )

        let worktreesRoot = root
            .deletingLastPathComponent()
            .appendingPathComponent(
                "\(root.lastPathComponent)-worktrees",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        try FileManager.default.createDirectory(
            at: worktreesRoot,
            withIntermediateDirectories: true
        )

        let fixture = GitManagerWorktreeFixture(
            root: root,
            worktreesRoot: worktreesRoot
        )

        _ = try await fixture.git(
            [
                "init",
                "-q",
                "-b",
                "master",
            ]
        )

        _ = try await fixture.git(
            [
                "config",
                "user.email",
                "interfaces@example.invalid",
            ]
        )

        _ = try await fixture.git(
            [
                "config",
                "user.name",
                "Interfaces Test",
            ]
        )

        try fixture.write(
            "base\n",
            path: "shared.txt",
            at: root
        )

        _ = try await fixture.git(
            [
                "add",
                "shared.txt",
            ]
        )

        _ = try await fixture.git(
            [
                "commit",
                "-q",
                "-m",
                "base",
            ]
        )

        return fixture
    }

    func git(
        _ arguments: [String],
        at directory: URL? = nil
    ) async throws -> String {
        try await GitRepo.gitOut(
            directory ?? root,
            arguments
        )
    }

    func head(
        at directory: URL? = nil
    ) async throws -> String {
        try await git(
            [
                "rev-parse",
                "HEAD",
            ],
            at: directory
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    func branch(
        at directory: URL
    ) async throws -> String {
        try await git(
            [
                "branch",
                "--show-current",
            ],
            at: directory
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    func write(
        _ content: String,
        path: String,
        at directory: URL
    ) throws {
        let url = directory.appendingPathComponent(
            path
        )

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try content.write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
    }

    func read(
        _ path: String,
        at directory: URL
    ) throws -> String {
        try String(
            contentsOf: directory.appendingPathComponent(
                path
            ),
            encoding: .utf8
        )
    }

    func commit(
        _ message: String,
        paths: [String],
        at directory: URL
    ) async throws {
        _ = try await git(
            [
                "add",
            ] + paths,
            at: directory
        )

        _ = try await git(
            [
                "commit",
                "-q",
                "-m",
                message,
            ],
            at: directory
        )
    }

    func remove() {
        try? FileManager.default.removeItem(
            at: root
        )

        try? FileManager.default.removeItem(
            at: worktreesRoot
        )
    }
}
