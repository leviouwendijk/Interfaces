import Foundation
import Version

/// Releases are annotated git tags named by `ReleaseTag` (bare semver).
extension GitRepo {
    public enum ReleaseError: Swift.Error, Sendable, LocalizedError {
        case dirty(URL)
        case unpushed(URL, ahead: Int)
        case exists(String)
        case alreadyReleased(String)
        case notNewer(String, latest: String)

        public var errorDescription: String? {
            switch self {
            case .dirty(let directory):
                return "\(directory.path) has uncommitted changes; commit them before tagging a release."
            case .unpushed(let directory, let ahead):
                return "\(directory.path) is \(ahead) commit(s) ahead of its upstream; push before tagging a release."
            case .exists(let tag):
                return "Tag \(tag) already exists (as \(tag) or v\(tag))."
            case .notNewer(let tag, let latest):
                return "\(tag) is not newer than the latest release \(latest)."
            case .alreadyReleased(let tag):
                return "HEAD is already released as \(tag); commit something new before the next release."
            }
        }
    }

    /// The newest release tag reachable from HEAD.
    public static func latestRelease(at directory: URL) async throws -> ObjectVersion? {
        ReleaseTag.latest(in: try await tagNames(at: directory, ["tag", "--merged", "HEAD", "--list"]))
    }

    /// Tags HEAD with the target's version, annotated, without pushing. Refuses a dirty HEAD, a
    /// HEAD that is already released, a version tagged before, and a version not newer than the
    /// latest release. With `requirePushed`, HEAD must already be on its upstream (the tag then
    /// marks something public); without it, the caller pushes the commit and the tag together.
    @discardableResult
    public static func tagRelease(
        _ target: ReleaseTarget,
        at directory: URL,
        requirePushed: Bool
    ) async throws -> (from: ObjectVersion?, to: ObjectVersion) {
        guard try await !isDirty(directory) else { throw ReleaseError.dirty(directory) }
        if requirePushed {
            let divergence = try await divergence(directory)
            guard divergence.ahead == 0 else { throw ReleaseError.unpushed(directory, ahead: divergence.ahead) }
        }

        if let released = try await tagNames(at: directory, ["tag", "--points-at", "HEAD"])
            .first(where: { ReleaseTag.version(of: $0) != nil }) {
            throw ReleaseError.alreadyReleased(released)
        }

        let planned = try await plannedRelease(target, at: directory)
        let tag = ReleaseTag.name(for: planned.to)
        _ = try await gitOut(directory, ["tag", "-a", tag, "-m", tag])
        return planned
    }

    /// The version a release of `target` would get, checked against the existing tags (newer
    /// than the latest release, not tagged before) without tagging anything. Lets a caller
    /// refuse a release before it commits.
    public static func plannedRelease(
        _ target: ReleaseTarget,
        at directory: URL
    ) async throws -> (from: ObjectVersion?, to: ObjectVersion) {
        let latest = try await latestRelease(at: directory)
        let version = target.version(after: latest)
        let tag = ReleaseTag.name(for: version)
        if let latest, version <= latest {
            throw ReleaseError.notNewer(tag, latest: ReleaseTag.name(for: latest))
        }
        guard !ReleaseTag.isTagged(version, in: try await tagNames(at: directory, ["tag", "--list"])) else {
            throw ReleaseError.exists(tag)
        }
        return (latest, version)
    }

    /// Tags HEAD (already pushed) with the target's version and pushes the tag to the upstream remote.
    @discardableResult
    public static func release(
        _ target: ReleaseTarget,
        at directory: URL
    ) async throws -> (from: ObjectVersion?, to: ObjectVersion) {
        let result = try await tagRelease(target, at: directory, requirePushed: true)
        let (remote, _) = try await upstream(directory)
        _ = try await gitOut(directory, ["push", remote, ReleaseTag.name(for: result.to)])
        return result
    }

    /// Removes a local tag, for a release whose push failed.
    public static func deleteTag(_ tag: String, at directory: URL) async throws {
        _ = try await gitOut(directory, ["tag", "-d", tag])
    }

    private static func tagNames(at directory: URL, _ arguments: [String]) async throws -> [String] {
        try await gitOut(directory, arguments)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
