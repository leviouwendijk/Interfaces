import Foundation

public enum DocumentDrawerError: Error, LocalizedError, Sendable {
    case cannotCreateDocumentCGContext
    case missingKeyInValuesOrder(key: String)

    public var errorDescription: String? {
        switch self {
        case .cannotCreateDocumentCGContext:
            return "Cannot create document's CGContext for drawing PDF"
        case .missingKeyInValuesOrder(let key):
            return "Draw value identifiers do not contain key specified in order \(key)"

        }
    }
}
