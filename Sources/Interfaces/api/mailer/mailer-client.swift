import Foundation
import plate

public protocol MailerAPIPayload {
    associatedtype Variables: Encodable

    var route:     MailerAPIRoute { get }
    var endpoint:  MailerAPIEndpoint { get }
    var content:   MailerAPIRequestContent<Variables> { get }
}

public struct MailerAPIClient {
    public let apiKey: String
    public let baseURL: URL

    public static var environmentApiKey: String {
        let value = environment(MailerAPIEnvironmentKey.apikey.rawValue)
        guard !value.isEmpty else {
            fatalError("Invalid value for \"\(MailerAPIEnvironmentKey.apikey.rawValue)\": \(value)")
        }
        return value
    }

    public static var environmentBaseURL: URL {
        let value = environment(MailerAPIEnvironmentKey.apiURL.rawValue)
        guard let url = URL(string: value) else {
            fatalError("Invalid value for \"\(MailerAPIEnvironmentKey.apiURL.rawValue)\": \(value)")
        }
        return url
    }

    public init(
        apiKey: String = environmentApiKey, 
        baseURL: URL = MailerAPIClient.environmentBaseURL
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    public func send<P: MailerAPIPayload>(
        _ payload: P,
        headers: [String:String] = [:],
        completion: @escaping @Sendable (Result<Data, MailerAPIError>) -> Void
    ) {
        do {
            let path = try MailerAPIPath(route: payload.route, endpoint: payload.endpoint)
            let url  = try path.url(baseURL: baseURL)

            // 3️⃣ JSON‐encode the payload’s content
            let jsonData = try JSONEncoder().encode(payload.content)

            // 4️⃣ Prepare headers
            var allHeaders = headers
            allHeaders["Content-Type"] = "application/json"

            let request = NetworkRequest(
                url: url,
                method: .post,
                auth: .apikey(value: apiKey),
                headers: allHeaders,
                body: jsonData,
                log: true
            )

            request.executeAPI { result in
                switch result {
                case .success(let data):
                    completion(.success(data))

                case .failure(let underlyingError):
                    // Wrap any network‐level error
                    completion(.failure(.network(underlyingError)))
                }
            }

        } catch let apiError as MailerAPIError {
            // Any of our custom errors
            completion(.failure(apiError))

        } catch {
            // Fallback: wrap unknown errors as `.network`
            completion(.failure(.network(error)))
        }
    }
}
