import Foundation

public enum GitRepo {
    public enum Error: Swift.Error, LocalizedError, Sendable {
        case noUpstreamConfigured
        case invalidRevListOutput(raw: String)

        public var errorDescription: String? {
            switch self {
            case .noUpstreamConfigured:
                return "No upstream configured for the current branch."
            case .invalidRevListOutput(let raw):
                return "Unexpected output from `git rev-list --left-right --count HEAD...@{u}`: \(raw)"
            }
        }
    }

    public enum Head { 
        case local
        case remote 
    }

    public static func upstream(_ directoryURL: URL) async throws -> (remote: String, branch: String) {
        let s = try await sh(
            .zsh,
            "git",
            ["rev-parse","--abbrev-ref","--symbolic-full-name","@{u}"],
            cwd: directoryURL
        )
        .stdoutText().trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = s.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            throw GitRepo.Error.noUpstreamConfigured
        }
        return (parts[0], parts[1])
    }

    public static func fetchUpstream(_ directoryURL: URL, prune: Bool = true) async throws {
        let (remote, _) = try await upstream(directoryURL)
        var args = ["fetch", remote]
        if prune { args.append("--prune") }
        _ = try await sh(.zsh, "git", args, cwd: directoryURL)
    }

    public static func head(_ directoryURL: URL, _ host: Head) async throws -> String {
        switch host {
        case .local:
            return try await sh(.zsh, "git", ["rev-parse","HEAD"], cwd: directoryURL)
            .stdoutText().trimmingCharacters(in: .whitespacesAndNewlines)
        case .remote:
            return try await sh(.zsh, "git", ["rev-parse","@{u}"], cwd: directoryURL)
            .stdoutText().trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    public struct Divergence: Equatable, Sendable {
        public let ahead: Int   
        public let behind: Int 
        public var isUpToDate: Bool { ahead == 0 && behind == 0 }
    }

    public static func outdated(_ directoryURL: URL) async throws -> Bool {
        try await fetchUpstream(directoryURL, prune: true)
        let local  = try await head(directoryURL, .local)
        let remote = try await head(directoryURL, .remote)
        return local != remote
    }

    public static func divergence(_ directoryURL: URL) async throws -> Divergence {
        try await fetchUpstream(directoryURL, prune: true)
        let out = try await sh(
            .zsh,
            "git",
            ["rev-list","--left-right","--count","HEAD...@{u}"],
           cwd: directoryURL
        )
        .stdoutText().trimmingCharacters(in: .whitespacesAndNewlines)

        // format: "<ahead>\t<behind>"
        let parts = out.split { $0 == " " || $0 == "\t" }.compactMap { Int($0) }
        guard parts.count == 2 else {
            throw GitRepo.Error.invalidRevListOutput(raw: out)
        }
        return Divergence(ahead: parts[0], behind: parts[1])
    }
}
