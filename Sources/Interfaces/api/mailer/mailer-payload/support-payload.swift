import Foundation
import Structures

public struct SupportPayload: MailerAPIPayload {
    public typealias Variables = MailerAPISupportVariables

    public let route:     MailerAPIRoute     = .support
    public let endpoint:  MailerAPIEndpoint
    public let content:   MailerAPIRequestContent<Variables>

    public init(
            endpoint:     MailerAPIEndpoint = .food,
            variables:    MailerAPISupportVariables,
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
