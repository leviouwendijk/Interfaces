import Foundation

public struct PDOKSuggestResponse: Codable, Sendable {
    public let response: PDOKResponse
}

public struct PDOKResponse: Codable, Sendable {
    public let numFound: Int?
    public let docs: [PDOKDoc]?
}

public struct PDOKDoc: Codable, Sendable {
    public let weergavenaam: String?
    // extensible
}
