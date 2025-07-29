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
    case onboarding

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

// public enum MailerAPIEndpoint: String, CaseIterable, RawRepresentable, Sendable {
//     case confirmation
//     case issue
//     case issueSimple = "issue/simple"
//     case follow
//     case expired
//     case onboarding
//     case review
//     case check
//     case wrongPhone = "wrong/phone"
//     case food
//     case fetch
//     // case templateFetch  = "template/fetch"
//     case messageSend    = "message/send"
//     case demo
//     case availabilityRequest = "availability/request"
//     case availabilityDecrypt = "availability/decrypt"

//     public func viewableString() -> String {
//         return self.rawValue.viewableEndpointString()
//     }
// }

public struct MailerAPIEndpoint: Hashable, Sendable, RawRepresentable {
    public let base: MailerAPIEndpointBase
    public let sub: MailerAPIEndpointSub?
    public let isFrontEndVisible: Bool

    public init(
        base: MailerAPIEndpointBase,
        sub: MailerAPIEndpointSub? = nil,
        isFrontEndVisible: Bool = true
    ) {
        self.base = base
        self.sub = sub
        self.isFrontEndVisible = isFrontEndVisible
    }

    public init?(
        rawValue: String
    ) {
        let parts = rawValue.split(separator: "/", maxSplits: 1).map(String.init)
        guard let b = MailerAPIEndpointBase(rawValue: parts[0]) else { return nil }
        self.base = b
        if parts.count == 2, let s = MailerAPIEndpointSub(rawValue: parts[1]) {
            self.sub = s
        } else {
            self.sub = nil
        }

        self.isFrontEndVisible = true // default value
    }

    public var rawValue: String {
        guard let sub = sub else {
            return base.rawValue
        }
        return "\(base.rawValue)/\(sub.rawValue)"
    }

    public func viewableString() -> String {
        rawValue.viewableEndpointString()
    }

    public enum MailerAPIEndpointBase: String, CaseIterable, Sendable {
        case confirmation
        case issue
        case follow
        case expired
        // case onboarding
        case assessment
        case review
        case check
        case wrong
        case food
        case fetch
        case message
        case demo
        case availability
        case agreement
    }

    public enum MailerAPIEndpointSub: String, CaseIterable, Sendable {
        case simple        // “issue/simple”
        case phone         // “wrong/phone”
        case send          // “message/send”
        case request       // “availability/request”
        case decrypt       // “availability/decrypt”
        case submit
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

    private static let validMap: [MailerAPIRoute: Set<MailerAPIEndpoint>] = [
        .invoice: [
            .init(base: .issue),
            .init(base: .issue, sub: .simple, isFrontEndVisible: false), // simple endpoint is still non-existent
            .init(base: .expired)
        ],
        .appointment: [
            .init(base: .confirmation),
            .init(base: .availability, sub: .request),
            .init(base: .availability, sub: .decrypt, isFrontEndVisible: false) // endpoint not for front end use
        ],
        .quote: [
            .init(base: .issue),
            .init(base: .follow),
            .init(base: .agreement, sub: .request),
            .init(base: .agreement, sub: .decrypt, isFrontEndVisible: false) // endpoint not for front end use
        ],
        .lead: [
            .init(base: .confirmation),
            .init(base: .follow),
            .init(base: .check),
            .init(base: .wrong, sub: .phone)
        ],
        .onboarding: [
            .init(base: .assessment, sub: .request),
            .init(base: .assessment, sub: .decrypt, isFrontEndVisible: false),
            .init(base: .assessment, sub: .submit)
        ],
        .service: [
            // .init(base: .onboarding),
            .init(base: .follow),
            .init(base: .demo)
        ],
        .resolution: [
            .init(base: .review),
            .init(base: .follow)
        ],
        .affiliate: [
            .init(base: .food)
        ],
        .custom: [
            .init(base: .message, sub: .send)
        ],
        .template: [
            .init(base: .fetch)
        ]
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
