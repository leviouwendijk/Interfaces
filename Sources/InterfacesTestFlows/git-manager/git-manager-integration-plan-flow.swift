import Foundation
import Interfaces
import TestFlows

extension InterfacesFlowSuite {
    static var gitManagerIntegrationPlanFlow: TestFlow {
        TestFlow(
            "git-manager-integration-plan",
            tags: [
                "git",
                "integration",
                "plan",
                "observe",
            ]
        ) {
            try await proveFastForwardPlan()
            try await proveCleanMergeAndDriftPlan()
            try await proveConflictPlan()

            return [
                .field(
                    "cases",
                    "3"
                ),
            ]
        }
    }
}

private func proveFastForwardPlan() async throws {
    let fixture = try await GitManagerWorktreeFixture.make()

    defer {
        fixture.remove()
    }

    let base = try await fixture.head()
    let sourceID = try GitManagerIsolationID(
        "integration fast-forward"
    )
    let destination = fixture.worktreesRoot
        .appendingPathComponent(
            "source",
            isDirectory: true
        )
    let branch = sourceID.branchName()

    _ = try await GitManagerWorktree.create(
        .init(
            repository: fixture.root,
            destination: destination,
            baseRef: "master",
            checkout: .newBranch(
                branch
            )
        )
    )

    try fixture.write(
        "source\n",
        path: "source.txt",
        at: destination
    )

    try await fixture.commit(
        "source",
        paths: [
            "source.txt",
        ],
        at: destination
    )

    let sourceHead = try await fixture.head(
        at: destination
    )

    let plan = try await GitManagerIntegrationPlanner.plan(
        sourceRef: branch,
        targetRef: "master",
        expectedTargetCommit: base,
        at: fixture.root
    )

    try Expect.equal(
        plan.classification,
        .fastForward,
        "source-only advancement is classified as fast-forward"
    )

    try Expect.true(
        !plan.targetDrifted,
        "unchanged target is not marked drifted"
    )

    try Expect.equal(
        plan.mergeBase,
        base,
        "fast-forward merge base is the original target commit"
    )

    try Expect.equal(
        plan.source.commit,
        sourceHead,
        "plan retains the exact source commit"
    )

    try Expect.equal(
        plan.target.commit,
        base,
        "plan retains the exact target commit"
    )

    try Expect.equal(
        plan.sourceCommitCount,
        1,
        "fast-forward source contains one new commit"
    )

    try Expect.equal(
        plan.targetCommitCount,
        0,
        "fast-forward target contains no divergent commits"
    )

    try Expect.equal(
        plan.sourcePaths,
        [
            "source.txt",
        ],
        "fast-forward plan retains source changed paths"
    )
}

private func proveCleanMergeAndDriftPlan() async throws {
    let fixture = try await GitManagerWorktreeFixture.make()

    defer {
        fixture.remove()
    }

    let base = try await fixture.head()
    let sourceID = try GitManagerIsolationID(
        "integration clean merge"
    )
    let destination = fixture.worktreesRoot
        .appendingPathComponent(
            "source",
            isDirectory: true
        )
    let branch = sourceID.branchName()

    _ = try await GitManagerWorktree.create(
        .init(
            repository: fixture.root,
            destination: destination,
            baseRef: "master",
            checkout: .newBranch(
                branch
            )
        )
    )

    try fixture.write(
        "source\n",
        path: "source.txt",
        at: destination
    )

    try await fixture.commit(
        "source",
        paths: [
            "source.txt",
        ],
        at: destination
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

    let targetHead = try await fixture.head()

    let plan = try await GitManagerIntegrationPlanner.plan(
        sourceRef: branch,
        targetRef: "master",
        expectedTargetCommit: base,
        at: fixture.root
    )

    try Expect.equal(
        plan.classification,
        .cleanMerge,
        "non-overlapping divergent changes are classified as clean merge"
    )

    try Expect.true(
        plan.targetDrifted,
        "target advancement since isolation is retained as drift"
    )

    try Expect.equal(
        plan.mergeBase,
        base,
        "clean merge retains the original common ancestor"
    )

    try Expect.equal(
        plan.target.commit,
        targetHead,
        "plan captures the target commit after drift"
    )

    try Expect.equal(
        plan.sourceCommitCount,
        1,
        "clean merge source divergence count"
    )

    try Expect.equal(
        plan.targetCommitCount,
        1,
        "clean merge target divergence count"
    )

    try Expect.equal(
        plan.sourcePaths,
        [
            "source.txt",
        ],
        "clean merge plan retains source changed paths"
    )

    try Expect.equal(
        plan.targetPaths,
        [
            "target.txt",
        ],
        "clean merge plan retains target changed paths"
    )

    try Expect.equal(
        plan.overlappingPaths,
        [],
        "non-overlapping merge has no path overlap"
    )

    try Expect.equal(
        plan.conflictPaths,
        [],
        "clean merge has no merge-tree conflicts"
    )
}

private func proveConflictPlan() async throws {
    let fixture = try await GitManagerWorktreeFixture.make()

    defer {
        fixture.remove()
    }

    let sourceID = try GitManagerIsolationID(
        "integration conflict"
    )
    let destination = fixture.worktreesRoot
        .appendingPathComponent(
            "source",
            isDirectory: true
        )
    let branch = sourceID.branchName()

    _ = try await GitManagerWorktree.create(
        .init(
            repository: fixture.root,
            destination: destination,
            baseRef: "master",
            checkout: .newBranch(
                branch
            )
        )
    )

    try fixture.write(
        "source\n",
        path: "shared.txt",
        at: destination
    )

    try await fixture.commit(
        "source conflict",
        paths: [
            "shared.txt",
        ],
        at: destination
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

    let sourceHead = try await fixture.head(
        at: destination
    )
    let targetHead = try await fixture.head()

    let plan = try await GitManagerIntegrationPlanner.plan(
        sourceRef: branch,
        targetRef: "master",
        at: fixture.root
    )

    try Expect.equal(
        plan.classification,
        .conflicts,
        "real merge conflict is detected without mutating either branch"
    )

    try Expect.equal(
        plan.overlappingPaths,
        [
            "shared.txt",
        ],
        "conflict plan retains overlapping path"
    )

    try Expect.true(
        plan.conflictPaths.contains(
            "shared.txt"
        ),
        "merge-tree proof retains conflicting path"
    )

    try Expect.equal(
        try await fixture.head(
            at: destination
        ),
        sourceHead,
        "planning does not move source HEAD"
    )

    try Expect.equal(
        try await fixture.head(),
        targetHead,
        "planning does not move target HEAD"
    )

    try Expect.equal(
        try fixture.read(
            "shared.txt",
            at: fixture.root
        ),
        "target\n",
        "planning does not alter target working tree"
    )

    try Expect.equal(
        try fixture.read(
            "shared.txt",
            at: destination
        ),
        "source\n",
        "planning does not alter source working tree"
    )
}
