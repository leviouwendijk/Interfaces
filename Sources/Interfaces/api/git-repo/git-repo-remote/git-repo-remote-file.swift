import Foundation
import plate

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
