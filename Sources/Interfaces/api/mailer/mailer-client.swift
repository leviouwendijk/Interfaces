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

            // let jsonData = try JSONEncoder().encode(payload.content)
            // surface a re-caught error
            let jsonData: Data
            do {
                jsonData = try JSONEncoder().encode(payload.content)
            } catch {
                return completion(.failure(.invalidFormat(original: "JSON encode failed: \(error)")))
            }

            var allHeaders = headers
            allHeaders["Content-Type"] = "application/json"
            allHeaders["Accept"]       = "application/json"

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

                case .failure(let underlying):
                    let ns = underlying as NSError
                    if let status = ns.userInfo["statusCode"] as? Int {
                        let bodyText: String = {
                            if let d = ns.userInfo["responseBody"] as? Data {
                                return String(data: d, encoding: .utf8) ?? "<non-utf8 body>"
                            }
                            if let s = ns.userInfo["responseBody"] as? String { return s }
                            return "<no-body>"
                        }()
                        completion(.failure(.server(status: status, body: bodyText)))
                    } else {
                        completion(.failure(.network(underlying)))
                    }
                }
            }
        } catch let apiError as MailerAPIError {
            completion(.failure(apiError))
        } catch {
            completion(.failure(.network(error)))
        }
    }
}
