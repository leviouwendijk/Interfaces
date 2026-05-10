import Foundation

extension RSynchronizer {
    public struct Summary: Sendable {
        public let sentBytes: Int?
        public let receivedBytes: Int?
        public let totalSizeBytes: Int?
        public let speedup: Double?

        public init(
            sentBytes: Int? = nil,
            receivedBytes: Int? = nil,
            totalSizeBytes: Int? = nil,
            speedup: Double? = nil
        ) {
            self.sentBytes = sentBytes
            self.receivedBytes = receivedBytes
            self.totalSizeBytes = totalSizeBytes
            self.speedup = speedup
        }
    }

    public static func parseSummary(
        from text: String
    ) -> Summary {
        Summary.Parser.parse(
            text
        )
    }
}

private extension RSynchronizer.Summary {
    enum Parser {
        static func parse(
            _ text: String
        ) -> RSynchronizer.Summary {
            var sentBytes: Int?
            var receivedBytes: Int?
            var totalSizeBytes: Int?
            var speedup: Double?

            for line in text.split(
                separator: "\n",
                omittingEmptySubsequences: false
            ) {
                let words = line.split {
                    $0 == " " || $0 == "\t"
                }

                guard !words.isEmpty else {
                    continue
                }

                for index in words.indices {
                    if words[index] == "sent",
                       let valueIndex = words.index(
                           index,
                           offsetBy: 1,
                           limitedBy: words.index(before: words.endIndex)
                       ) {
                        sentBytes = integer(
                            words[valueIndex]
                        )
                    }

                    if words[index] == "received",
                       let valueIndex = words.index(
                           index,
                           offsetBy: 1,
                           limitedBy: words.index(before: words.endIndex)
                       ) {
                        receivedBytes = integer(
                            words[valueIndex]
                        )
                    }

                    if words[index] == "total",
                       hasWord(
                           "size",
                           after: index,
                           offset: 1,
                           in: words
                       ),
                       hasWord(
                           "is",
                           after: index,
                           offset: 2,
                           in: words
                       ),
                       let value = word(
                           after: index,
                           offset: 3,
                           in: words
                       ) {
                        totalSizeBytes = integer(
                            value
                        )
                    }

                    if words[index] == "speedup",
                       hasWord(
                           "is",
                           after: index,
                           offset: 1,
                           in: words
                       ),
                       let value = word(
                           after: index,
                           offset: 2,
                           in: words
                       ) {
                        speedup = double(
                            value
                        )
                    }
                }
            }

            return .init(
                sentBytes: sentBytes,
                receivedBytes: receivedBytes,
                totalSizeBytes: totalSizeBytes,
                speedup: speedup
            )
        }

        static func hasWord(
            _ expected: String,
            after index: Array<Substring>.Index,
            offset: Int,
            in words: [Substring]
        ) -> Bool {
            guard
                let value = word(
                    after: index,
                    offset: offset,
                    in: words
                )
            else {
                return false
            }

            return value == expected
        }

        static func word(
            after index: Array<Substring>.Index,
            offset: Int,
            in words: [Substring]
        ) -> Substring? {
            words.index(
                index,
                offsetBy: offset,
                limitedBy: words.index(before: words.endIndex)
            )
            .map {
                words[$0]
            }
        }

        static func integer(
            _ value: Substring
        ) -> Int? {
            Int(
                String(value).filter {
                    $0 != ","
                }
            )
        }

        static func double(
            _ value: Substring
        ) -> Double? {
            Double(
                String(value).filter {
                    $0 != ","
                }
            )
        }
    }
}
