import Foundation

public struct GitManagerChangeSummary: Sendable, Codable, Hashable {
    public var modified: [String]
    public var deleted: [String]
    public var added: [String]
    public var renamed: [String]
    public var untracked: [String]

    public var trackedCount: Int {
        modified.count
            + deleted.count
            + added.count
            + renamed.count
    }

    public var untrackedCount: Int {
        untracked.count
    }

    public var totalCount: Int {
        trackedCount + untrackedCount
    }

    public var hasChanges: Bool {
        totalCount > 0
    }

    public init(
        modified: [String] = [],
        deleted: [String] = [],
        added: [String] = [],
        renamed: [String] = [],
        untracked: [String] = []
    ) {
        self.modified = modified
        self.deleted = deleted
        self.added = added
        self.renamed = renamed
        self.untracked = untracked
    }

    public init(
        porcelain: String
    ) {
        self.init()

        for rawLine in porcelain.split(
            separator: "\n",
            omittingEmptySubsequences: true
        ) {
            let line = String(
                rawLine
            )

            guard line.count >= 3 else {
                continue
            }

            let status = String(
                line.prefix(2)
            )

            let pathStart = line.index(
                line.startIndex,
                offsetBy: 3
            )

            let path = String(
                line[pathStart...]
            )

            if status == "??" {
                untracked.append(
                    path
                )

                continue
            }

            if status.contains("R") {
                renamed.append(
                    path
                )

                continue
            }

            if status.contains("A") {
                added.append(
                    path
                )

                continue
            }

            if status.contains("D") {
                deleted.append(
                    path
                )

                continue
            }

            if status.contains("M") {
                modified.append(
                    path
                )

                continue
            }

            modified.append(
                path
            )
        }
    }
}
