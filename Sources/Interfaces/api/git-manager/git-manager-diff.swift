import Foundation

public enum GitManagerDiffScope:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case working
    case staged
    case both
}

public struct GitManagerDiffRequest:
    Sendable,
    Codable,
    Hashable
{
    public let scope: GitManagerDiffScope
    public let paths: [String]
    public let contextLines: Int
    public let maxPatchBytes: Int

    public init(
        scope: GitManagerDiffScope = .both,
        paths: [String] = [],
        contextLines: Int = 3,
        maxPatchBytes: Int = 262_144
    ) {
        self.scope = scope
        self.paths = paths
        self.contextLines = min(
            20,
            max(
                0,
                contextLines
            )
        )
        self.maxPatchBytes = min(
            1_048_576,
            max(
                1,
                maxPatchBytes
            )
        )
    }
}

public struct GitManagerDiffSection:
    Sendable,
    Codable,
    Hashable
{
    public let scope: GitManagerDiffScope
    public let changedPaths: [String]
    public let insertions: Int
    public let deletions: Int
    public let patch: String
    public let patchByteCount: Int
    public let truncated: Bool

    public init(
        scope: GitManagerDiffScope,
        changedPaths: [String],
        insertions: Int,
        deletions: Int,
        patch: String,
        patchByteCount: Int,
        truncated: Bool
    ) {
        self.scope = scope
        self.changedPaths = changedPaths
        self.insertions = insertions
        self.deletions = deletions
        self.patch = patch
        self.patchByteCount = patchByteCount
        self.truncated = truncated
    }
}

public struct GitManagerDiffResult:
    Sendable,
    Codable,
    Hashable
{
    public let sections: [GitManagerDiffSection]
    public let hasChanges: Bool

    public init(
        sections: [GitManagerDiffSection]
    ) {
        self.sections = sections
        self.hasChanges = sections.contains {
            !$0.changedPaths.isEmpty
        }
    }
}

public enum GitManagerDiffError:
    Error,
    Sendable,
    LocalizedError
{
    case invalidPath(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPath(let value):
            return """
            Git diff paths must be non-empty repository-relative literal paths without parent traversal. Received: \(value)
            """
        }
    }
}

public enum GitManagerDiff {
    public static func observe(
        _ request: GitManagerDiffRequest = .init(),
        at directory: URL = URL(
            fileURLWithPath:
                FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
    ) async throws -> GitManagerDiffResult {
        let root = try await requireRoot(
            at: directory
        )

        let pathspecs = try literalPathspecs(
            request.paths
        )

        let scopes: [GitManagerDiffScope]

        switch request.scope {
        case .working:
            scopes = [
                .working,
            ]

        case .staged:
            scopes = [
                .staged,
            ]

        case .both:
            scopes = [
                .working,
                .staged,
            ]
        }

        var sections: [GitManagerDiffSection] = []
        sections.reserveCapacity(
            scopes.count
        )

        for scope in scopes {
            sections.append(
                try await section(
                    scope: scope,
                    request: request,
                    pathspecs: pathspecs,
                    at: root
                )
            )
        }

        return .init(
            sections: sections
        )
    }
}

private extension GitManagerDiff {
    struct NumstatSummary {
        let paths: [String]
        let insertions: Int
        let deletions: Int
    }

    static func requireRoot(
        at directory: URL
    ) async throws -> URL {
        let state =
            try await GitManagerRepositoryInspector
                .state(
                    at: directory,
                    fetch: false
                )

        guard let root = state.root else {
            throw GitManagerError.notGitRepository(
                directory.path
            )
        }

        return root
    }

    static func section(
        scope: GitManagerDiffScope,
        request: GitManagerDiffRequest,
        pathspecs: [String],
        at root: URL
    ) async throws -> GitManagerDiffSection {
        let patch =
            try await GitRepo.gitOut(
                root,
                patchArguments(
                    scope: scope,
                    contextLines:
                        request.contextLines,
                    pathspecs: pathspecs
                )
            )

        let numstat =
            try await GitRepo.gitOut(
                root,
                numstatArguments(
                    scope: scope,
                    pathspecs: pathspecs
                )
            )

        let summary = parseNumstat(
            numstat
        )

        let patchData = Data(
            patch.utf8
        )

        let truncated =
            patchData.count
            > request.maxPatchBytes

        let visibleData: Data

        if truncated {
            visibleData = Data(
                patchData.prefix(
                    request.maxPatchBytes
                )
            )
        } else {
            visibleData = patchData
        }

        return .init(
            scope: scope,
            changedPaths:
                summary.paths,
            insertions:
                summary.insertions,
            deletions:
                summary.deletions,
            patch:
                String(
                    decoding:
                        visibleData,
                    as:
                        UTF8.self
                ),
            patchByteCount:
                patchData.count,
            truncated:
                truncated
        )
    }

    static func patchArguments(
        scope: GitManagerDiffScope,
        contextLines: Int,
        pathspecs: [String]
    ) -> [String] {
        var arguments = [
            "diff",
            "--no-ext-diff",
            "--no-color",
            "--no-renames",
            "--unified=\(contextLines)",
        ]

        if scope == .staged {
            arguments.append(
                "--cached"
            )
        }

        arguments.append(
            "--"
        )

        arguments.append(
            contentsOf:
                pathspecs
        )

        return arguments
    }

    static func numstatArguments(
        scope: GitManagerDiffScope,
        pathspecs: [String]
    ) -> [String] {
        var arguments = [
            "diff",
            "--no-ext-diff",
            "--no-renames",
            "--numstat",
        ]

        if scope == .staged {
            arguments.append(
                "--cached"
            )
        }

        arguments.append(
            "--"
        )

        arguments.append(
            contentsOf:
                pathspecs
        )

        return arguments
    }

    static func literalPathspecs(
        _ values: [String]
    ) throws -> [String] {
        try values.map { value in
            let trimmed =
                value.trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

            guard !trimmed.isEmpty,
                  trimmed == value,
                  !value.hasPrefix("/"),
                  !value.contains("\0")
            else {
                throw GitManagerDiffError
                    .invalidPath(
                        value
                    )
            }

            let components =
                value.split(
                    separator: "/",
                    omittingEmptySubsequences:
                        false
                )

            guard !components.contains(
                where: {
                    $0 == ".."
                }
            ) else {
                throw GitManagerDiffError
                    .invalidPath(
                        value
                    )
            }

            return ":(literal)\(value)"
        }
    }

    static func parseNumstat(
        _ output: String
    ) -> NumstatSummary {
        var paths = Set<String>()
        var insertions = 0
        var deletions = 0

        for rawLine in output.split(
            separator: "\n",
            omittingEmptySubsequences: true
        ) {
            let fields = rawLine.split(
                separator: "\t",
                maxSplits: 2,
                omittingEmptySubsequences:
                    false
            )

            guard fields.count == 3 else {
                continue
            }

            let inserted =
                Int(fields[0])
                ?? 0

            let deleted =
                Int(fields[1])
                ?? 0

            let changedPath =
                String(
                    fields[2]
                )

            if !changedPath.isEmpty {
                paths.insert(
                    changedPath
                )
            }

            insertions += inserted
            deletions += deleted
        }

        return .init(
            paths:
                paths.sorted(),
            insertions:
                insertions,
            deletions:
                deletions
        )
    }
}
