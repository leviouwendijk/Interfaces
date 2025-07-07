import Foundation
import plate

public enum MailerAPIAlias: String, CaseIterable, RawRepresentable, Sendable {
    case betalingen
    case bevestigingen
    case offertes
    case relaties
    case support
    case intern

    fileprivate static let routeMap: [MailerAPIRoute: MailerAPIAlias] = [
        .invoice:     .betalingen,
        .appointment: .bevestigingen,
        .quote:       .offertes,
        .lead:        .relaties,
        .service:     .relaties,
        .resolution:  .relaties,
        .affiliate:   .relaties,
        .custom:      .relaties,
        .template:    .intern
    ]
}

public enum MailerAPIRoute: String, CaseIterable, RawRepresentable, Sendable {
    case quote
    case lead
    case appointment
    case affiliate
    case service
    case invoice
    case resolution
    case custom
    case template

    public func alias() -> String {
        MailerAPIAlias
        .routeMap[self]?.rawValue ?? "relaties"
    }

    public var endpointsRequiringAvailability: Set<MailerAPIEndpoint> {
        switch self {
            case .lead:       return [.confirmation, .check, .follow]
            // case .service:    return [.follow]
            default:          return []
        }
    }

    public var validEndpoints: [MailerAPIEndpoint] {
        MailerAPIPath.endpoints(for: self)
    }

    public func viewableString() -> String {
        return self.rawValue.viewableEndpointString()
    }
}

public enum MailerAPIEndpoint: String, CaseIterable, RawRepresentable, Sendable {
    case confirmation
    case issue
    case issueSimple = "issue/simple"
    case follow
    case expired
    case onboarding
    case review
    case check
    case wrongPhone = "wrong/phone"
    case food
    case fetch
    // case templateFetch  = "template/fetch"
    case messageSend    = "message/send"
    case demo

    public func viewableString() -> String {
        return self.rawValue.viewableEndpointString()
    }
}

public struct MailerAPIPath {
    public let route:    MailerAPIRoute
    public let endpoint: MailerAPIEndpoint

    public static func defaultBaseURLString() throws -> String {
        try MailerAPIRequestDefaults.defaultBaseURL()
    }

    public static func defaultBaseURL() throws -> URL {
        let base = try defaultBaseURLString()
        guard let url = URL(string: base) else {
            throw MailerAPIError.invalidURL(base)
        }
        return url
    }

    private static let validMap: [MailerAPIRoute:Set<MailerAPIEndpoint>] = [
        .invoice:    [.issue, .expired, .issueSimple],
        .appointment:[.confirmation],
        .quote:      [.issue, .follow],
        .lead:       [.confirmation, .follow, .check, .wrongPhone],
        .service:    [.onboarding, .follow, .demo],
        .resolution: [.review, .follow],
        .affiliate:  [.food],
        .custom:     [.messageSend],
        .template:   [.fetch]
    ]

    public init(
        route: MailerAPIRoute,
        endpoint: MailerAPIEndpoint
    ) throws {
        guard
          let allowed = MailerAPIPath.validMap[route],
          allowed.contains(endpoint)
        else {
          throw MailerAPIError.invalidEndpoint(route: route, endpoint: endpoint)
        }
        self.route = route
        self.endpoint = endpoint
    }

    public func url(baseURL: URL) throws -> URL {
        let str = "\(baseURL.absoluteString)/\(route.rawValue)/\(endpoint.rawValue)"
        guard let url = URL(string: str) else {
            throw MailerAPIError.invalidURL(str)
        }
        return url
    }

    public func url() throws -> URL {
        try url(baseURL: Self.defaultBaseURL())
    }

    public func string(baseURL: String) -> String {
        "\(baseURL)/\(route.rawValue)/\(endpoint.rawValue)"
    }

    public func string() throws -> String {
        let base = try Self.defaultBaseURLString()
        return string(baseURL: base)
    }

    public static func endpoints(for route: MailerAPIRoute) -> [MailerAPIEndpoint] {
        return Array(validMap[route] ?? [])
    }

    public static func isValid(endpoint: MailerAPIEndpoint, for route: MailerAPIRoute) -> Bool {
        validMap[route]?.contains(endpoint) ?? false
    }

    public var requiresAvailability: Bool {
        route.endpointsRequiringAvailability.contains(endpoint)
    }
}
