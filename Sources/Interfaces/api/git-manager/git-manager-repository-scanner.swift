import Foundation

public enum GitManagerRepositoryScanner {
    public static func repositories(
        under root: URL,
        maxDepth: Int = 4
    ) throws -> [URL] {
        guard FileManager.default.fileExists(
            atPath: root.path
        ) else {
            throw GitManagerError.missingDirectory(
                root.path
            )
        }

        var result: [URL] = []

        try scan(
            root,
            depth: 0,
            maxDepth: maxDepth,
            result: &result
        )

        return result.sorted {
            $0.path < $1.path
        }
    }
}

private extension GitManagerRepositoryScanner {
    static func scan(
        _ directory: URL,
        depth: Int,
        maxDepth: Int,
        result: inout [URL]
    ) throws {
        guard depth <= maxDepth else {
            return
        }

        let gitDirectory = directory.appendingPathComponent(
            ".git",
            isDirectory: true
        )

        if FileManager.default.fileExists(
            atPath: gitDirectory.path
        ) {
            result.append(
                directory
            )

            return
        }

        let children = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ],
            options: [
                .skipsPackageDescendants,
                .skipsHiddenFiles,
            ]
        )

        for child in children {
            let values = try child.resourceValues(
                forKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey,
                ]
            )

            guard values.isDirectory == true,
                  values.isSymbolicLink != true,
                  !ignoredDirectoryNames.contains(
                    child.lastPathComponent
                  )
            else {
                continue
            }

            try scan(
                child,
                depth: depth + 1,
                maxDepth: maxDepth,
                result: &result
            )
        }
    }

    static let ignoredDirectoryNames: Set<String> = [
        ".build",
        ".git",
        ".swiftpm",
        "DerivedData",
        "Library",
        "node_modules",
    ]
}
