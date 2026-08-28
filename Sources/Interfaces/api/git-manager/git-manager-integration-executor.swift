import Foundation

public enum GitManagerIntegrationExecutionStatus:
    String,
    Sendable,
    Codable,
    Hashable
{
    case ready
    case conflicts
    case alreadyIntegrated = "already_integrated"
}

public struct GitManagerIntegrationExecution:
    Sendable,
    Codable,
    Hashable
{
    public let plan: GitManagerIntegrationPlan
    public let isolationID: GitManagerIsolationID
    public let integrationBranch: String?
    public let worktree: URL?
    public let status: GitManagerIntegrationExecutionStatus
    public let targetHeadBefore: String
    public let integrationHead: String?
    public let conflictPaths: [String]

    public init(
        plan: GitManagerIntegrationPlan,
        isolationID: GitManagerIsolationID,
        integrationBranch: String?,
        worktree: URL?,
        status: GitManagerIntegrationExecutionStatus,
        targetHeadBefore: String,
        integrationHead: String?,
        conflictPaths: [String]
    ) {
        self.plan = plan
        self.isolationID = isolationID
        self.integrationBranch = integrationBranch
        self.worktree = worktree?.standardizedFileURL
        self.status = status
        self.targetHeadBefore = targetHeadBefore
        self.integrationHead = integrationHead
        self.conflictPaths = conflictPaths
    }
}

public struct GitManagerIntegrationPromotion:
    Sendable,
    Codable,
    Hashable
{
    public let targetBranch: String
    public let previousTargetHead: String
    public let newTargetHead: String
    public let targetWorktree: URL?

    public init(
        targetBranch: String,
        previousTargetHead: String,
        newTargetHead: String,
        targetWorktree: URL?
    ) {
        self.targetBranch = targetBranch
        self.previousTargetHead = previousTargetHead
        self.newTargetHead = newTargetHead
        self.targetWorktree = targetWorktree?.standardizedFileURL
    }
}

public enum GitManagerIntegrationExecutionError:
    Error,
    LocalizedError,
    Sendable,
    Equatable
{
    case staleSource(
        expected: String,
        actual: String
    )
    case staleTarget(
        expected: String,
        actual: String
    )
    case staleIntegrationHead(
        expected: String,
        actual: String
    )
    case unsupportedClassification(
        GitManagerIntegrationClassification
    )
    case integrationNotReady(
        GitManagerIntegrationExecutionStatus
    )
    case missingIntegrationState
    case targetBranchMissing(String)
    case integrationWorktreeDirty(String)
    case targetWorktreeDirty(String)
    case promotionNotFastForward
    case cleanupRequiresDiscard
    case gitFailed(
        operation: String,
        code: Int32,
        stderr: String
    )

    public var errorDescription: String? {
        switch self {
        case .staleSource(
            let expected,
            let actual
        ):
            return "Integration source moved after planning. Expected \(expected), found \(actual)."

        case .staleTarget(
            let expected,
            let actual
        ):
            return "Integration target moved after planning. Expected \(expected), found \(actual)."

        case .staleIntegrationHead(
            let expected,
            let actual
        ):
            return "Prepared integration HEAD moved. Expected \(expected), found \(actual)."

        case .unsupportedClassification(let classification):
            return "Integration classification is not executable: \(classification.rawValue)"

        case .integrationNotReady(let status):
            return "Integration cannot be promoted while status is \(status.rawValue)."

        case .missingIntegrationState:
            return "Prepared integration is missing its worktree, branch, or integration HEAD."

        case .targetBranchMissing(let branch):
            return "Integration target local branch does not exist: \(branch)"

        case .integrationWorktreeDirty(let path):
            return "Prepared integration worktree is dirty: \(path)"

        case .targetWorktreeDirty(let path):
            return "Integration target worktree is dirty: \(path)"

        case .promotionNotFastForward:
            return "Prepared integration cannot fast-forward the target."

        case .cleanupRequiresDiscard:
            return "Prepared integration has not been safely incorporated into the target. Cleanup requires discard=true."

        case .gitFailed(
            let operation,
            let code,
            let stderr
        ):
            return "\(operation) failed with exit code \(code): \(stderr)"
        }
    }
}

