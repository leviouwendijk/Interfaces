import Foundation
import plate

extension GitRepo {
    public static func remoteRawBuildObjectURL(
        _ directoryURL: URL,
        file: String = "build-object.pkl",
        ref: String? = nil
    ) async throws -> String {
        // let branch: String = try await {
        //     if let r = ref { return r }
        //     let (_, b) = try await defaultRemoteAndBranch(directoryURL)
        //     return b
        // }()

        // let remote = try await gitOut(directoryURL, ["remote", "get-url", "origin"])
        //     .trimmingCharacters(in: .whitespacesAndNewlines)
        // guard !remote.isEmpty else { throw RemoteError.noOrigin }

        // func parseOwnerRepo(_ s: String) -> (host: String, owner: String, repo: String)? {
        //     if s.hasPrefix("git@"),
        //        let at = s.firstIndex(of: "@"),
        //        let colon = s.firstIndex(of: ":")
        //     {
        //         let host = String(s[s.index(after: at)..<colon])
        //         let path = s[s.index(after: colon)...]
        //             .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        //             .replacingOccurrences(of: ".git", with: "")
        //         let comps = path.split(separator: "/").map(String.init)
        //         guard comps.count >= 2 else { return nil }
        //         return (host, comps[0], comps[1])
        //     } else if let url = URL(string: s), let host = url.host {
        //         let comps = url.path
        //             .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        //             .replacingOccurrences(of: ".git", with: "")
        //             .split(separator: "/").map(String.init)
        //         guard comps.count >= 2 else { return nil }
        //         return (host, comps[0], comps[1])
        //     }
        //     return nil
        // }

        // guard let (host, owner, repo) = parseOwnerRepo(remote) else {
        //     throw RemoteError.badURL(remote)
        // }

        let branch: String
        if let r = ref {
            branch = r
        } else {
            let (_, b) = try await defaultRemoteAndBranch(directoryURL)
            branch = b
        }

        let remote = try await gitOut(directoryURL, ["remote", "get-url", "origin"])
        .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remote.isEmpty else { throw RemoteError.noOrigin }

        guard let id = parseOwnerRepo(remote) else {
            throw RemoteError.badURL(remote)
        }

        switch id.host.lowercased() {
        case "github.com":
            return "https://raw.githubusercontent.com/\(id.owner)/\(id.repo)/\(branch)/\(file)"
        case "gitlab.com":
            // Note: GitLab raw uses /-/raw/<branch>/<path>
            return "https://gitlab.com/\(id.owner)/\(id.repo)/-/raw/\(branch)/\(file)"
        case "bitbucket.org":
            return "https://bitbucket.org/\(id.owner)/\(id.repo)/raw/\(branch)/\(file)"
        default:
            throw RemoteError.headNotResolvable("Unsupported host: \(id.host)")
        }
    }
}
