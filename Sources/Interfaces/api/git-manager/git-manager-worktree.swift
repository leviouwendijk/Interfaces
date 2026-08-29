import Foundation

public struct GitManagerWorktreeRecord:
    Sendable,
    Codable,
    Hashable
{
    public let path: URL
    public let head: String
    public let branch: String?
    public let isDetached: Bool
    public let isBare: Bool
    public let isLocked: Bool
    public let lockReason: String?
    public let isPrunable: Bool
    public let prunableReason: String?
    public let isPrimary: Bool

    public init(
        path: URL,
        head: String,
        branch: String?,
        isDetached: Bool,
        isBare: Bool,
        isLocked: Bool,
        lockReason: String?,
        isPrunable: Bool,
        prunableReason: String?,
        isPrimary: Bool
    ) {
        self.path = path.standardizedFileURL
        self.head = head
        self.branch = branch
        self.isDetached = isDetached
        self.isBare = isBare
        self.isLocked = isLocked
        self.lockReason = lockReason
        self.isPrunable = isPrunable
        self.prunableReason = prunableReason
        self.isPrimary = isPrimary
    }
}

public enum GitManagerWorktreeCheckout:
    Sendable,
    Codable,
    Hashable
{
    case newBranch(String)
    case existingBranch(String)
    case detached
}

public struct GitManagerWorktreeCreateRequest:
    Sendable,
    Codable,
    Hashable
{
    public let repository: URL
    public let destination: URL
    public let baseRef: String
    public let checkout: GitManagerWorktreeCheckout

    public init(
        repository: URL,
        destination: URL,
        baseRef: String,
        checkout: GitManagerWorktreeCheckout
    ) {
        self.repository = repository.standardizedFileURL
        self.destination = destination.standardizedFileURL
        self.baseRef = baseRef
        self.checkout = checkout
    }
}

public struct GitManagerWorktreeCreateResult:
    Sendable,
    Codable,
    Hashable
{
    public let worktree: GitManagerWorktreeRecord
    public let baseRef: String
    public let baseCommit: String

    public init(
        worktree: GitManagerWorktreeRecord,
        baseRef: String,
        baseCommit: String
    ) {
        self.worktree = worktree
        self.baseRef = baseRef
        self.baseCommit = baseCommit
    }
}

public struct GitManagerWorktreePruneResult:
    Sendable,
    Codable,
    Hashable
{
    public let dryRun: Bool
    public let output: String

    public init(
        dryRun: Bool,
        output: String
    ) {
        self.dryRun = dryRun
        self.output = output
    }
}

public enum GitManagerWorktreeError:
    Error,
    LocalizedError,
    Sendable,
    Equatable
{
    case destinationExists(String)
    case invalidBranch(String)
    case branchAlreadyExists(String)
    case branchOccupied(
        branch: String,
        path: String
    )
    case worktreeNotFound(String)
    case primaryRemovalDenied(String)
    case gitFailed(
        operation: String,
        code: Int32,
        stderr: String
    )

    public var errorDescription: String? {
        switch self {
        case .destinationExists(let path):
            return "Git worktree destination already exists: \(path)"

        case .invalidBranch(let branch):
            return "Invalid Git branch name: \(branch)"

        case .branchAlreadyExists(let branch):
            return "Git branch already exists: \(branch)"

        case .branchOccupied(
            let branch,
            let path
        ):
            return "Git branch '\(branch)' is already checked out at \(path)."

        case .worktreeNotFound(let path):
            return "Git worktree was not found: \(path)"

        case .primaryRemovalDenied(let path):
            return "Refusing to remove the primary Git worktree: \(path)"

        case .gitFailed(
            let operation,
            let code,
            let stderr
        ):
            return "\(operation) failed with exit code \(code): \(stderr)"
        }
    }
}

public enum GitManagerWorktree {
    public static func list(
        at repository: URL
    ) async throws -> [GitManagerWorktreeRecord] {
        let result = try await GitRepo.git(
            repository,
            [
                "worktree",
                "list",
                "--porcelain",
            ]
        )

        guard result.code == 0 else {
            throw failure(
                "git worktree list",
                result
            )
        }

        return parse(
            result.out
        )
    }

