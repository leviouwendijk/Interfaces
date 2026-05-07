import Foundation

public struct GitManagerSBMMetadata: Sendable, Codable, Hashable {
    public let binary: String
    public let projectRootURL: URL

    public init(
        binary: String,
        projectRootURL: URL
    ) {
        self.binary = binary
        self.projectRootURL = projectRootURL
    }
}

public enum GitManagerSBMMetadataStore {
    public static func repositories(
        directory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "sbm-bin",
                isDirectory: true
            )
    ) throws -> [GitManagerSBMMetadata] {
        guard FileManager.default.fileExists(
            atPath: directory.path
        ) else {
            throw GitManagerError.missingDirectory(
                directory.path
            )
        }

        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )

        return files
            .filter {
                $0.lastPathComponent.hasSuffix(
                    ".metadata"
                )
            }
            .compactMap { file in
                guard let projectRoot = try? projectRoot(
                    from: file
                ) else {
                    return nil
                }

                let binary = String(
                    file.lastPathComponent.dropLast(
                        ".metadata".count
                    )
                )

                return GitManagerSBMMetadata(
                    binary: binary,
                    projectRootURL: URL(
                        fileURLWithPath: projectRoot
                    )
                )
            }
            .sorted {
                $0.projectRootURL.path < $1.projectRootURL.path
            }
    }
}

private extension GitManagerSBMMetadataStore {
    static func projectRoot(
        from file: URL
    ) throws -> String? {
        let contents = try String(
            contentsOf: file,
            encoding: .utf8
        )

        for line in contents.split(
            separator: "\n"
        ) {
            let parts = line.split(
                separator: "=",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )

            guard parts.count == 2,
                  parts[0] == "ProjectRootPath"
            else {
                continue
            }

            return String(
                parts[1]
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }

        return nil
    }
}
