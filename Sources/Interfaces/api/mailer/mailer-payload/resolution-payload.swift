import Foundation
import Structures

public struct ResolutionPayload: MailerAPIPayload {
    public typealias Variables = MailerAPIResolutionVariables

    public let route:     MailerAPIRoute     = .resolution
    public let endpoint:  MailerAPIEndpoint
    public let content:   MailerAPIRequestContent<Variables>

    public init(
            endpoint:     MailerAPIEndpoint,
            variables:    MailerAPIResolutionVariables,
            customFrom:   MailerAPIEmailFrom? = nil,
            emailsTo:     [String],
            emailsCC:     [String] = [],
            emailsBCC:    [String]? = nil,
            emailsReplyTo:[String]? = nil,
            attachments:  [MailerAPIEmailAttachment]? = nil,
            addHeaders:   [String: String] = [:]
    ) throws {
        self.endpoint = endpoint

        let template = MailerAPITemplate(
            variables: variables
        )

        let attach = MailerAPIEmailAttachmentsArray(attachments: attachments)

        let from: MailerAPIEmailFrom
        if let override = customFrom {
            from = override
        } else {
            from = try MailerAPIRequestDefaults.defaultFrom(for: route)
        }

        let bccList   = try emailsBCC ?? MailerAPIRequestDefaults.defaultBCC()

        let to = MailerAPIEmailTo(
            to: emailsTo, 
            cc: emailsCC, 
            bcc: bccList
        )

        let replyTo = try emailsReplyTo   ?? MailerAPIRequestDefaults.defaultReplyTo()

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