    public static func current(
        at directory: URL
    ) async throws -> GitManagerWorktreeRecord? {
        let root = try await GitRepo.gitOut(
            directory,
            [
                "rev-parse",
                "--show-toplevel",
            ]
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let normalizedRoot = URL(
            fileURLWithPath: root,
            isDirectory: true
        )
        .standardizedFileURL

        return try await list(
            at: directory
        )
        .first {
            $0.path == normalizedRoot
        }
    }

    public static func occupied(
        by branch: String,
        at repository: URL
    ) async throws -> GitManagerWorktreeRecord? {
        try await list(
            at: repository
        )
        .first {
            $0.branch == branch
        }
    }

    public static func create(
        _ request: GitManagerWorktreeCreateRequest
    ) async throws -> GitManagerWorktreeCreateResult {
        let fm = FileManager.default

        guard !fm.fileExists(
            atPath: request.destination.path
        ) else {
            throw GitManagerWorktreeError.destinationExists(
                request.destination.path
            )
        }

        let baseCommit = try await GitRepo.resolveCommit(
            request.baseRef,
            at: request.repository
        )

        var arguments = [
            "worktree",
            "add",
        ]

        switch request.checkout {
        case .newBranch(let branch):
            try await requireValidBranch(
                branch,
                at: request.repository
            )

            let exists = try await branchExists(
                branch,
                at: request.repository
            )

            guard !exists else {
                throw GitManagerWorktreeError.branchAlreadyExists(
                    branch
                )
            }

            arguments.append(
                contentsOf: [
                    "-b",
                    branch,
                    request.destination.path,
                    baseCommit,
                ]
            )

        case .existingBranch(let branch):
            try await requireValidBranch(
                branch,
                at: request.repository
            )

            guard try await branchExists(
                branch,
                at: request.repository
            ) else {
                throw GitManagerWorktreeError.invalidBranch(
                    branch
                )
            }

            if let occupied = try await occupied(
                by: branch,
                at: request.repository
            ) {
                throw GitManagerWorktreeError.branchOccupied(
                    branch: branch,
                    path: occupied.path.path
                )
            }

            arguments.append(
                contentsOf: [
                    request.destination.path,
                    branch,
                ]
            )

        case .detached:
            arguments.append(
                contentsOf: [
                    "--detach",
                    request.destination.path,
                    baseCommit,
                ]
            )
        }

        let result = try await GitRepo.git(
            request.repository,
            arguments
        )

        guard result.code == 0 else {
            throw failure(
                "git worktree add",
                result
            )
        }

        guard let worktree = try await list(
            at: request.repository
        )
        .first(
            where: {
                $0.path == request.destination
            }
        ) else {
            throw GitManagerWorktreeError.worktreeNotFound(
                request.destination.path
            )
        }

        return .init(
            worktree: worktree,
            baseRef: request.baseRef,
            baseCommit: baseCommit
        )
    }

    public static func lock(
        _ worktree: URL,
        reason: String? = nil,
        at repository: URL
    ) async throws {
        var arguments = [
            "worktree",
            "lock",
        ]

        if let reason,
           !reason.isEmpty
        {
            arguments.append(
                contentsOf: [
                    "--reason",
                    reason,
                ]
            )
        }

        arguments.append(
            worktree.standardizedFileURL.path
        )

        let result = try await GitRepo.git(
            repository,
            arguments
        )

        guard result.code == 0 else {
            throw failure(
                "git worktree lock",
                result
            )
        }
    }

    public static func unlock(
        _ worktree: URL,
        at repository: URL
    ) async throws {
        let result = try await GitRepo.git(
            repository,
            [
                "worktree",
                "unlock",
                worktree.standardizedFileURL.path,
            ]
        )

        guard result.code == 0 else {
            throw failure(
                "git worktree unlock",
                result
            )
        }
    }

    public static func remove(
        _ worktree: URL,
        at repository: URL,
        force: Bool = false
    ) async throws {
        let worktree = worktree.standardizedFileURL
        let records = try await list(
            at: repository
        )

        guard let record = records.first(
            where: {
                $0.path == worktree
            }
        ) else {
            throw GitManagerWorktreeError.worktreeNotFound(
                worktree.path
            )
        }

        guard !record.isPrimary else {
            throw GitManagerWorktreeError.primaryRemovalDenied(
                worktree.path
            )
        }

        var arguments = [
            "worktree",
            "remove",
        ]

        if force {
            arguments.append(
                "--force"
            )
        }

        arguments.append(
            worktree.path
        )

        let result = try await GitRepo.git(
            repository,
            arguments
        )

        guard result.code == 0 else {
            throw failure(
                "git worktree remove",
                result
            )
        }
    }

    @discardableResult
    public static func prune(
        at repository: URL,
        dryRun: Bool = false
    ) async throws -> GitManagerWorktreePruneResult {
        var arguments = [
            "worktree",
            "prune",
            "--verbose",
        ]

        if dryRun {
            arguments.append(
                "--dry-run"
            )
        }

        let result = try await GitRepo.git(
            repository,
            arguments
        )

        guard result.code == 0 else {
            throw failure(
                "git worktree prune",
                result
            )
        }

        return .init(
            dryRun: dryRun,
            output: result.out + result.err
        )
    }
}

private extension GitManagerWorktree {
    static func requireValidBranch(
        _ branch: String,
        at repository: URL
    ) async throws {
        let result = try await GitRepo.git(
            repository,
            [
                "check-ref-format",
                "--branch",
                branch,
            ]
        )

        guard result.code == 0 else {
            throw GitManagerWorktreeError.invalidBranch(
                branch
            )
        }
    }

