import Foundation

public enum PostcodeClientError: Error, LocalizedError {
    case invalidInput
    case invalidURL
    case httpError(status: Int)
    case noResults
    case decodeError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidInput: return "Ongeldige invoer (postcode of huisnummer)"
        case .invalidURL:   return "Fout in URL-constructie"
        case .httpError(let status): return "HTTP fout: \(status)"
        case .noResults:    return "Geen resultaten gevonden voor dit adres"
        case .decodeError(let e): return "Decode fout: \(e.localizedDescription)"
        }
    }
}
