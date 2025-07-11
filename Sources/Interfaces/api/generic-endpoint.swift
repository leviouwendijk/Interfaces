import Foundation
// struct Endpoint = -> [PathElement]

public enum APIProtocol: String, Sendable {
    case http
    case https

    public var urlPrefix: String {
        return "\(self.rawValue)://"
    }
}
public enum EndpointError: Error {
    case elementsCannotBeEmpty
}

public struct Endpoint: Sendable {
    public let elements: [String]

    public var request: String {
        return "/" + elements.joined(separator: "/")
    }
    
    public init(
        elements: [String]
    ) throws {
        guard !elements.isEmpty else {
            throw EndpointError.elementsCannotBeEmpty
        }
        self.elements = elements
    }
}

public struct Route: Sendable {
    public let apiProtocol: APIProtocol
    public let domain: String
    public let endpoints: [Endpoint]

    public var urls: [String] {
        var r = [String]()
        for e in endpoints {
            let str = apiProtocol.urlPrefix + domain + e.request
            r.append(str)
        }
        return r
    }
    
    public init(
        apiProtocol: APIProtocol = .https,
        domain: String,
        endpoints: [Endpoint]
    ) throws {
        guard !endpoints.isEmpty else {
            throw EndpointError.elementsCannotBeEmpty
        }
        self.apiProtocol = apiProtocol

        self.domain = domain
        .strippingTrailingSlashes()
        .strippingDomainProtocol()

        self.endpoints = endpoints
    }
}
