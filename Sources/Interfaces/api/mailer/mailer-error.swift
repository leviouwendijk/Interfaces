import Foundation
import plate

public enum MailerAPIError: Error, LocalizedError {
    case missingEnv(String)
    case invalidURL(String)
    case network(Error)
    case invalidEndpoint(route: MailerAPIRoute, endpoint: MailerAPIEndpoint)
    case invalidFormat(original: String)
    case server(status: Int, body: String)

    public var errorDescription: String? {
        switch self {
        case .missingEnv(let key):
            return "Missing environment variable: \(key)."

        case .invalidURL(let url):
            return "Invalid URL: \(url)."

        case .network(let err):
            var r = "Network Error: "
            r.append(err.localizedDescription)
            if let api = err as? APIError {
                r.append("plate API error: \(api.description)")
            }
            return r

        case .invalidEndpoint(let route, let endpoint):
            return "Invalid endpoint for route: route=\(String(describing: route)), endpoint=\(String(describing: endpoint))."

        case .invalidFormat(let original):
            return "Invalid format: \(original)."

        case .server(let status, let body):
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            let preview = trimmed.prefix(500)
            return "Server error (\(status)). Body: \(preview)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .missingEnv:
            return "A required environment variable is not set."
        case .invalidURL:
            return "The URL string could not be parsed."
        case .network:
            return "The request failed before a valid response was received."
        case .invalidEndpoint:
            return "The selected endpoint is incompatible with the route."
        case .invalidFormat:
            return "One or more inputs have the wrong shape or encoding."
        case .server:
            return "The server responded with a non-2xx HTTP status code."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .missingEnv:
            return "Define the variable in your environment or .env and restart."
        case .invalidURL:
            return "Check the domain, path, and query; avoid illegal characters."
        case .network:
            return "Check connectivity and try again; inspect the underlying error."
        case .invalidEndpoint:
            return "Pick a compatible route/endpoint pair."
        case .invalidFormat:
            return "Correct the input or payload format and retry."
        case .server:
            return "Inspect the status and body; check server logs."
        }
    }
}
