import Foundation

public struct SwiftPackageDumpBlob: Sendable, Hashable {
    public let raw: Data

    @inlinable
    public init(raw: Data) {
        self.raw = raw
    }

    @inlinable
    public init(jsonUTF8: String) {
        self.raw = Data(jsonUTF8.utf8)
    }

    @inlinable
    public init(contentsOf url: URL) throws {
        self.raw = try Data(contentsOf: url, options: .mappedIfSafe)
    }

    @inlinable
    public var utf8String: String? {
        String(data: raw, encoding: .utf8)
    }
}
