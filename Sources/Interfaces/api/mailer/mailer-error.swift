import Foundation

public enum MailerAPIError: Error {
    case missingEnv(String)
    case invalidURL(String)
    case network(Error)
    case invalidEndpoint(route: MailerAPIRoute, endpoint: MailerAPIEndpoint)
    case invalidFormat(original: String)
}