    static func branchExists(
        _ branch: String,
        at repository: URL
    ) async throws -> Bool {
        let result = try await GitRepo.git(
            repository,
            [
                "show-ref",
                "--verify",
                "--quiet",
                "refs/heads/\(branch)",
            ]
        )

        switch result.code {
        case 0:
            return true

        case 1:
            return false

        default:
            throw failure(
                "git show-ref",
                result
            )
        }
    }

    static func failure(
        _ operation: String,
        _ result: (
            code: Int32,
            out: String,
            err: String
        )
    ) -> GitManagerWorktreeError {
        .gitFailed(
            operation: operation,
            code: result.code,
            stderr: result.err.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        )
    }

    static func parse(
        _ output: String
    ) -> [GitManagerWorktreeRecord] {
        var records: [GitManagerWorktreeRecord] = []

        var path: URL?
        var head = ""
        var branch: String?
        var detached = false
        var bare = false
        var locked = false
        var lockReason: String?
        var prunable = false
        var prunableReason: String?

        func flush() {
            guard let currentPath = path else {
                return
            }

            records.append(
                .init(
                    path: currentPath,
                    head: head,
                    branch: branch,
                    isDetached: detached,
                    isBare: bare,
                    isLocked: locked,
                    lockReason: lockReason,
                    isPrunable: prunable,
                    prunableReason: prunableReason,
                    isPrimary: records.isEmpty
                )
            )

            path = nil
            head = ""
            branch = nil
            detached = false
            bare = false
            locked = false
            lockReason = nil
            prunable = false
            prunableReason = nil
        }

        for rawLine in output.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ) {
            let line = String(
                rawLine
            )

            if line.isEmpty {
                flush()
                continue
            }

            if line.hasPrefix(
                "worktree "
            ) {
                path = URL(
                    fileURLWithPath: String(
                        line.dropFirst(
                            "worktree ".count
                        )
                    ),
                    isDirectory: true
                )
                .standardizedFileURL
            } else if line.hasPrefix(
                "HEAD "
            ) {
                head = String(
                    line.dropFirst(
                        "HEAD ".count
                    )
                )
            } else if line.hasPrefix(
                "branch "
            ) {
                let raw = String(
                    line.dropFirst(
                        "branch ".count
                    )
                )

                branch = raw.hasPrefix(
                    "refs/heads/"
                )
                    ? String(
                        raw.dropFirst(
                            "refs/heads/".count
                        )
                    )
                    : raw
            } else if line == "detached" {
                detached = true
            } else if line == "bare" {
                bare = true
            } else if line == "locked" {
                locked = true
            } else if line.hasPrefix(
                "locked "
            ) {
                locked = true
                lockReason = String(
                    line.dropFirst(
                        "locked ".count
                    )
                )
            } else if line == "prunable" {
                prunable = true
            } else if line.hasPrefix(
                "prunable "
            ) {
                prunable = true
                prunableReason = String(
                    line.dropFirst(
                        "prunable ".count
                    )
                )
            }
        }

        flush()

        return records
    }
}
