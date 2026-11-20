import Foundation
import Interfaces
import TestFlows

extension InterfacesFlowSuite {
    static var gitManagerIntegrationExecutionFlow: TestFlow {
        TestFlow(
            "git-manager-integration-execution",
            tags: [
                "git",
                "integration",
                "execution",
                "worktree",
            ]
        ) {
            try await provePreparedIntegrationPromotion()
            try await proveStaleTargetPromotionDenied()
            try await proveConflictedIntegrationIsolation()

            return [
                .field(
                    "cases",
                    "3"
                ),
            ]
        }
    }
}

private func provePreparedIntegrationPromotion() async throws {
    let fixture = try await GitManagerWorktreeFixture.make()

    defer {
        fixture.remove()
    }

    let sourceID = try GitManagerIsolationID(
        "prepared integration source"
    )
    let sourceDestination = fixture.worktreesRoot
        .appendingPathComponent(
            "source",
            isDirectory: true
        )
    let sourceBranch = sourceID.branchName()

    _ = try await GitManagerWorktree.create(
        .init(
            repository: fixture.root,
            destination: sourceDestination,
            baseRef: "master",
            checkout: .newBranch(
                sourceBranch
            )
        )
    )

    try fixture.write(
        "source\n",
        path: "source.txt",
        at: sourceDestination
    )

    try await fixture.commit(
        "source",
        paths: [
            "source.txt",
        ],
        at: sourceDestination
    )

    let sourceHead = try await fixture.head(
        at: sourceDestination
    )

    try fixture.write(
        "target\n",
        path: "target.txt",
        at: fixture.root
    )

    try await fixture.commit(
        "target",
        paths: [
            "target.txt",
        ],
        at: fixture.root
    )

    let targetBefore = try await fixture.head()

    let plan = try await GitManagerIntegrationPlanner.plan(
        sourceRef: sourceBranch,
        targetRef: "master",
        at: fixture.root
    )

    try Expect.equal(
        plan.classification,
        .cleanMerge,
        "prepared integration fixture requires a real merge"
    )

    let integrationID = try GitManagerIsolationID(
        "prepared integration promotion"
    )
    let integrationDestination = fixture.worktreesRoot
        .appendingPathComponent(
            "integration",
            isDirectory: true
        )

    let execution = try await GitManagerIntegrationExecutor.prepare(
        plan,
        isolationID: integrationID,
        destination: integrationDestination,
        at: fixture.root
    )

    try Expect.equal(
        execution.status,
        .ready,
        "clean integration prepares in an isolated worktree"
    )

    try Expect.equal(
        try await fixture.head(),
        targetBefore,
        "preparing integration does not move target branch"
    )

    try Expect.equal(
        try await fixture.head(
            at: sourceDestination
        ),
        sourceHead,
        "preparing integration does not move source branch"
    )

    try Expect.true(
        !FileManager.default.fileExists(
            atPath: fixture.root
                .appendingPathComponent(
                    "source.txt"
                )
                .path
        ),
        "source change is absent from target before promotion"
    )

    try Expect.equal(
        try fixture.read(
            "source.txt",
            at: integrationDestination
        ),
        "source\n",
        "integration worktree contains source change"
    )

    try Expect.equal(
        try fixture.read(
            "target.txt",
            at: integrationDestination
        ),
        "target\n",
        "integration worktree contains target change"
    )

    let promotion = try await GitManagerIntegrationExecutor.promote(
        execution,
        targetBranch: "master",
        at: fixture.root
    )

    try Expect.equal(
        promotion.previousTargetHead,
        targetBefore,
        "promotion records exact target pre-state"
    )

    try Expect.equal(
        try await fixture.head(),
        promotion.newTargetHead,
        "promotion advances target to prepared integration HEAD"
    )

    try Expect.equal(
        try fixture.read(
            "source.txt",
            at: fixture.root
        ),
        "source\n",
        "promoted target receives source change"
    )

    try Expect.equal(
        try await fixture.head(
            at: sourceDestination
        ),
        sourceHead,
        "promotion preserves original source branch"
    )

    try await GitManagerIntegrationExecutor.cleanup(
        execution,
        at: fixture.root
    )

    try Expect.true(
        !FileManager.default.fileExists(
            atPath: integrationDestination.path
        ),
        "successful integration cleanup removes disposable worktree"
    )

    try Expect.true(
        FileManager.default.fileExists(
            atPath: sourceDestination.path
        ),
        "successful integration cleanup preserves source worktree"
    )

    try Expect.true(
        try await branchExists(
            sourceBranch,
            at: fixture.root
        ),
        "successful integration cleanup preserves source branch"
    )

    try Expect.true(
        !(try await branchExists(
            integrationID.branchName(
                prefix: "integration"
            ),
            at: fixture.root
        )),
        "successful integration cleanup removes disposable branch"
    )
}

