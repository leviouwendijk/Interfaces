import Foundation
import plate

public enum ResourcesEnvironmentKey: String {
    case h_logo = "HONDENMEESTERS_H_LOGO"
    case quote_template = "HONDENMEESTERS_QUOTE_TEMPLATE"
}

public struct ResourcesEnvironment {
    public static func require(_ key: ResourcesEnvironmentKey) throws -> String {
        guard let raw = ProcessInfo.processInfo.environment[key.rawValue],
            !raw.isEmpty
        else {
            throw MailerAPIError.missingEnv(key.rawValue)
        }
        return raw
    }

    public static func optional(_ key: ResourcesEnvironmentKey) -> String? {
        ProcessInfo.processInfo.environment[key.rawValue]
    }
}
