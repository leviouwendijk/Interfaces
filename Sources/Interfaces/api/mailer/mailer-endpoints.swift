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
        .support:     .relaties,
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
    case support
    case test

    public func alias() -> String {
        MailerAPIAlias
        .routeMap[self]?.rawValue ?? "relaties"
    }

    @available(*, deprecated, message: "Invoke the endpoint.requiresAvailability boolean")
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

public struct MailerAPIEndpoint: Hashable, Sendable, RawRepresentable {
    public let base: MailerAPIEndpointBase
    public let sub: MailerAPIEndpointSub?
    public let method: HTTPMethod?
    public let isFrontEndVisible: Bool
    public let requiresAvailability: Bool

    public init(
        base: MailerAPIEndpointBase,
        sub: MailerAPIEndpointSub? = nil,
        method: HTTPMethod? = nil,
        isFrontEndVisible: Bool = true,
        requiresAvailability: Bool = false
    ) {
        self.base = base
        self.sub = sub
        self.method = method
        self.isFrontEndVisible = isFrontEndVisible
        self.requiresAvailability = requiresAvailability
    }

    public init?(
        rawValue: String,
    ) {
        let parts = rawValue.split(separator: "/", maxSplits: 1).map(String.init)
        guard let b = MailerAPIEndpointBase(rawValue: parts[0]) else { return nil }
        self.base = b
        if parts.count == 2, let s = MailerAPIEndpointSub(rawValue: parts[1]) {
            self.sub = s
        } else {
            self.sub = nil
        }

        self.method = nil
        self.isFrontEndVisible = true // default value
        self.requiresAvailability = false // activates values pane (UI)
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

    public enum MailerAPIEndpointBase: String, CaseIterable, Sendable, Equatable {
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
        case `catch`

        case ok
        case status
        case error
    }

    public enum MailerAPIEndpointSub: String, CaseIterable, Sendable {
        case simple        // “issue/simple”
        case phone         // “wrong/phone”
        case send          // “message/send”
        case request       // “availability/request”
        case decrypt       // “availability/decrypt”
        case submit

        case json
    }

    public var id: String {
        "\(rawValue)|\(method?.rawValue ?? "NONE")"
    }

    // include method in equality/hash
    public static func == (lhs: MailerAPIEndpoint, rhs: MailerAPIEndpoint) -> Bool {
        lhs.base == rhs.base && lhs.sub == rhs.sub && lhs.method == rhs.method
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(base)
        hasher.combine(sub?.rawValue ?? "")
        hasher.combine(method?.rawValue ?? "")
    }

    // includes Base
    @inlinable
    public static func ~= (pattern: MailerAPIEndpointBase, value: MailerAPIEndpoint) -> Bool {
        value.base == pattern
    }

    // includes Sub
    @inlinable
    public static func ~= (pattern: MailerAPIEndpointSub, value: MailerAPIEndpoint) -> Bool {
        value.sub == pattern
    }

    // includes HTTPMethod
    @inlinable
    public static func ~= (pattern: HTTPMethod, value: MailerAPIEndpoint) -> Bool {
        value.method == pattern
    }

    // includes (BASE, optional SUB, optional METHOD)
    // pattern nil equates to a wildcard
    @inlinable
    public static func ~= (
        pattern: (MailerAPIEndpointBase, MailerAPIEndpointSub?, HTTPMethod?),
        value: MailerAPIEndpoint
    ) -> Bool {
        guard value.base == pattern.0 else { return false }
        if let sub = pattern.1, value.sub != sub { return false }
        if let method = pattern.2, value.method != method { return false }
        return true
    }
}

public enum MailerAPIEndpointStage: String, CaseIterable, Sendable {
    case sales
    case operations
    case billing
    case other
    case testing
}

public struct MailerAPIMapObject: Sendable {
    public let endpoints: Set<MailerAPIEndpoint>
    public let stage: MailerAPIEndpointStage
    
    public init(
        endpoints: Set<MailerAPIEndpoint>,
        stage: MailerAPIEndpointStage
    ) {
        self.endpoints = endpoints
        self.stage = stage
    }

