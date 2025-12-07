import Foundation
import Structures
import plate

public struct AppointmentPayload: MailerAPIPayload {
    public typealias Variables = MailerAPIAppointmentVariables

    public let route:     MailerAPIRoute = .appointment
    public let endpoint:  MailerAPIEndpoint
    public let content:   MailerAPIRequestContent<Variables>

    public init(
            endpoint:     MailerAPIEndpoint,
            variables:    MailerAPIAppointmentVariables,
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

        var attach = MailerAPIEmailAttachmentsArray(attachments: attachments)

        for (idx, appt) in variables.appointments.enumerated() {
            // guard let start = Calendar.current.date(from: appt.dateComponents) else {
            //     throw MailerAPIAppointmentError.cannotConstructDateFromComponents
            // }
            let start = try appt.dateComponents.date(
                .amsterdam
            )
            let end = start.addingTimeInterval(2 * 60 * 60)

            let icsText = ICSBuilder.event(
                uid:         UUID().uuidString,
                start:       start,
                end:         end,
                summary:     "Afspraak voor \(variables.dog)",
                // description: "Beste \(variables.name),\n\nJe afspraak voor \(variables.dog) is bevestigd.\n\nHoud alsjeblieft rekening met mogelijke uitloop.\n\nHartelijke groet,\nHet Hondenmeesters Team",
                description: """
                Beste \(variables.name),

                Je afspraak voor \(variables.dog) is bevestigd.

                Houd alsjeblieft rekening met mogelijke uitloop.

                Aanradingen ter voorbereiding:
                1. Geef je hond geen eten direct vooraf de sessie. Dit kan namelijk de mogelijke benutting van voedseldrijf inefficiënt maken.

                2. Zorg dat je eventuele beloningen (voer en spel-objecten) binnen handbereik hebt.

                Hartelijke groet,
                Het Hondenmeesters Team
                """,
                location:    "\(appt.street) \(appt.number), \(appt.area), \(appt.location)",
                prodId:      "//Hondenmeesters//Event//EN"
            )
            let blob = Data(icsText.utf8)
            let fileName = "appointment-\(idx)-\(variables.dog).ics"

            let icsAttachment = MailerAPIEmailAttachment(
                data: blob,
                type: .ics,
                name: fileName
            )
            attach.add(icsAttachment)
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
