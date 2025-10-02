import Foundation

public struct PDOKSuggestResponse: Codable {
    public let response: PDOKResponse
}

public struct PDOKResponse: Codable {
    public let numFound: Int?
    public let docs: [PDOKDoc]?
}

public struct PDOKDoc: Codable {
    public let weergavenaam: String?
    // extensible
}
