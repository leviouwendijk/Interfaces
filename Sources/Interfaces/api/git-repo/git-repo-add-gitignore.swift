import Foundation

extension GitRepo {
    public enum GitignoreUpdateResult {
        case appended
        case alreadyPresent
        case notFound
    }

    @discardableResult
    public static func appending(
        ignorable: [String] = ["compiled.pkl", "/compiled.pkl", "**/compiled.pkl"],
        to file: String = ".gitignore",
        in dir: URL
    ) throws -> (GitignoreUpdateResult, String) {
        let gi = dir.appendingPathComponent(file, isDirectory: false)

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: gi.path, isDirectory: &isDir), !isDir.boolValue else {
            return (.notFound, gi.path)
        }

        let data = try Data(contentsOf: gi)
        let contents = String(decoding: data, as: UTF8.self)
        let lines = contents.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }

        let wanted = Set(ignorable)
        let already = lines.contains { wanted.contains($0) }
        if already { return (.alreadyPresent, "") }

        let fh = try FileHandle(forWritingTo: gi)
        try fh.seekToEnd()

        if !contents.isEmpty, !contents.hasSuffix("\n") && !contents.hasSuffix("\r\n") {
            try fh.write(contentsOf: Data("\n".utf8))
        }

        var block = """
        # auto-added ignorables:

        """

        for i in ignorable {
            block.append(i)
            block.append("\n")
        }
        block.append("\n")

        try fh.write(contentsOf: Data(block.utf8))
        try fh.close()

        return (.appended, block)
    }
}
