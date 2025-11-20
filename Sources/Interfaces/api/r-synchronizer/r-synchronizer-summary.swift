import Foundation

extension RSynchronizer {
    public struct Summary: Sendable {
        public let sentBytes: Int?
        public let receivedBytes: Int?
        public let totalSizeBytes: Int?
        public let speedup: Double?
    }

    public static func parseSummary(from text: String) -> Summary {
        func match(_ pattern: String) -> [String]? {
            let re = try? NSRegularExpression(pattern: pattern)
            guard let re else { return nil }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let m = re.matches(in: text, range: range).last else { return nil }
            return (0..<m.numberOfRanges).compactMap { i in
                guard let r = Range(m.range(at: i), in: text) else { return nil }
                return String(text[r])
            }
        }

        let sentRecv = match(#"sent\s+([0-9,]+)\s+bytes\s+received\s+([0-9,]+)\s+bytes"#)
        let total    = match(#"total size is\s+([0-9,]+)"#)
        let speed    = match(#"speedup is\s+([0-9.]+)"#)

        func toInt(_ s: String?) -> Int? {
            s.flatMap { Int($0.replacingOccurrences(of: ",", with: "")) }
        }
        func toDouble(_ s: String?) -> Double? { s.flatMap(Double.init) }

        return Summary(
            sentBytes: toInt(sentRecv?.dropFirst().first),
            receivedBytes: toInt(sentRecv?.dropFirst().dropFirst().first),
            totalSizeBytes: toInt(total?.dropFirst().first),
            speedup: toDouble(speed?.dropFirst().first)
        )
    }
}