public enum GitManagerIntegrationExecutor {
    public static func prepare(
        _ plan: GitManagerIntegrationPlan,
        isolationID: GitManagerIsolationID,
        destination: URL,
        at repository: URL
    ) async throws -> GitManagerIntegrationExecution {
        let current = try await GitManagerIntegrationPlanner.plan(
            sourceRef: plan.source.ref,
            targetRef: plan.target.ref,
            expectedTargetCommit: plan.expectedTargetCommit,
            at: repository
        )

        guard current.source.commit == plan.source.commit else {
            throw GitManagerIntegrationExecutionError.staleSource(
                expected: plan.source.commit,
                actual: current.source.commit
            )
        }

        guard current.target.commit == plan.target.commit else {
            throw GitManagerIntegrationExecutionError.staleTarget(
                expected: plan.target.commit,
                actual: current.target.commit
            )
        }

        if current.classification == .alreadyIntegrated {
            return .init(
                plan: current,
                isolationID: isolationID,
                integrationBranch: nil,
                worktree: nil,
                status: .alreadyIntegrated,
                targetHeadBefore: current.target.commit,
                integrationHead: current.target.commit,
                conflictPaths: []
            )
        }

        guard current.classification != .unrelatedHistories else {
            throw GitManagerIntegrationExecutionError.unsupportedClassification(
                current.classification
            )
        }

        let branch = isolationID.branchName(
            prefix: "integration"
        )
        let destination = destination.standardizedFileURL

        _ = try await GitManagerWorktree.create(
            .init(
                repository: repository,
                destination: destination,
                baseRef: current.target.commit,
                checkout: .newBranch(
                    branch
                )
            )
        )

        let merge = try await GitRepo.git(
            destination,
            [
                "merge",
                "--no-edit",
                current.source.commit,
            ]
        )

        if merge.code == 0 {
            let integrationHead = try await head(
                at: destination
            )

            return .init(
                plan: current,
                isolationID: isolationID,
                integrationBranch: branch,
                worktree: destination,
                status: .ready,
                targetHeadBefore: current.target.commit,
                integrationHead: integrationHead,
                conflictPaths: []
            )
        }

        let conflictPaths = try await unmergedPaths(
            at: destination
        )

        if !conflictPaths.isEmpty {
            return .init(
                plan: current,
                isolationID: isolationID,
                integrationBranch: branch,
                worktree: destination,
                status: .conflicts,
                targetHeadBefore: current.target.commit,
                integrationHead: nil,
                conflictPaths: conflictPaths
            )
        }

        throw failure(
            "git merge",
            merge
        )
    }

    public static func promote(
        _ execution: GitManagerIntegrationExecution,
        targetBranch: String,
        at repository: URL
    ) async throws -> GitManagerIntegrationPromotion {
        guard execution.status == .ready else {
            throw GitManagerIntegrationExecutionError.integrationNotReady(
                execution.status
            )
        }

        guard let worktree = execution.worktree,
              let integrationHead = execution.integrationHead
        else {
            throw GitManagerIntegrationExecutionError.missingIntegrationState
        }

        let actualIntegrationHead = try await head(
            at: worktree
        )

        guard actualIntegrationHead == integrationHead else {
            throw GitManagerIntegrationExecutionError.staleIntegrationHead(
                expected: integrationHead,
                actual: actualIntegrationHead
            )
        }

        let integrationDirty = try await GitRepo.isDirty(
            worktree,
            includeUntracked: true
        )

        guard !integrationDirty else {
            throw GitManagerIntegrationExecutionError.integrationWorktreeDirty(
                worktree.path
            )
        }

        let targetHead = try await localBranchHead(
            targetBranch,
            at: repository
        )

        guard targetHead == execution.plan.target.commit else {
            throw GitManagerIntegrationExecutionError.staleTarget(
                expected: execution.plan.target.commit,
                actual: targetHead
            )
        }

        guard try await isAncestor(
            targetHead,
            of: integrationHead,
            at: repository
        ) else {
            throw GitManagerIntegrationExecutionError.promotionNotFastForward
        }

        let occupied = try await GitManagerWorktree.occupied(
            by: targetBranch,
            at: repository
        )

        if let occupied {
            let dirty = try await GitRepo.isDirty(
                occupied.path,
                includeUntracked: true
            )

            guard !dirty else {
                throw GitManagerIntegrationExecutionError.targetWorktreeDirty(
                    occupied.path.path
                )
            }

            let occupiedHead = try await head(
                at: occupied.path
            )

            guard occupiedHead == targetHead else {
                throw GitManagerIntegrationExecutionError.staleTarget(
                    expected: targetHead,
                    actual: occupiedHead
                )
            }

            let result = try await GitRepo.git(
                occupied.path,
                [
                    "merge",
                    "--ff-only",
                    integrationHead,
                ]
            )

            guard result.code == 0 else {
                throw failure(
                    "git merge --ff-only",
                    result
                )
            }

            let promotedHead = try await head(
                at: occupied.path
            )

            guard promotedHead == integrationHead else {
                throw GitManagerIntegrationExecutionError.staleTarget(
                    expected: integrationHead,
                    actual: promotedHead
                )
            }
        } else {
            let result = try await GitRepo.git(
                repository,
                [
                    "branch",
                    "-f",
                    targetBranch,
                    integrationHead,
                ]
            )

            guard result.code == 0 else {
                throw failure(
                    "git branch -f",
                    result
                )
            }

            let promotedHead = try await localBranchHead(
                targetBranch,
                at: repository
            )

            guard promotedHead == integrationHead else {
                throw GitManagerIntegrationExecutionError.staleTarget(
                    expected: integrationHead,
                    actual: promotedHead
                )
            }
        }

        return .init(
            targetBranch: targetBranch,
            previousTargetHead: targetHead,
            newTargetHead: integrationHead,
            targetWorktree: occupied?.path
        )
    }

