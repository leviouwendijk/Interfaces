import Foundation
import plate

extension GitRepo {
    ///   git@github.com:owner/repo.git
    ///   https://github.com/owner/repo.git
    ///   ssh://git@github.com/owner/repo.git
    ///   git://github.com/owner/repo
    public static func parseOwnerRepo(_ remote: String) -> RemoteID? {
        if remote.hasPrefix("git@"),
           let at = remote.firstIndex(of: "@"),
           let colon = remote.firstIndex(of: ":") {
            let host = String(remote[remote.index(after: at)..<colon])
            let path = remote[remote.index(after: colon)...]
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .replacingOccurrences(of: ".git", with: "")
            let comps = path.split(separator: "/").map(String.init)
            guard comps.count >= 2 else { return nil }
            return .init(host: host, owner: comps[0], repo: comps[1])
        }

        // ssh://, https://, http://, git://
        if let url = URL(string: remote),
           let host = url.host {
            let comps = url.path
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .replacingOccurrences(of: ".git", with: "")
                .split(separator: "/").map(String.init)
            guard comps.count >= 2 else { return nil }
            return .init(host: host, owner: comps[0], repo: comps[1])
        }

        return nil
    }

    /// Repo web root URL (e.g. https://github.com/owner/repo) if host is known.
    public static func repoWebURL(_ id: RemoteID) -> URL? {
        switch id.host.lowercased() {
        case "github.com":    return URL(string: "https://github.com/\(id.owner)/\(id.repo)")
        case "gitlab.com":    return URL(string: "https://gitlab.com/\(id.owner)/\(id.repo)")
        case "bitbucket.org": return URL(string: "https://bitbucket.org/\(id.owner)/\(id.repo)")
        default:              return nil
        }
    }

    public static func repoWebURL(_ id: RemoteID, path: [String] = [], branchTree: String? = nil) -> URL? {
        guard var base = repoWebURL(id) else { return nil }

        if let branch = branchTree, !branch.isEmpty {
            switch id.host.lowercased() {
            case "github.com":
                base.appendPathComponent("tree")
                base.appendPathComponent(branch)
            case "gitlab.com":
                base.appendPathComponent("-")
                base.appendPathComponent("tree")
                base.appendPathComponent(branch)
            case "bitbucket.org":
                base.appendPathComponent("branch")
                base.appendPathComponent(branch)
            default:
                break
            }
        }

        for p in path { base.appendPathComponent(p) }
        return base
    }

    public static func repoWebURL(
        directoryURL: URL,
        remoteName: String = "origin",
        path: [String] = [],
        useBranchTree: Bool = false,
        ref: String? = nil
    ) async throws -> URL {
        let remoteStr = try await gitOut(directoryURL, ["remote", "get-url", remoteName])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remoteStr.isEmpty else { throw RemoteError.noOrigin }

        guard let id = parseOwnerRepo(remoteStr) else {
            throw RemoteError.badURL(remoteStr)
        }

        let branch: String?
        if useBranchTree {
            if let r = ref {
                branch = r
            } else if let (_, b) = try? await defaultRemoteAndBranch(directoryURL) {
                branch = b
            } else {
                branch = nil
            }
        } else {
            branch = nil
        }

        guard let url = repoWebURL(id, path: path, branchTree: branch) else {
            throw RemoteError.headNotResolvable("Unsupported host: \(id.host)")
        }
        return url
    }
}
