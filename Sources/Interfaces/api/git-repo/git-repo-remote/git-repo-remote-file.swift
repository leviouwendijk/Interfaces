import Foundation

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

    /// Fetch generic UTF-8 text from an update URL. Build-object decoding belongs to Executable.
    public static func fetchText(fromUpdateURL urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else { throw RemoteError.badURL(urlString) }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let text = String(data: data, encoding: .utf8) else {
            throw RemoteError.fileMissing(urlString)
        }
        return text
    }
}
