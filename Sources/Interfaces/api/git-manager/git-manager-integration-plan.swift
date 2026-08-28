import Foundation

public enum GitManagerIntegrationClassification:
    String,
    Sendable,
    Codable,
    Hashable
{
    case alreadyIntegrated = "already_integrated"
    case fastForward = "fast_forward"
    case cleanMerge = "clean_merge"
    case conflicts
    case unrelatedHistories = "unrelated_histories"
}

public struct GitManagerIntegrationEndpoint:
    Sendable,
    Codable,
    Hashable
{
    public let ref: String
    public let commit: String

    public init(
        ref: String,
        commit: String
    ) {
        self.ref = ref
        self.commit = commit
    }
}

public struct GitManagerIntegrationPlan:
    Sendable,
    Codable,
    Hashable
{
    public let source: GitManagerIntegrationEndpoint
    public let target: GitManagerIntegrationEndpoint
    public let expectedTargetCommit: String?
    public let targetDrifted: Bool
    public let mergeBase: String?
    public let sourceCommitCount: Int
    public let targetCommitCount: Int
    public let sourcePaths: [String]
    public let targetPaths: [String]
    public let overlappingPaths: [String]
    public let conflictPaths: [String]
    public let classification: GitManagerIntegrationClassification

    public init(
        source: GitManagerIntegrationEndpoint,
        target: GitManagerIntegrationEndpoint,
        expectedTargetCommit: String?,
        targetDrifted: Bool,
        mergeBase: String?,
        sourceCommitCount: Int,
        targetCommitCount: Int,
        sourcePaths: [String],
        targetPaths: [String],
        overlappingPaths: [String],
        conflictPaths: [String],
        classification: GitManagerIntegrationClassification
    ) {
        self.source = source
        self.target = target
        self.expectedTargetCommit = expectedTargetCommit
        self.targetDrifted = targetDrifted
        self.mergeBase = mergeBase
        self.sourceCommitCount = sourceCommitCount
        self.targetCommitCount = targetCommitCount
        self.sourcePaths = sourcePaths
        self.targetPaths = targetPaths
        self.overlappingPaths = overlappingPaths
        self.conflictPaths = conflictPaths
        self.classification = classification
    }
}

public enum GitManagerIntegrationPlanError:
    Error,
    LocalizedError,
    Sendable,
    Equatable
{
    case refNotResolvable(String)
    case gitFailed(
        operation: String,
        code: Int32,
        stderr: String
    )
    case invalidCount(String)

    public var errorDescription: String? {
        switch self {
        case .refNotResolvable(let ref):
            return "Git integration ref is not resolvable to a commit: \(ref)"

        case .gitFailed(
            let operation,
            let code,
            let stderr
        ):
            return "\(operation) failed with exit code \(code): \(stderr)"

        case .invalidCount(let value):
            return "Git integration commit count is invalid: \(value)"
        }
    }
}

