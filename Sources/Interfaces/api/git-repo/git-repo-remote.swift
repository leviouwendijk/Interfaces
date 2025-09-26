import Foundation
import plate

extension GitRepo {
    /// Resolve (remote, branch). Prefer configured upstream; fall back to origin/HEAD.
    public static func defaultRemoteAndBranch(_ directoryURL: URL) async throws -> (remote: String, branch: String) {
        // Try configured upstream first.
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

    /// Ensure we have the latest remote branch (shallow).
    public static func fetchDefaultRemote(_ directoryURL: URL) async throws -> (remote: String, branch: String) {
        let (remote, branch) = try await defaultRemoteAndBranch(directoryURL)
        _ = try await gitOut(directoryURL, ["fetch", "--depth", "1", remote, branch])
        return (remote, branch)
    }
}

extension GitRepo {
    /// Fetch text content of a path at origin/<branch>. If `ref` is provided, use it (e.g. "refs/heads/master").
    public static func fetchRemoteFile(_ directoryURL: URL, path: String, ref: String? = nil) async throws -> String {
        let (remote, branch) = try await (ref == nil
            ? fetchDefaultRemote(directoryURL)
            : { ("origin", ref!) }())
        let (code, out, err) = try await git(directoryURL, ["show", "\(remote)/\(branch):\(path)"])
        guard code == 0 else {
            if err.contains("fatal: Path") || err.contains("fatal: invalid object name") {
                throw RemoteError.fileMissing(path)
            }
            throw RemoteError.processFailed(code, err)
        }
        return out
    }

    /// High-level: load and parse build-object from remote git. Tries modern first, then legacy→modernize.
    public static func fetchRemoteBuildObject(
        _ directoryURL: URL,
        filename: String = "build-object.pkl",
        ref: String? = nil
    ) async throws -> BuildObjectConfiguration {
        let text = try await fetchRemoteFile(directoryURL, path: filename, ref: ref)
        let parser = PklParser(text)
        if let modern = try? parser.parseBuildObject() { return modern }
        let legacy = try parser.parseLegacyBuildObject()
        return legacy.modernize()
    }

    public static func fetchBuildObject(fromUpdateURL urlString: String) async throws -> BuildObjectConfiguration {
        guard let url = URL(string: urlString) else { throw RemoteError.badURL(urlString) }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let text = String(data: data, encoding: .utf8) else {
            throw RemoteError.fileMissing(urlString)
        }
        let parser = PklParser(text)
        if let modern = try? parser.parseBuildObject() { return modern }
        let legacy = try parser.parseLegacyBuildObject()
        return legacy.modernize()
    }
}

extension GitRepo {
    /// Build a raw HTTP URL to `file` on the default remote/branch (supports GitHub/GitLab/Bitbucket).
    public static func remoteRawBuildObjectURL(
        _ directoryURL: URL,
        file: String = "build-object.pkl",
        ref: String? = nil
    ) async throws -> String {
        // Resolve branch (prefer upstream/origin HEAD)
        let branch: String = try await {
            if let r = ref { return r }
            let (_, b) = try await defaultRemoteAndBranch(directoryURL)
            return b
        }()

        // Get the origin remote URL (ssh or https)
        let remote = try await gitOut(directoryURL, ["remote", "get-url", "origin"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remote.isEmpty else { throw RemoteError.noOrigin }

        // Parse host/owner/repo
        func parseOwnerRepo(_ s: String) -> (host: String, owner: String, repo: String)? {
            if s.hasPrefix("git@"),
               let at = s.firstIndex(of: "@"),
               let colon = s.firstIndex(of: ":")
            {
                let host = String(s[s.index(after: at)..<colon])
                let path = s[s.index(after: colon)...]
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    .replacingOccurrences(of: ".git", with: "")
                let comps = path.split(separator: "/").map(String.init)
                guard comps.count >= 2 else { return nil }
                return (host, comps[0], comps[1])
            } else if let url = URL(string: s), let host = url.host {
                let comps = url.path
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    .replacingOccurrences(of: ".git", with: "")
                    .split(separator: "/").map(String.init)
                guard comps.count >= 2 else { return nil }
                return (host, comps[0], comps[1])
            }
            return nil
        }

        guard let (host, owner, repo) = parseOwnerRepo(remote) else {
            throw RemoteError.badURL(remote)
        }

        // Construct raw URL per known host
        switch host.lowercased() {
        case "github.com":
            return "https://raw.githubusercontent.com/\(owner)/\(repo)/\(branch)/\(file)"
        case "gitlab.com":
            // Note: GitLab raw uses /-/raw/<branch>/<path>
            return "https://gitlab.com/\(owner)/\(repo)/-/raw/\(branch)/\(file)"
        case "bitbucket.org":
            return "https://bitbucket.org/\(owner)/\(repo)/raw/\(branch)/\(file)"
        default:
            throw RemoteError.headNotResolvable("Unsupported host: \(host)")
        }
    }
}
