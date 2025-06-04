import Foundation

public enum NumbersParserError: Error {
    case missingEnv(String)
    case invalidURL(String)
    case missingHeaders(file: String)
    case noRows(file: String)
    case invalidJSON(file: String)
    case writeFailed(file: String, underlying: Error)
    case pdfDocumentCreationFailed(String)
    case cannotGenerateOutput(String)
    case pageNotFound(Int)
    case fileNotFound(String)
}
