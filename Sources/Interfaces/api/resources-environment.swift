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
    case certification_template = "HONDENMEESTERS_CERTIFICATION_TEMPLATE"

    case quote_default_output = "HONDENMEESTERS_QUOTE_DEFAULT_OUTPUT"

    case levi_logo_circled = "LEVIOUWENDIJK_LOGO_CIRCLED"
    case levi_private_invoice = "LEVIOUWENDIJK_PRIVATE_INVOICE"
    case levi_signature = "LEVIOUWENDIJK_SIGNATURE"
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
