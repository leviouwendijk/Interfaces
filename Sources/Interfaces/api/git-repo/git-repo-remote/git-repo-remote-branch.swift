import Foundation
import plate

extension GitRepo {
    public static func defaultRemoteAndBranch(_ directoryURL: URL) async throws -> (remote: String, branch: String) {
        if let up = try? await upstream(directoryURL) {
            return up // (remote, branch)
        }
        // Fallback to origin/HEAD symref.
        let (code, out, err) = try await git(directoryURL, ["ls-remote", "--symref", "origin", "HEAD"])
        guard code == 0 else {
            if err.contains("No such remote") { throw RemoteError.noOrigin }
            throw RemoteError.processFailed(code, err)
        }
        // Example: "ref: refs/heads/main\tHEAD\n<sha>\tHEAD\n"
        guard let line = out.split(separator: "\n").first(where: { $0.contains("ref:") }),
              let range = line.range(of: "refs/heads/") else {
            throw RemoteError.headNotResolvable(out.isEmpty ? err : out)
        }
        let branch = line[range.upperBound...].split(separator: "\t").first.map(String.init) ?? "master"
        return ("origin", branch)
    }

    public static func fetchDefaultRemote(_ directoryURL: URL) async throws -> (remote: String, branch: String) {
        let (remote, branch) = try await defaultRemoteAndBranch(directoryURL)
        _ = try await gitOut(directoryURL, ["fetch", "--depth", "1", remote, branch])
        return (remote, branch)
    }
}
