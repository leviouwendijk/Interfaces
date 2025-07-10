import Foundation

public enum JSONValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    public enum JSONValueError: Error {
        case typeMismatch(expected: String, actual: JSONValue)
        case invalidCast(description: String)
        case pathNotFound(path: String)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            if d == Double(Int(d)) {
                self = .int(Int(d))
            } else {
                self = .double(d)
            }
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a valid JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let b):
            try container.encode(b)
        case .int(let i):
            try container.encode(i)
        case .double(let d):
            try container.encode(d)
        case .string(let s):
            try container.encode(s)
        case .array(let a):
            try container.encode(a)
        case .object(let o):
            try container.encode(o)
        }
    }

    public func value(forDotPath path: String) throws -> JSONValue {
        let components = path.split(separator: ".").map(String.init)
        return try value(forPathComponents: components, fullPath: path)
    }

    private func value(forPathComponents components: [String], fullPath: String) throws -> JSONValue {
        guard let first = components.first else { return self }
        switch self {
        case .object(let dict):
            if let next = dict[first] {
                return try next.value(forPathComponents: Array(components.dropFirst()), fullPath: fullPath)
            }
        case .array(let arr):
            if let idx = Int(first), arr.indices.contains(idx) {
                return try arr[idx].value(forPathComponents: Array(components.dropFirst()), fullPath: fullPath)
            }
        default:
            break
        }
        throw JSONValueError.pathNotFound(path: fullPath)
    }

    public var stringValue: String {
        get throws {
            switch self {
            case .string(let s): return s
            case .int(let i): return String(i)
            case .double(let d): return String(d)
            case .bool(let b): return String(b)
            default: throw JSONValueError.typeMismatch(expected: "String/Int/Double/Bool", actual: self)
            }
        }
    }

    public var intValue: Int {
        get throws {
            switch self {
            case .int(let i): return i
            case .string(let s):
                if let val = Int(s) { return val }
                throw JSONValueError.invalidCast(description: "Cannot convert string '\(s)' to Int")
            case .double(let d): return Int(d)
            case .bool(let b): return b ? 1 : 0
            default: throw JSONValueError.typeMismatch(expected: "Int/String/Double/Bool", actual: self)
            }
        }
    }

    public var doubleValue: Double {
        get throws {
            switch self {
            case .double(let d): return d
            case .int(let i): return Double(i)
            case .string(let s):
                if let val = Double(s) { return val }
                throw JSONValueError.invalidCast(description: "Cannot convert string '\(s)' to Double")
            case .bool(let b): return b ? 1.0 : 0.0
            default: throw JSONValueError.typeMismatch(expected: "Double/Int/String/Bool", actual: self)
            }
        }
    }

    public var boolValue: Bool {
        get throws {
            switch self {
            case .bool(let b): return b
            case .string(let s):
                let lower = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if lower == "true" || lower == "1" { return true }
                if lower == "false" || lower == "0" { return false }
                throw JSONValueError.invalidCast(description: "Cannot convert string '\(s)' to Bool")
            case .int(let i): return i != 0
            case .double(let d): return d != 0.0
            default: throw JSONValueError.typeMismatch(expected: "Bool/String/Int/Double", actual: self)
            }
        }
    }

    public var arrayValue: [JSONValue] {
        get throws {
            if case .array(let arr) = self { return arr }
            throw JSONValueError.typeMismatch(expected: "Array", actual: self)
        }
    }

    public var objectValue: [String: JSONValue] {
        get throws {
            if case .object(let dict) = self { return dict }
            throw JSONValueError.typeMismatch(expected: "Object", actual: self)
        }
    }
}
