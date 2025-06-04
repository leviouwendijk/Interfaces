import Foundation
import plate

public enum ResourceError: PlateLibraryError, LocalizedError {
    case notFound(resourceName: String, resourceType: String)
    case invalidPath(path: String)
    
    public var errorDescription: String? {
        switch self {
        case .notFound(let name, let type):
            return "Unable to find resource “\(name).\(type)” in bundle."
        case .invalidPath(let path):
            return "invalid path provided: \(path)"
        }
    }
}

public enum FileProcessingError: PlateLibraryError {
    case cannotReadHTML(URL, underlying: Error)
    case cannotWriteHTML(URL, underlying: Error)
    case cannotWriteCSS(URL, underlying: Error)
    
    var underlyingError: Error? {
        switch self {
        case .cannotReadHTML(_, let err), .cannotWriteHTML(_, let err), .cannotWriteCSS(_, let err):
            return err
        }
    }
}

public enum PDFGenerationError: PlateLibraryError {
    case htmlFileMissing(URL)
    case cssFileMissing(URL)
    case processFailed(exitCode: Int32, output: String)
    case cannotRunProcess(underlying: Error)
    
    var localizedDescription: String {
        switch self {
        case .htmlFileMissing(let url):
            return "HTML file not found at \(url.path)."
        case .cssFileMissing(let url):
            return "CSS file not found at \(url.path)."
        case .processFailed(let code, let output):
            return "WeasyPrint exited with code \(code). Output:\n\(output)"
        case .cannotRunProcess(let err):
            return "Unable to launch WeasyPrint process: \(err.localizedDescription)"
        }
    }
}
