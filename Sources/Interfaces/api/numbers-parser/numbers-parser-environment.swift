import Foundation

public enum NumbersParserEnvironmentKey: String {
    case source = "NUMBERS_SOURCE"
    case destination = "NUMBERS_DESTINATION"
    case target = "NUMBERS_TARGET"
    case parsed = "NUMBERS_PARSED"
    case reparsed = "NUMBERS_REPARSED"
    case invoiceRaw = "NUMBERS_INVOICE_RAW"
    case invoice = "NUMBERS_INVOICE_OUT"
    case sheet = "NUMBERS_SHEET"
    case table = "NUMBERS_TABLE"
    case row = "NUMBERS_ROW"
    case column = "NUMBERS_COLUMN"
    case contacts = "NUMBERS_CONTACTS"
}

public struct NumbersParserEnvironment {
    public static func require(_ key: NumbersParserEnvironmentKey) throws -> String {
        guard let raw = ProcessInfo.processInfo.environment[key.rawValue],
            !raw.isEmpty
        else {
            throw NumbersParserError.missingEnv(key.rawValue)
        }
        return raw
    }

    public static func optional(_ key: NumbersParserEnvironmentKey) -> String? {
        ProcessInfo.processInfo.environment[key.rawValue]
    }
}
