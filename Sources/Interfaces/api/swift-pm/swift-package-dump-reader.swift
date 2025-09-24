import Foundation
import Structures

public enum SwiftPackageDumpReaderError: Error, LocalizedError, Sendable {
    case notJSON(String)
    case invalidPointer(String)
    case typeMismatch(expected: String, actual: String?)

    public var errorDescription: String? {
        switch self {
        case .notJSON(let blob):
            return """
            The blob does not contain a valid JSON object.

            blob: 
            \(blob)
            """
        case .invalidPointer(let p):
            return "Invalid pointer: \(p)"
        case .typeMismatch(let exp, let got):
            return "Type mismatch. Expected: \(exp), got: \(got ?? "nil")"
        }
    }
}

public struct SwiftPackageDumpReader: Sendable {
    public let blob: SwiftPackageDumpBlob
    public let root: Structures.JSONValue

    public init(blob: SwiftPackageDumpBlob) throws {
        let decoder = JSONDecoder()
        guard let parsed = try? decoder.decode(JSONValue.self, from: blob.raw) else {
            throw SwiftPackageDumpReaderError.notJSON((blob.utf8String ?? "failed to get utf8 string from blob"))
        }
        self.blob = blob
        self.root = parsed
    }

    /// Accepts ".a.b.0.c" or "/a/b/0/c".
    @inline(__always)
    private func normalizeToDotPath(_ pointer: String) throws -> String {
        if pointer.isEmpty || pointer == "." || pointer == "/" { return "" }
        if pointer.hasPrefix(".") { return String(pointer.dropFirst()) }
        if pointer.hasPrefix("/") {
            // RFC6901 unescape (~1 -> "/", ~0 -> "~"), then join with "."
            let parts = pointer.dropFirst()
                .split(separator: "/")
                .map { $0.replacingOccurrences(of: "~1", with: "/").replacingOccurrences(of: "~0", with: "~") }
            return parts.joined(separator: ".")
        }
        // treat as dot path by default
        return pointer
    }

    public func value(at pointer: String) throws -> JSONValue {
        let dot = try normalizeToDotPath(pointer)
        return try (dot.isEmpty ? root : root.value(forDotPath: dot))
    }

    public func valueString(_ pointer: String) throws -> String { try value(at: pointer).stringValue }
    public func valueInt(_ pointer: String) throws -> Int { try value(at: pointer).intValue }
    public func valueDouble(_ pointer: String) throws -> Double { try value(at: pointer).doubleValue }
    public func valueBool(_ pointer: String) throws -> Bool { try value(at: pointer).boolValue }
    public func valueArray(_ pointer: String) throws -> [JSONValue] { try value(at: pointer).arrayValue }
    public func valueObject(_ pointer: String) throws -> [String: JSONValue] { try value(at: pointer).objectValue }

    public func decode<T: Decodable>(_ type: T.Type, at pointer: String) throws -> T {
        let sub = try value(at: pointer)
        let data = try JSONEncoder().encode(sub)
        return try JSONDecoder().decode(T.self, from: data)
    }

    public func packageName() -> String? {
        (try? valueString(".name")) ?? (try? valueString("/name"))
    }

    public func allTargets() -> [[String: JSONValue]] {
        (try? valueArray(".targets"))?.compactMap { try? $0.objectValue }
        ?? (try? valueArray("/targets"))?.compactMap { try? $0.objectValue }
        ?? []
    }

    public func allTargetNames() -> [String] {
        allTargets().compactMap { dict in try? dict["name"]?.stringValue }
    }

    public func executableTargetNames() -> [String] {
        allTargets().compactMap { dict in
            guard (try? dict["type"]?.stringValue) == "executable" else { return nil }
            return try? dict["name"]?.stringValue
        }
    }

    public func allProducts() -> [[String: JSONValue]] {
        (try? valueArray(".products"))?.compactMap { try? $0.objectValue }
        ?? (try? valueArray("/products"))?.compactMap { try? $0.objectValue }
        ?? []
    }

    public func allDependencies() -> [[String: JSONValue]] {
        (try? valueArray(".dependencies"))?.compactMap { try? $0.objectValue }
        ?? (try? valueArray("/dependencies"))?.compactMap { try? $0.objectValue }
        ?? []
    }

    public func toolsVersionString() -> String? {
        (try? valueString(".toolsVersion._version"))
        ?? (try? valueString("/toolsVersion/_version"))
    }

    /// e.g. ["macos": "13.0", "ios": "17.0"]
    public func minimumPlatformVersions() -> [String:String] {
        let arr = (try? valueArray(".platforms")) ?? (try? valueArray("/platforms")) ?? []
        var out: [String:String] = [:]
        for item in arr {
            guard
                let obj = try? item.objectValue,
                let name = try? obj["platformName"]?.stringValue,
                let ver  = try? obj["version"]?.stringValue
            else { continue }
            out[name] = ver
        }
        return out
    }
}
