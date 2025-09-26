import Foundation
import plate

extension GitRepo {
    @available(*, deprecated, message: "Use fetchDefaultRemote(_:)")
    public static func fetchUpstream(_ dir: URL, prune: Bool = true) async throws {
        _ = try await fetchDefaultRemote(dir)
    }
}

extension GitRepo {
    public static func upstream(_ dir: URL) async throws -> (remote:String, branch:String) {
        let s = try await gitOut(dir, ["rev-parse","--abbrev-ref","--symbolic-full-name","@{u}"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = s.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { throw GitRepo.Error.noUpstreamConfigured }
        return (parts[0], parts[1])
    }

    public static func head(_ dir: URL, _ host: Head) async throws -> String {
        switch host {
        case .local:  return try await gitOut(dir, ["rev-parse","HEAD"]).trimmingCharacters(in: .whitespacesAndNewlines)
        case .remote: return try await gitOut(dir, ["rev-parse","@{u}"]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    public struct Divergence: Equatable, Sendable {
        public let ahead: Int   
        public let behind: Int 
        public var isUpToDate: Bool { ahead == 0 && behind == 0 }
    }

    public static func outdated(_ dir: URL) async throws -> Bool {
        _ = try await fetchDefaultRemote(dir)
        return try await head(dir, .local) != head(dir, .remote)
    }

    public static func divergence(_ dir: URL) async throws -> Divergence {
        _ = try await fetchDefaultRemote(dir)
        let out = try await gitOut(dir, ["rev-list","--left-right","--count","HEAD...@{u}"])
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = out.split { $0 == " " || $0 == "\t" }.compactMap { Int($0) }
        guard parts.count == 2 else { throw GitRepo.Error.invalidRevListOutput(raw: out) }
        return .init(ahead: parts[0], behind: parts[1])
    }
}
