import Foundation
import Readers
import Writers

/// The entries `gm init` writes to a new .gitignore and `gm ignore` merges into an existing one.
enum GitignoreDefaults {
    static let entries = [
        ".DS_Store",
        ".build/",
        ".index-build/",
        ".swiftpm/",
        "DerivedData/",
        "*.xcodeproj/project.xcworkspace/xcuserdata/",
        "*.xcodeproj/xcuserdata/",
        "*.xcworkspace/xcuserdata/",
        "xcuserdata/",
        ".env",
        ".env.*",
        ".env/*",
        ".claude/",
        "**/.testflows/*",
        "!**/.testflows/snapshots/",
        "compiled.pkl",
        "/compiled.pkl",
        "**/compiled.pkl"
    ]

    enum MergeResult {
        case created(Int)
        case merged([String])
        case unchanged
    }

    static func file(in directory: URL) -> URL {
        directory.appendingPathComponent(".gitignore")
    }

    static func exists(in directory: URL) throws -> Bool {
        try read(in: directory).existed
    }

    /// Default entries the .gitignore does not list yet, in default order.
    static func missing(in directory: URL) throws -> [String] {
        let existing = Set(
            try read(in: directory).text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        return entries.filter { !existing.contains($0) }
    }

    static func merge(in directory: URL) throws -> MergeResult {
        let current = try read(in: directory)
        guard current.existed else {
            try write(entries.joined(separator: "\n") + "\n", in: directory)
            return .created(entries.count)
        }

        let missing = try missing(in: directory)
        guard !missing.isEmpty else { return .unchanged }

        var updated = current.text
        if !updated.isEmpty && !updated.hasSuffix("\n") { updated += "\n" }
        if !updated.isEmpty && !updated.hasSuffix("\n\n") { updated += "\n" }
        updated += "# gm defaults\n" + missing.joined(separator: "\n") + "\n"
        try write(updated, in: directory)
        return .merged(missing)
    }

    private static func read(in directory: URL) throws -> TextReadResult {
        try TextFileReader(file(in: directory)).read(options: .init(missingFilePolicy: .returnEmpty))
    }

    private static func write(_ text: String, in directory: URL) throws {
        try FileWriter(file(in: directory)).write(text, options: .overwriteWithoutBackup)
    }
}
