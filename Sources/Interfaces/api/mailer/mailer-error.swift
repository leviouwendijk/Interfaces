import Foundation

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
            return String(
                format: NSLocalizedString(
                    "MailerAPIError.missingEnv",
                    comment: "Environment variable missing (formatted with key)"
                ),
                key
            )

        case .invalidURL(let url):
            return String(
                format: NSLocalizedString(
                    "MailerAPIError.invalidURL",
                    comment: "Invalid URL (formatted with url)"
                ),
                url
            )

        case .network(let err):
            return String(
                format: NSLocalizedString(
                    "MailerAPIError.network",
                    comment: "Network error (formatted with underlying error description)"
                ),
                err.localizedDescription
            )

        case .invalidEndpoint(let route, let endpoint):
            return String(
                format: NSLocalizedString(
                    "MailerAPIError.invalidEndpoint",
                    comment: "Invalid endpoint for route (formatted with route, endpoint)"
                ),
                String(describing: route),
                String(describing: endpoint)
            )

        case .invalidFormat(let original):
            return String(
                format: NSLocalizedString(
                    "MailerAPIError.invalidFormat",
                    comment: "Invalid format (formatted with original value)"
                ),
                original
            )

        case .server(let status, let body):
            return String(
                format: NSLocalizedString(
                    "MailerAPIError.server",
                    comment: "Server returned HTTP error (formatted with status code and body)"
                ),
                status,
                body
            )
        }
    }

    public var failureReason: String? {
        switch self {
        case .missingEnv:
            return NSLocalizedString(
                "MailerAPIError.failureReason.missingEnv",
                comment: "Reason for missing environment variable"
            )

        case .invalidURL:
            return NSLocalizedString(
                "MailerAPIError.failureReason.invalidURL",
                comment: "Reason for invalid URL"
            )

        case .network:
            return NSLocalizedString(
                "MailerAPIError.failureReason.network",
                comment: "Reason for network error"
            )

        case .invalidEndpoint:
            return NSLocalizedString(
                "MailerAPIError.failureReason.invalidEndpoint",
                comment: "Reason for invalid endpoint"
            )

        case .invalidFormat:
            return NSLocalizedString(
                "MailerAPIError.failureReason.invalidFormat",
                comment: "Reason for invalid format"
            )

        case .server:
            return NSLocalizedString(
                "MailerAPIError.failureReason.server",
                comment: "Reason for server error"
            )
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .missingEnv:
            return NSLocalizedString(
                "MailerAPIError.recoverySuggestion.missingEnv",
                comment: "Suggestion for missing env"
            )

        case .invalidURL:
            return NSLocalizedString(
                "MailerAPIError.recoverySuggestion.invalidURL",
                comment: "Suggestion for invalid URL"
            )

        case .network:
            return NSLocalizedString(
                "MailerAPIError.recoverySuggestion.network",
                comment: "Suggestion for network error"
            )

        case .invalidEndpoint:
            return NSLocalizedString(
                "MailerAPIError.recoverySuggestion.invalidEndpoint",
                comment: "Suggestion for invalid endpoint"
            )

        case .invalidFormat:
            return NSLocalizedString(
                "MailerAPIError.recoverySuggestion.invalidFormat",
                comment: "Suggestion for invalid format"
            )

        case .server:
            return NSLocalizedString(
                "MailerAPIError.recoverySuggestion.server",
                comment: "Suggestion for server error"
            )
        }
    }
}