    public static func cleanup(
        _ execution: GitManagerIntegrationExecution,
        discard: Bool = false,
        at repository: URL
    ) async throws {
        guard let branch = execution.integrationBranch,
              let worktree = execution.worktree
        else {
            return
        }

        if execution.status == .conflicts {
            guard discard else {
                throw GitManagerIntegrationExecutionError.cleanupRequiresDiscard
            }

            let abort = try await GitRepo.git(
                worktree,
                [
                    "merge",
                    "--abort",
                ]
            )

            guard abort.code == 0 else {
                throw failure(
                    "git merge --abort",
                    abort
                )
            }
        } else if !discard {
            guard let integrationHead = execution.integrationHead else {
                throw GitManagerIntegrationExecutionError.missingIntegrationState
            }

            let currentTarget = try await commit(
                execution.plan.target.ref,
                at: repository
            )

            guard try await isAncestor(
                integrationHead,
                of: currentTarget,
                at: repository
            ) else {
                throw GitManagerIntegrationExecutionError.cleanupRequiresDiscard
            }
        }

        try await GitManagerWorktree.remove(
            worktree,
            at: repository
        )

        let result = try await GitRepo.git(
            repository,
            [
                "branch",
                "-D",
                branch,
            ]
        )

        guard result.code == 0 else {
            throw failure(
                "git branch delete",
                result
            )
        }
    }
}

private extension GitManagerIntegrationExecutor {
    static func head(
        at repository: URL
    ) async throws -> String {
        try await GitRepo.gitOut(
            repository,
            [
                "rev-parse",
                "HEAD",
            ]
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    static func commit(
        _ ref: String,
        at repository: URL
    ) async throws -> String {
        let result = try await GitRepo.git(
            repository,
            [
                "rev-parse",
                "--verify",
                "\(ref)^{commit}",
            ]
        )

        guard result.code == 0 else {
            throw failure(
                "git rev-parse",
                result
            )
        }

        return result.out.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    static func localBranchHead(
        _ branch: String,
        at repository: URL
    ) async throws -> String {
        let result = try await GitRepo.git(
            repository,
            [
                "rev-parse",
                "--verify",
                "refs/heads/\(branch)^{commit}",
            ]
        )

        guard result.code == 0 else {
            if result.code == 128 {
                throw GitManagerIntegrationExecutionError.targetBranchMissing(
                    branch
                )
            }

            throw failure(
                "git rev-parse target branch",
                result
            )
        }

        return result.out.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    static func isAncestor(
        _ ancestor: String,
        of descendant: String,
        at repository: URL
    ) async throws -> Bool {
        let result = try await GitRepo.git(
            repository,
            [
                "merge-base",
                "--is-ancestor",
                ancestor,
                descendant,
            ]
        )

        switch result.code {
        case 0:
            return true

        case 1:
            return false

        default:
            throw failure(
                "git merge-base --is-ancestor",
                result
            )
        }
    }

    static func unmergedPaths(
        at repository: URL
    ) async throws -> [String] {
        let output = try await GitRepo.gitOut(
            repository,
            [
                "diff",
                "--name-only",
                "--diff-filter=U",
            ]
        )

        return output
            .split(
                whereSeparator: \.isNewline
            )
            .map(
                String.init
            )
            .sorted()
    }

    static func failure(
        _ operation: String,
        _ result: (
            code: Int32,
            out: String,
            err: String
        )
    ) -> GitManagerIntegrationExecutionError {
        .gitFailed(
            operation: operation,
            code: result.code,
            stderr: result.err.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        )
    }
}
