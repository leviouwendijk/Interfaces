import Foundation

public enum GitManagerAction {
    @discardableResult
    public static func prepareCommit(
        paths: [String] = [
            ".",
        ],
        at directory: URL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
    ) async throws -> String {
        let paths = paths
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }

        guard !paths.isEmpty else {
            throw GitManagerError.unsafeSync(
                "Commit preparation requires at least one path."
            )
        }

        let root = try await requireRoot(
            at: directory
        )

        return try await GitRepo.gitOut(
            root,
            [
                "add",
                "--",
            ] + paths
        )
    }

    @discardableResult
    public static func commitPrepared(
        message: String,
        at directory: URL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
    ) async throws -> String {
        let message = message.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !message.isEmpty else {
            throw GitManagerError.missingCommitMessage
        }

        let root = try await requireRoot(
            at: directory
        )

        return try await GitRepo.gitOut(
            root,
            [
                "commit",
                "-m",
                message,
            ]
        )
    }

    @discardableResult
    public static func save(
        message: String,
        at directory: URL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
    ) async throws -> [String] {
        [
            try await prepareCommit(
                at: directory
            ),
            try await commitPrepared(
                message: message,
                at: directory
            ),
        ]
    }

    @discardableResult
    public static func commit(
        message: String,
        push shouldPush: Bool,
        at directory: URL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
    ) async throws -> [String] {
        var outputs = try await save(
            message: message,
            at: directory
        )

        if shouldPush {
            outputs.append(
                try await GitManagerAction.push(
                    at: directory
                )
            )
        }

        return outputs
    }

    @discardableResult
    public static func pull(
        at directory: URL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
    ) async throws -> String {
        let root = try await requireRoot(
            at: directory
        )

        let upstream = try await GitRepo.defaultRemoteAndBranch(
            root
        )

        return try await GitRepo.gitOut(
            root,
            [
                "pull",
                "--ff-only",
                upstream.remote,
                upstream.branch,
            ]
        )
    }

    @discardableResult
    public static func push(
        at directory: URL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
    ) async throws -> String {
        let root = try await requireRoot(
            at: directory
        )

        let upstream = try await GitRepo.defaultRemoteAndBranch(
            root
        )

        return try await GitRepo.gitOut(
            root,
            [
                "push",
                "-u",
                upstream.remote,
                upstream.branch,
            ]
        )
    }

    @discardableResult
    public static func push(
        remote: String,
        branch: String,
        setUpstream: Bool = true,
        at directory: URL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
    ) async throws -> String {
        let remote = remote.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let branch = branch.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !remote.isEmpty else {
            throw GitManagerError.unsafeSync(
                "Push remote cannot be blank."
            )
        }

        guard !branch.isEmpty else {
            throw GitManagerError.unsafeSync(
                "Push branch cannot be blank."
            )
        }

        let root = try await requireRoot(
            at: directory
        )

        var arguments = [
            "push",
        ]

        if setUpstream {
            arguments.append(
                "-u"
            )
        }

        arguments.append(
            contentsOf: [
                remote,
                branch,
            ]
        )

        return try await GitRepo.gitOut(
            root,
            arguments
        )
    }

    public static func sync(
        at directory: URL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
    ) async throws -> GitManagerSyncResult {
        let state = try await GitManagerRepositoryInspector.state(
            at: directory
        )

        switch state.classification {
        case .upToDate:
            return .init(
                state: state,
                action: .none,
                output: "Already up to date."
            )

        case .ahead:
            return .init(
                state: state,
                action: .push,
                output: try await push(
                    at: directory
                )
            )

        case .behind:
            return .init(
                state: state,
                action: .pull,
                output: try await pull(
                    at: directory
                )
            )

        case .dirty:
            throw GitManagerError.unsafeSync(
                "Repo has tracked local modifications. Commit, stash, or inspect before sync."
            )

        case .untracked:
            throw GitManagerError.unsafeSync(
                "Repo has untracked files. Add, ignore, remove, or inspect before sync."
            )

        case .diverged:
            throw GitManagerError.unsafeSync(
                "Repo has diverged. Refusing automatic sync."
            )

        case .noUpstream:
            throw GitManagerError.noUpstream(
                state.displayName
            )

        case .notGitRepository:
            throw GitManagerError.notGitRepository(
                directory.path
            )

        case .unknown:
            throw GitManagerError.unsafeSync(
                "Could not classify repo safely."
            )
        }
    }

    public static func hardResetToUpstream(
        cleanUntracked: Bool,
        at directory: URL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
    ) async throws {
        let root = try await requireRoot(
            at: directory
        )

        try await GitRepo.hardResetToUpstream(
            root,
            cleanUntracked: cleanUntracked
        )
    }

    @discardableResult
    public static func raw(
        _ arguments: [String],
        at directory: URL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
    ) async throws -> String {
        let root = try await requireRoot(
            at: directory
        )

        return try await GitRepo.gitOut(
            root,
            arguments
        )
    }
}

public struct GitManagerSyncResult: Sendable, Codable, Hashable {
    public let state: GitManagerRepositoryState
    public let action: GitManagerSyncAction
    public let output: String

    public init(
        state: GitManagerRepositoryState,
        action: GitManagerSyncAction,
        output: String
    ) {
        self.state = state
        self.action = action
        self.output = output
    }
}

public enum GitManagerSyncAction: String, Sendable, Codable, Hashable {
    case none
    case pull
    case push
}

private extension GitManagerAction {
    static func requireRoot(
        at directory: URL
    ) async throws -> URL {
        let state = try await GitManagerRepositoryInspector.state(
            at: directory,
            fetch: false
        )

        guard let root = state.root else {
            throw GitManagerError.notGitRepository(
                directory.path
            )
        }

        return root
    }
}
