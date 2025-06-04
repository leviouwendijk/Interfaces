import Foundation

public struct CustomPayload: MailerAPIPayload {
    public typealias Variables = MailerAPICustomVariables

    public let route:     MailerAPIRoute     = .custom
    public let endpoint:  MailerAPIEndpoint
    public let content:   MailerAPIRequestContent<Variables>

    public init(
            endpoint:     MailerAPIEndpoint = .messageSend,
            variables:    MailerAPICustomVariables,
            customFrom:   MailerAPIEmailFrom? = nil,
            emailsTo:     [String],
            emailsCC:     [String] = [],
            emailsBCC:    [String]? = nil,
            emailsReplyTo:[String]? = nil,
            attachments:  [MailerAPIEmailAttachment]? = nil,
            addHeaders:   [String: String] = [:],
            includeQuote: Bool = false,
            includeInvoice: Bool = false,
    ) throws {
        self.endpoint = endpoint

        let template = MailerAPITemplate(
            variables: variables
        )

        var attach = MailerAPIEmailAttachmentsArray(attachments: attachments)

        let quotePath = try MailerAPIEnvironment.require(.quotePath)
        let quote = try MailerAPIEmailAttachment(path: quotePath)

        let invoicePath = try MailerAPIEnvironment.require(.invoicePDF)
        let invoice = try MailerAPIEmailAttachment(path: invoicePath)

        if includeQuote == true {
            attach.add(quote)
        }

        if includeInvoice == true {
            attach.add(invoice)
        }

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
