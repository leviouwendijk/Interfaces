import Foundation
import plate

public enum ResourcesEnvironmentError: Error, LocalizedError {
    case missingEnv(String)
    case invalidURL(String)

    public var errorDescription: String? {
        switch self {
        case .missingEnv(let key):
            return "Required environment variable '\(key)' is not set or is empty."
        case .invalidURL(let path):
            return "The value '\(path)' is not a valid file path or URL."
        }
    }
}

public enum ResourcesEnvironmentKey: String {
    case h_logo = "HONDENMEESTERS_H_LOGO"
    case quote_template = "HONDENMEESTERS_QUOTE_TEMPLATE"
    case invoice_template = "HONDENMEESTERS_INVOICE_TEMPLATE"
}

public struct ResourcesEnvironment {
    public static func require(_ key: ResourcesEnvironmentKey) throws -> String {
        guard let raw = ProcessInfo.processInfo.environment[key.rawValue],
            !raw.isEmpty
        else {
            throw ResourcesEnvironmentError.missingEnv(key.rawValue)
        }
        return raw
    }

    public static func optional(_ key: ResourcesEnvironmentKey) -> String? {
        ProcessInfo.processInfo.environment[key.rawValue]
    }
}