public enum GitManagerIntegrationPlanner {
    public static func plan(
        sourceRef: String,
        targetRef: String,
        expectedTargetCommit: String? = nil,
        at repository: URL
    ) async throws -> GitManagerIntegrationPlan {
        let sourceCommit = try await commit(
            sourceRef,
            at: repository
        )
        let targetCommit = try await commit(
            targetRef,
            at: repository
        )

        let source = GitManagerIntegrationEndpoint(
            ref: sourceRef,
            commit: sourceCommit
        )
        let target = GitManagerIntegrationEndpoint(
            ref: targetRef,
            commit: targetCommit
        )

        let targetDrifted = expectedTargetCommit.map {
            $0 != targetCommit
        } ?? false

        if try await isAncestor(
            sourceCommit,
            of: targetCommit,
            at: repository
        ) {
            return .init(
                source: source,
                target: target,
                expectedTargetCommit: expectedTargetCommit,
                targetDrifted: targetDrifted,
                mergeBase: sourceCommit,
                sourceCommitCount: 0,
                targetCommitCount: try await commitCount(
                    from: sourceCommit,
                    to: targetCommit,
                    at: repository
                ),
                sourcePaths: [],
                targetPaths: try await changedPaths(
                    from: sourceCommit,
                    to: targetCommit,
                    at: repository
                ),
                overlappingPaths: [],
                conflictPaths: [],
                classification: .alreadyIntegrated
            )
        }

        if try await isAncestor(
            targetCommit,
            of: sourceCommit,
            at: repository
        ) {
            return .init(
                source: source,
                target: target,
                expectedTargetCommit: expectedTargetCommit,
                targetDrifted: targetDrifted,
                mergeBase: targetCommit,
                sourceCommitCount: try await commitCount(
                    from: targetCommit,
                    to: sourceCommit,
                    at: repository
                ),
                targetCommitCount: 0,
                sourcePaths: try await changedPaths(
                    from: targetCommit,
                    to: sourceCommit,
                    at: repository
                ),
                targetPaths: [],
                overlappingPaths: [],
                conflictPaths: [],
                classification: .fastForward
            )
        }

        guard let mergeBase = try await mergeBase(
            sourceCommit,
            targetCommit,
            at: repository
        ) else {
            return .init(
                source: source,
                target: target,
                expectedTargetCommit: expectedTargetCommit,
                targetDrifted: targetDrifted,
                mergeBase: nil,
                sourceCommitCount: 0,
                targetCommitCount: 0,
                sourcePaths: [],
                targetPaths: [],
                overlappingPaths: [],
                conflictPaths: [],
                classification: .unrelatedHistories
            )
        }

        let sourcePaths = try await changedPaths(
            from: mergeBase,
            to: sourceCommit,
            at: repository
        )
        let targetPaths = try await changedPaths(
            from: mergeBase,
            to: targetCommit,
            at: repository
        )
        let overlappingPaths = Array(
            Set(sourcePaths)
                .intersection(
                    Set(targetPaths)
                )
        )
        .sorted()

        let mergeTree = try await mergeTree(
            sourceCommit: sourceCommit,
            targetCommit: targetCommit,
            at: repository
        )

        return .init(
            source: source,
            target: target,
            expectedTargetCommit: expectedTargetCommit,
            targetDrifted: targetDrifted,
            mergeBase: mergeBase,
            sourceCommitCount: try await commitCount(
                from: mergeBase,
                to: sourceCommit,
                at: repository
            ),
            targetCommitCount: try await commitCount(
                from: mergeBase,
                to: targetCommit,
                at: repository
            ),
            sourcePaths: sourcePaths,
            targetPaths: targetPaths,
            overlappingPaths: overlappingPaths,
            conflictPaths: mergeTree.conflictPaths,
            classification: mergeTree.hasConflicts
                ? .conflicts
                : .cleanMerge
        )
    }
}

private extension GitManagerIntegrationPlanner {
    struct MergeTreeResult {
        let hasConflicts: Bool
        let conflictPaths: [String]
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
            if result.code == 128 {
                throw GitManagerIntegrationPlanError.refNotResolvable(
                    ref
                )
            }

            throw failure(
                "git rev-parse",
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

    static func mergeBase(
        _ source: String,
        _ target: String,
        at repository: URL
    ) async throws -> String? {
        let result = try await GitRepo.git(
            repository,
            [
                "merge-base",
                source,
                target,
            ]
        )

        switch result.code {
        case 0:
            return result.out.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        case 1:
            return nil

        default:
            throw failure(
                "git merge-base",
                result
            )
        }
    }

    static func changedPaths(
        from base: String,
        to head: String,
        at repository: URL
    ) async throws -> [String] {
        let output = try await GitRepo.gitOut(
            repository,
            [
                "diff",
                "--name-only",
                "--no-renames",
                base,
                head,
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

    static func commitCount(
        from base: String,
        to head: String,
        at repository: URL
    ) async throws -> Int {
        let value = try await GitRepo.gitOut(
            repository,
            [
                "rev-list",
                "--count",
                "\(base)..\(head)",
            ]
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard let count = Int(
            value
        ) else {
            throw GitManagerIntegrationPlanError.invalidCount(
                value
            )
        }

        return count
    }

    static func mergeTree(
        sourceCommit: String,
        targetCommit: String,
        at repository: URL
    ) async throws -> MergeTreeResult {
        let result = try await GitRepo.git(
            repository,
            [
                "merge-tree",
                "--write-tree",
                "--name-only",
                "--no-messages",
                targetCommit,
                sourceCommit,
            ]
        )

        guard result.code == 0 || result.code == 1 else {
            throw failure(
                "git merge-tree",
                result
            )
        }

        let conflictPaths = result.out
            .split(
                whereSeparator: \.isNewline
            )
            .map(
                String.init
            )
            .filter {
                !$0.isEmpty
                    && !looksLikeObjectID(
                        $0
                    )
            }
            .sorted()

        return .init(
            hasConflicts: result.code == 1,
            conflictPaths: conflictPaths
        )
    }

    static func looksLikeObjectID(
        _ value: String
    ) -> Bool {
        guard value.count == 40
                || value.count == 64
        else {
            return false
        }

        return value.unicodeScalars.allSatisfy {
            let code = $0.value

            return (48...57).contains(code)
                || (97...102).contains(code)
                || (65...70).contains(code)
        }
    }

    static func failure(
        _ operation: String,
        _ result: (
            code: Int32,
            out: String,
            err: String
        )
    ) -> GitManagerIntegrationPlanError {
        .gitFailed(
            operation: operation,
            code: result.code,
            stderr: result.err.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        )
    }
}
