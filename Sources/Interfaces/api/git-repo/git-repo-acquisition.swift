import Foundation

public extension GitRepo {
    static func clone(
        _ origin: URL,
        to destination: URL
    ) async throws {
        _ = try await gitOut(
            destination.deletingLastPathComponent(),
            [
                "clone",
                origin.absoluteString,
                destination.standardizedFileURL.path,
            ]
        )
    }

    static func resolveCommit(
        _ reference: String,
        at repository: URL
    ) async throws -> String {
        try await gitOut(
            repository,
            [
                "rev-parse",
                "--verify",
                "\(reference)^{commit}",
            ]
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }
}
