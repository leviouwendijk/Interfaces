import Foundation
import plate

public enum GitRepo {
    @discardableResult
    public static func git(_ cwd: URL, _ args: [String]) async throws -> (code: Int32, out: String, err: String) {
        let res = try await sh(.zsh, "git", args, cwd: cwd)
        let out = res.stdoutText()
        let err = res.stderrText()
        return (Int32(res.exitCode ?? 0), out, err)
    }

    public static func gitOut(_ cwd: URL, _ args: [String]) async throws -> String {
        let (code, out, err) = try await git(cwd, args)
        guard code == 0 else { throw RemoteError.processFailed(code, err) }
        return out
    }
}
