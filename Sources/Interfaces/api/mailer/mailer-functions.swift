import Foundation

public struct MailerAPIClientVariable {
    public let name: String
    public let dog: String
}

public func splitClientDog(from raw: String) throws -> MailerAPIClientVariable {
    let parts = raw
        .split(separator: "|", omittingEmptySubsequences: false)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

    guard parts.count == 2 else {
        throw MailerAPIError.invalidFormat(original: raw)
    }

    return MailerAPIClientVariable(name: parts[0], dog: parts[1])
}
