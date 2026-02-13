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

// public enum PDFGenerationError: PlateLibraryError, Error, LocalizedError {
//     case htmlFileMissing(URL)
//     case cssFileMissing(URL)
//     case processFailed(exitCode: Int32, output: String)
//     case cannotRunProcess(underlying: Error)
//     case cannotCreateURLFromStringPath(String)
    
//     public var localizedDescription: String {
//         switch self {
//         case .htmlFileMissing(let url):
//             return "HTML file not found at \(url.path)."
//         case .cssFileMissing(let url):
//             return "CSS file not found at \(url.path)."
//         case .processFailed(let code, let output):
//             return "WeasyPrint exited with code \(code). Output:\n\(output)"
//         case .cannotRunProcess(let err):
//             return "Unable to launch WeasyPrint process: \(err.localizedDescription)"
//         case .cannotCreateURLFromStringPath(let path):
//             return "Error in trying to process path-string: \(path)"
//         }
//     }
// }

public enum PDFGenerationError: PlateLibraryError, Error, LocalizedError {
    case htmlFileMissing(URL)
    case cssFileMissing(URL)
    case processFailed(exitCode: Int32, output: String)
    case cannotRunProcess(underlying: Error)
    case cannotCreateURLFromStringPath(String)

    public var errorDescription: String? {
        switch self {
        case .htmlFileMissing(let url):
            return "HTML file not found at \(url.path)."

        case .cssFileMissing(let url):
            return "CSS file not found at \(url.path)."

        case .processFailed(let code, let output):
            return "WeasyPrint exited with code \(code). Output:\n\(output)"

        case .cannotRunProcess(let err):
            return "Unable to launch WeasyPrint process: \(err.localizedDescription)"

        case .cannotCreateURLFromStringPath(let path):
            return "Error processing path string: \(path)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .processFailed:
            return "The WeasyPrint process returned a non-zero exit status."
        case .cannotRunProcess:
            return "The WeasyPrint executable could not be launched."
        case .htmlFileMissing:
            return "The HTML input file does not exist at the resolved path."
        case .cssFileMissing:
            return "The CSS input file does not exist at the resolved path."
        case .cannotCreateURLFromStringPath:
            return "The destination path could not be converted into a valid file URL."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .cannotRunProcess:
            return "Verify the weasyprint binary path is correct and executable, and that the app has permission to run it."
        case .processFailed:
            return "Check the WeasyPrint output for missing fonts/resources or invalid CSS/HTML."
        case .htmlFileMissing, .cssFileMissing:
            return "Verify the file is created successfully and the path is correct."
        case .cannotCreateURLFromStringPath:
            return "Pass an absolute path to a writable location (e.g. ~/Desktop)."
        }
    }
}
