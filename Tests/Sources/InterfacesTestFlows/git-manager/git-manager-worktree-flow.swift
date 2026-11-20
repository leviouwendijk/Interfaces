import Foundation
import Interfaces
import TestFlows

extension InterfacesFlowSuite {
    static var gitManagerWorktreeFlow: TestFlow {
        TestFlow(
            "git-manager-worktree",
            tags: [
                "git",
                "worktree",
                "isolation",
            ]
        ) {
            let fixture = try await GitManagerWorktreeFixture.make()

            defer {
                fixture.remove()
            }

            let alphaID = try GitManagerIsolationID(
                "agentic cross-lib feature alpha"
            )
            let alphaIDAgain = try GitManagerIsolationID(
                "agentic cross-lib feature alpha"
            )
            let betaID = try GitManagerIsolationID(
                "agentic cross-lib feature beta"
            )

            try Expect.equal(
                alphaID,
                alphaIDAgain,
                "same semantic isolation key resolves deterministically"
            )

            try Expect.true(
                alphaID != betaID,
                "different semantic isolation keys resolve differently"
            )

            try Expect.contains(
                alphaID.branchName(),
                alphaID.digest,
                "isolation branch includes deterministic collision-resistant digest"
            )

            let alphaDestination = fixture.worktreesRoot
                .appendingPathComponent(
                    "alpha",
                    isDirectory: true
                )
            let betaDestination = fixture.worktreesRoot
                .appendingPathComponent(
                    "beta",
                    isDirectory: true
                )

            let alphaBranch = alphaID.branchName()
            let betaBranch = betaID.branchName()

            let alpha = try await GitManagerWorktree.create(
                .init(
                    repository: fixture.root,
                    destination: alphaDestination,
                    baseRef: "master",
                    checkout: .newBranch(
                        alphaBranch
                    )
                )
            )

            let beta = try await GitManagerWorktree.create(
                .init(
                    repository: fixture.root,
                    destination: betaDestination,
                    baseRef: "master",
                    checkout: .newBranch(
                        betaBranch
                    )
                )
            )

            try Expect.equal(
                alpha.baseCommit,
                beta.baseCommit,
                "parallel worktrees retain the same resolved base commit"
            )

            try Expect.equal(
                try await fixture.branch(
                    at: alphaDestination
                ),
                alphaBranch,
                "alpha worktree owns its semantic branch"
            )

            try Expect.equal(
                try await fixture.branch(
                    at: betaDestination
                ),
                betaBranch,
                "beta worktree owns its semantic branch"
            )

            try fixture.write(
                "alpha\n",
                path: "shared.txt",
                at: alphaDestination
            )
            try fixture.write(
                "beta\n",
                path: "shared.txt",
                at: betaDestination
            )

            try Expect.equal(
                try fixture.read(
                    "shared.txt",
                    at: fixture.root
                ),
                "base\n",
                "parallel worktree edits do not alter the primary worktree"
            )

            try Expect.equal(
                try fixture.read(
                    "shared.txt",
                    at: alphaDestination
                ),
                "alpha\n",
                "alpha worktree retains its own filesystem state"
            )

            try Expect.equal(
                try fixture.read(
                    "shared.txt",
                    at: betaDestination
                ),
                "beta\n",
                "beta worktree retains its own filesystem state"
            )

            try await fixture.commit(
                "alpha",
                paths: [
                    "shared.txt",
                ],
                at: alphaDestination
            )

            try await fixture.commit(
                "beta",
                paths: [
                    "shared.txt",
                ],
                at: betaDestination
            )

            let occupiedAlpha = try await GitManagerWorktree.occupied(
                by: alphaBranch,
                at: fixture.root
            )

            try Expect.equal(
                occupiedAlpha?.path,
                alphaDestination.standardizedFileURL,
                "branch occupancy resolves the owning worktree"
            )

            try await GitManagerWorktree.lock(
                alphaDestination,
                reason: "integration test",
                at: fixture.root
            )

            let lockedAlpha = try await GitManagerWorktree.list(
                at: fixture.root
            )
            .first {
                $0.path == alphaDestination.standardizedFileURL
            }

            try Expect.true(
                lockedAlpha?.isLocked == true,
                "worktree lock state is observable"
            )

            try await GitManagerWorktree.unlock(
                alphaDestination,
                at: fixture.root
            )

            try await GitManagerWorktree.remove(
                alphaDestination,
                at: fixture.root
            )

            try await GitManagerWorktree.remove(
                betaDestination,
                at: fixture.root
            )

            _ = try await GitManagerWorktree.prune(
                at: fixture.root,
                dryRun: true
            )

            let remaining = try await GitManagerWorktree.list(
                at: fixture.root
            )

            try Expect.equal(
                remaining.count,
                1,
                "removing linked worktrees leaves only the primary worktree"
            )

            return []
        }
    }
}
