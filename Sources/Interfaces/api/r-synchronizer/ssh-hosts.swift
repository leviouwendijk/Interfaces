import Foundation

public enum SSHHosts {
    public static func list(from path: String = "~/.ssh/config") -> [String] {
        let expanded = NSString(string: path).expandingTildeInPath
        guard let content = try? String(contentsOfFile: expanded, encoding: .utf8) else {
            return []
        }

        return content
            .components(separatedBy: .newlines)
            .filter { $0.hasPrefix("Host ") && !$0.contains("*") }
            .map {
                $0.replacingOccurrences(of: "Host ", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
    }
}