    public init(
        _ endpoints: Set<MailerAPIEndpoint>,
        _ stage: MailerAPIEndpointStage
    ) {
        self.endpoints = endpoints
        self.stage = stage
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

    private static let validMap: [MailerAPIRoute: MailerAPIMapObject] = [
        .invoice: .init(
            [
                .init(base: .issue, method: .post),
                .init(base: .issue, sub: .simple, method: .post, isFrontEndVisible: false), // simple endpoint is still non-existent
                .init(base: .expired, method: .post)
            ],
            .billing
        ),

        .appointment: .init(
            [
                .init(base: .confirmation, method: .post),
                .init(base: .availability, sub: .request, method: .post),
                .init(base: .availability, sub: .decrypt, method: .post, isFrontEndVisible: false) // endpoint not for front end use
            ],
            .operations
        ),

        .quote: .init(
            [
                .init(base: .issue, method: .post),
                .init(base: .follow, method: .post),
                .init(base: .agreement, sub: .request, method: .post),
                .init(base: .agreement, sub: .decrypt, method: .post, isFrontEndVisible: false) // endpoint not for front end use
            ],
            .sales
        ),

        .lead: .init(
            [
                .init(base: .confirmation, method: .post, requiresAvailability: true),
                .init(base: .follow, method: .post, requiresAvailability: true),
                .init(base: .check, method: .post, requiresAvailability: true),
                .init(base: .wrong, sub: .phone, method: .post)
            ],
            .sales
        ),

        .onboarding: .init(
            [
                .init(base: .assessment, sub: .request, method: .post),
                .init(base: .assessment, sub: .decrypt, method: .post, isFrontEndVisible: false),
                .init(base: .assessment, sub: .submit, method: .post, isFrontEndVisible: false)
            ],
            .sales
        ),

        .service: .init(
            [
                // .init(base: .onboarding),
                .init(base: .follow, method: .post),
                .init(base: .demo, method: .post)
            ],
            .operations
        ),
        
        .resolution: .init(
            [
                .init(base: .review, method: .post),
                .init(base: .follow, method: .post)
            ],
            .operations
        ),
            
        .affiliate: .init(
            [
                .init(base: .food, method: .post)
            ],
            .operations
        ),

        .custom: .init(
            [
                .init(base: .message, sub: .send, method: .post)
            ],
            .other
        ),


        .template: .init(
            [
                .init(base: .fetch, method: .post)
            ],
            .other
        ),

        .support: .init(
            [
                .init(base: .catch, method: .post)
            ],
            .operations
        ),

        .test: .init(
            [
                .init(base: .ok, method: .get),
                .init(base: .ok, method: .post),
                .init(base: .status, method: .get),
                .init(base: .status, method: .post),
                .init(base: .error, method: .get),
                .init(base: .error, method: .post),
                .init(base: .error, sub: .json, method: .get),
                .init(base: .error, sub: .json, method: .post)
            ],
            .testing
        )
    ]

    public static func isValid(endpoint: MailerAPIEndpoint, for route: MailerAPIRoute) -> Bool {
        guard let map = Self.validMap[route] else { return false }
        return map.endpoints.contains(endpoint)
    }

    public static func stage(for route: MailerAPIRoute) -> MailerAPIEndpointStage? {
        Self.validMap[route]?.stage
    }

    public init(
        route: MailerAPIRoute,
        endpoint: MailerAPIEndpoint
    ) throws {
        guard
            // let allowed = MailerAPIPath.validMap[route],
            // allowed.contains(endpoint)
            Self.isValid(endpoint: endpoint, for: route)
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

    // public static func endpoints(for route: MailerAPIRoute) -> [MailerAPIEndpoint] {
    //     return Array(validMap[route] ?? [])
    // }

    public static func endpoints(for route: MailerAPIRoute) -> [MailerAPIEndpoint] {
        return Array(Self.validMap[route]?.endpoints ?? [])
    }

    // public static func isValid(endpoint: MailerAPIEndpoint, for route: MailerAPIRoute) -> Bool {
    //     validMap[route]?.contains(endpoint) ?? false
    // }

    // public var requiresAvailability: Bool {
    //     route.endpointsRequiringAvailability.contains(endpoint)
    // }

    public var requiresAvailability: Bool {
        guard let map = Self.validMap[route] else { return false }
        return map.endpoints.first(where: { $0 == endpoint })?.requiresAvailability ?? false
    }
}
