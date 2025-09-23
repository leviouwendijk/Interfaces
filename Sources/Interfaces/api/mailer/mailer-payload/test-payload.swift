import Foundation
import Structures

public struct TestPayload: MailerAPIPayload {
    public typealias Variables = MailerAPITestVariables

    public let route:    MailerAPIRoute = .test
    public let endpoint: MailerAPIEndpoint
    public let content:  MailerAPIRequestContent<Variables>

    public init(
        endpoint:      MailerAPIEndpoint,
        variables:     MailerAPITestVariables = MailerAPITestVariables(),
        customFrom:    MailerAPIEmailFrom? = nil,
        emailsTo:      [String],
        emailsCC:      [String] = [],
        emailsBCC:     [String]? = nil,
        emailsReplyTo: [String]? = nil,
        attachments:   [MailerAPIEmailAttachment]? = nil,
        addHeaders:    [String: String] = [:]
    ) throws {
        self.endpoint = endpoint

        let template = MailerAPITemplate(variables: variables)

        let attach = MailerAPIEmailAttachmentsArray(attachments: attachments)

        let from: MailerAPIEmailFrom
        if let override = customFrom {
            from = override
        } else {
            from = try MailerAPIRequestDefaults.defaultFrom(for: route)
        }

        let bccList = try emailsBCC ?? MailerAPIRequestDefaults.defaultBCC()
        let to = MailerAPIEmailTo(
            to: emailsTo,
            cc: emailsCC,
            bcc: bccList
        )

        let replyTo = try emailsReplyTo ?? MailerAPIRequestDefaults.defaultReplyTo()

        self.content = MailerAPIRequestContent(
            from:        from,
            to:          to,
            subject:     nil,
            template:    template,
            headers:     addHeaders,
            replyTo:     replyTo,
            attachments: attach
        )
    }
}

public extension TestPayload {
    static func make(
        endpoint:      MailerAPIEndpoint,
        message:       String? = nil,
        statusCode:    Int? = nil,
        extra:         [String: String]? = nil,
        customFrom:    MailerAPIEmailFrom? = nil,
        emailsTo:      [String],
        emailsCC:      [String] = [],
        emailsBCC:     [String]? = nil,
        emailsReplyTo: [String]? = nil,
        attachments:   [MailerAPIEmailAttachment]? = nil,
        addHeaders:    [String: String] = [:]
    ) throws -> TestPayload {
        let defaults = defaultVariables(for: endpoint)
        let vars = MailerAPITestVariables(
            message: message ?? defaults.message,
            statusCode: statusCode ?? defaults.statusCode,
            extra: extra
        )

        return try TestPayload(
            endpoint:      endpoint,
            variables:     vars,
            customFrom:    customFrom,
            emailsTo:      emailsTo,
            emailsCC:      emailsCC,
            emailsBCC:     emailsBCC,
            emailsReplyTo: emailsReplyTo,
            attachments:   attachments,
            addHeaders:    addHeaders
        )
    }

    private static func defaultVariables(for endpoint: MailerAPIEndpoint) -> MailerAPITestVariables {
        switch (endpoint.base, endpoint.sub) {
        case (.ok, _):
            return .init(message: "OK", statusCode: 200)
        case (.status, _):
            return .init(message: "Custom status", statusCode: 200)
        case (.error, .some(.json)):
            return .init(message: "Deliberate JSON error")
        case (.error, _):
            return .init(message: "Deliberate error")
        default:
            return .init()
        }
    }
}
