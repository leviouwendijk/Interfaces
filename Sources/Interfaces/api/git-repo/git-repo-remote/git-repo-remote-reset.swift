import Foundation
import plate

extension GitRepo {
    /// Make the local branch exactly equal to @{u}. Optionally drop untracked files.
    @discardableResult
    public static func hardResetToUpstream(
        _ dir: URL,
        cleanUntracked: Bool = false,
        ensureFullHistory: Bool = true   // avoids phantom divergence
    ) async throws -> Void {
        // 1) Resolve upstream (origin/<branch> or whatever @{u} is)
        let (remote, branch) = try await defaultRemoteAndBranch(dir)

        // 2) Fetch in a way that preserves the commit graph for reliable HEAD...@{u} math
        var fetch = ["fetch", "--prune", "--tags"]
        if ensureFullHistory {
            // If the repo is shallow, unshallow to restore a real graph
            let isShallow = try await gitOut(dir, ["rev-parse","--is-shallow-repository"])
                .trimmingCharacters(in: .whitespacesAndNewlines) == "true"
            if isShallow { fetch.append("--unshallow") }
            // Optional speed-up without breaking history
            fetch.append(contentsOf: ["--filter=blob:none"])
        }
        fetch.append(contentsOf: [remote, branch])
        _ = try await gitOut(dir, fetch)

        // 3) Reset to upstream byte-for-byte
        _ = try await gitOut(dir, ["reset", "--hard", "@{u}"])

        // 4) Optional: purge untracked (e.g., build artifacts, Package.resolved drift)
        if cleanUntracked {
            _ = try await gitOut(dir, ["clean", "-fdx"])
        }
    }
}