private func proveStaleTargetPromotionDenied() async throws {
    let fixture = try await GitManagerWorktreeFixture.make()

    defer {
        fixture.remove()
    }

    let sourceID = try GitManagerIsolationID(
        "stale target source"
    )
    let sourceDestination = fixture.worktreesRoot
        .appendingPathComponent(
            "source",
            isDirectory: true
        )
    let sourceBranch = sourceID.branchName()

    _ = try await GitManagerWorktree.create(
        .init(
            repository: fixture.root,
            destination: sourceDestination,
            baseRef: "master",
            checkout: .newBranch(
                sourceBranch
            )
        )
    )

    try fixture.write(
        "source\n",
        path: "source.txt",
        at: sourceDestination
    )

    try await fixture.commit(
        "source",
        paths: [
            "source.txt",
        ],
        at: sourceDestination
    )

    let plan = try await GitManagerIntegrationPlanner.plan(
        sourceRef: sourceBranch,
        targetRef: "master",
        at: fixture.root
    )

    let integrationID = try GitManagerIsolationID(
        "stale target integration"
    )
    let integrationDestination = fixture.worktreesRoot
        .appendingPathComponent(
            "integration",
            isDirectory: true
        )

    let execution = try await GitManagerIntegrationExecutor.prepare(
        plan,
        isolationID: integrationID,
        destination: integrationDestination,
        at: fixture.root
    )

    try Expect.equal(
        execution.status,
        .ready,
        "stale-target fixture prepares successfully before target moves"
    )

    try fixture.write(
        "late target\n",
        path: "late-target.txt",
        at: fixture.root
    )

    try await fixture.commit(
        "late target",
        paths: [
            "late-target.txt",
        ],
        at: fixture.root
    )

    let movedTarget = try await fixture.head()

    do {
        _ = try await GitManagerIntegrationExecutor.promote(
            execution,
            targetBranch: "master",
            at: fixture.root
        )

        try Expect.true(
            false,
            "promotion must reject target movement after preparation"
        )
    } catch let error as GitManagerIntegrationExecutionError {
        try Expect.equal(
            error,
            .staleTarget(
                expected: plan.target.commit,
                actual: movedTarget
            ),
            "promotion fails closed when target moved"
        )
    }

    try Expect.equal(
        try await fixture.head(),
        movedTarget,
        "rejected promotion leaves moved target unchanged"
    )

    try await GitManagerIntegrationExecutor.cleanup(
        execution,
        discard: true,
        at: fixture.root
    )

    try Expect.true(
        try await branchExists(
            sourceBranch,
            at: fixture.root
        ),
        "discarding stale prepared integration preserves source branch"
    )
}

private func proveConflictedIntegrationIsolation() async throws {
    let fixture = try await GitManagerWorktreeFixture.make()

    defer {
        fixture.remove()
    }

    let sourceID = try GitManagerIsolationID(
        "conflicted integration source"
    )
    let sourceDestination = fixture.worktreesRoot
        .appendingPathComponent(
            "source",
            isDirectory: true
        )
    let sourceBranch = sourceID.branchName()

    _ = try await GitManagerWorktree.create(
        .init(
            repository: fixture.root,
            destination: sourceDestination,
            baseRef: "master",
            checkout: .newBranch(
                sourceBranch
            )
        )
    )

    try fixture.write(
        "source\n",
        path: "shared.txt",
        at: sourceDestination
    )

    try await fixture.commit(
        "source conflict",
        paths: [
            "shared.txt",
        ],
        at: sourceDestination
    )

    let sourceHead = try await fixture.head(
        at: sourceDestination
    )

    try fixture.write(
        "target\n",
        path: "shared.txt",
        at: fixture.root
    )

    try await fixture.commit(
        "target conflict",
        paths: [
            "shared.txt",
        ],
        at: fixture.root
    )

    let targetBefore = try await fixture.head()

    let plan = try await GitManagerIntegrationPlanner.plan(
        sourceRef: sourceBranch,
        targetRef: "master",
        at: fixture.root
    )

    try Expect.equal(
        plan.classification,
        .conflicts,
        "conflict fixture is classified before execution"
    )

    let integrationID = try GitManagerIsolationID(
        "conflicted integration execution"
    )
    let integrationDestination = fixture.worktreesRoot
        .appendingPathComponent(
            "integration",
            isDirectory: true
        )

    let execution = try await GitManagerIntegrationExecutor.prepare(
        plan,
        isolationID: integrationID,
        destination: integrationDestination,
        at: fixture.root
    )

    try Expect.equal(
        execution.status,
        .conflicts,
        "conflicted integration remains contained in disposable worktree"
    )

    try Expect.true(
        execution.conflictPaths.contains(
            "shared.txt"
        ),
        "execution reports actual unmerged path"
    )

    try Expect.equal(
        try await fixture.head(),
        targetBefore,
        "conflicted preparation does not move target"
    )

    try Expect.equal(
        try await fixture.head(
            at: sourceDestination
        ),
        sourceHead,
        "conflicted preparation does not move source"
    )

    do {
        _ = try await GitManagerIntegrationExecutor.promote(
            execution,
            targetBranch: "master",
            at: fixture.root
        )

        try Expect.true(
            false,
            "conflicted integration must not promote"
        )
    } catch let error as GitManagerIntegrationExecutionError {
        try Expect.equal(
            error,
            .integrationNotReady(
                .conflicts
            ),
            "conflicted integration promotion fails closed"
        )
    }

    try await GitManagerIntegrationExecutor.cleanup(
        execution,
        discard: true,
        at: fixture.root
    )

    try Expect.true(
        !FileManager.default.fileExists(
            atPath: integrationDestination.path
        ),
        "discarded conflicted integration worktree is removed"
    )

    try Expect.equal(
        try await fixture.head(),
        targetBefore,
        "discarding conflicted integration preserves target HEAD"
    )

    try Expect.equal(
        try await fixture.head(
            at: sourceDestination
        ),
        sourceHead,
        "discarding conflicted integration preserves source HEAD"
    )

    try Expect.true(
        try await branchExists(
            sourceBranch,
            at: fixture.root
        ),
        "discarding conflicted integration preserves source branch"
    )
}

private func branchExists(
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
        throw GitManagerIntegrationExecutionError.gitFailed(
            operation: "git show-ref",
            code: result.code,
            stderr: result.err.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        )
    }
}
