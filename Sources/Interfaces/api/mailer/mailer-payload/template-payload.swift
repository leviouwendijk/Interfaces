import Foundation
import Structures

public struct TemplatePayload: MailerAPIPayload {
    public typealias Variables = MailerAPITemplateVariables

    public let route:     MailerAPIRoute     = .template
    public let endpoint:  MailerAPIEndpoint
    public let content:   MailerAPIRequestContent<Variables>

    public init(
            endpoint:     MailerAPIEndpoint = .fetch,
            variables:    MailerAPITemplateVariables,
            addHeaders:   [String: String] = [:],
    ) throws {
        self.endpoint = endpoint

        let template = MailerAPITemplate(
            variables: variables
        )

        self.content = MailerAPIRequestContent(
            from:        nil,
            to:          nil,
            subject:     nil,
            template:    template,
            headers:     addHeaders,
            replyTo:     nil,
            attachments: .init(attachments: nil)
        )
    }
}
