import Foundation
import plate

extension GitRepo {
    @inline(__always)
    public static func isDirty(_ dir: URL, includeUntracked: Bool = true) async throws -> Bool {
        var args = ["status", "--porcelain"]
        if !includeUntracked { args.append("--untracked-files=no") }
        let out = try await gitOut(dir, args).trimmingCharacters(in: .whitespacesAndNewlines)
        return !out.isEmpty
    }

    @inline(__always)
    public static func hasUntracked(_ dir: URL) async throws -> Bool {
        let out = try await gitOut(dir, ["ls-files", "--others", "--exclude-standard"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return !out.isEmpty
    }
}
