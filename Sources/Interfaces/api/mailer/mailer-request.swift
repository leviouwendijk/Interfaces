import Foundation
import plate
import Structures

public struct MailerAPIRequestDefaults: Encodable {
    public init() {}

    public static func automationsEmail() throws -> String {
        try MailerAPIEnvironment.require(.automationsEmail)
    }

    public static func supportEmail() throws -> String {
        try MailerAPIEnvironment.require(.replyTo)
    }

    public static func defaultQuotePath() throws -> String {
        try MailerAPIEnvironment.require(.quotePath)
    }

    public static func defaultInvoicePath() throws -> String {
        try MailerAPIEnvironment.require(.invoicePDF)
    }

    public static func defaultBaseURL() throws -> String {
        try MailerAPIEnvironment.require(.apiURL)
    }

    public static func defaultBCC() throws -> [String] {
        let email = try automationsEmail()
        return [email]
    }

    public static func defaultReplyTo() throws -> [String] {
        let email = try supportEmail()
        return [email]
    }

    public static func defaultFrom(for route: MailerAPIRoute) throws -> MailerAPIEmailFrom {
        let name   = try MailerAPIEnvironment.require(.from)
        let domain = try MailerAPIEnvironment.require(.domain)
        let alias  = route.alias()
        
        return MailerAPIEmailFrom(
            name: name,
            alias: alias,
            domain: domain
        )
    }
}

public struct MailerAPIRequestContent<Variables: Encodable>: Encodable {
    public let from:        MailerAPIEmailFrom?
    public let to:          MailerAPIEmailTo?
    public let subject:     String?
    public let template:    MailerAPITemplate<Variables>?
    public let headers:     [String:String]
    public let replyTo:     [String]?
    public let attachments: MailerAPIEmailAttachmentsArray

    private enum CodingKeys: String, CodingKey {
        case from, to, cc, bcc, replyTo, subject, body, template, headers, attachments
    }

    public init(
        from:        MailerAPIEmailFrom? = nil,
        to:          MailerAPIEmailTo? = nil,
        subject:     String? = nil,
        template:    MailerAPITemplate<Variables>? = nil,
        headers:     [String:String] = [:],
        replyTo:     [String]? = nil,
        attachments: MailerAPIEmailAttachmentsArray
    ) {
        self.from        = from
        self.to          = to
        self.subject     = subject
        self.template    = template
        self.headers     = headers
        self.replyTo     = replyTo
        self.attachments = attachments
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Only emit “from” if it’s non‐nil
        try container.encodeIfPresent(from, forKey: .from)

        // Only emit to/cc/bcc if “to” is non‐nil
        if let to = to {
            try container.encode(to.to, forKey: .to)
            try container.encode(to.cc, forKey: .cc)
            try container.encode(to.bcc, forKey: .bcc)
        }

        // Same for replyTo
        try container.encodeIfPresent(replyTo, forKey: .replyTo)

        // The rest can stay encodeIfPresent or encode (for non‐optionals)
        try container.encodeIfPresent(subject,  forKey: .subject)
        // try container.encodeIfPresent(body,     forKey: .body)
        try container.encodeIfPresent(template, forKey: .template)
        try container.encode(headers,            forKey: .headers)
        try container.encode(attachments,       forKey: .attachments)
    }
}

public struct MailerAPITemplate<Variables: Encodable>: Encodable {
    public let category:  String? = nil
    public let file:      String? = nil
    public let variables: Variables
    
    private enum CodingKeys: String, CodingKey {
        case category, file, variables
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encodeIfPresent(file,     forKey: .file)
        try c.encode(variables,         forKey: .variables)
    }
}

public struct MailerAPIEmailFrom: Encodable {
    public let name: String
    public let alias: String
    public let domain: String

    public init(name: String, alias: String, domain: String) {
        self.name = name
        self.alias = alias
        self.domain = domain
    }

    public func dictionary() -> [String: String] {
        return [
            "name": name,
            "alias": alias,
            "domain": domain
        ]
    } 
}

public struct MailerAPIEmailTo: Encodable {
    public let to: [String]
    public let cc: [String]
    public let bcc: [String]
    
    public func dictionary() -> [String: [String]] {
        return [
            "to": to,
            "cc": cc,
            "bcc": bcc
        ]
    } 
}

public enum MailerAPIEmailAttachmentFileType: String, Encodable {
    case pdf = "pdf"
    case ics = "ics"
    case jpg = "jpg"
    case png = "png"
    case txt = "txt"
    case json = "json"
    case unknown = "unknown"
    
    public static func from(extension ext: String) -> MailerAPIEmailAttachmentFileType {
        return MailerAPIEmailAttachmentFileType(rawValue: ext.lowercased()) ?? .unknown
    }
}

public struct MailerAPIEmailAttachment: Encodable {
    public let path: String?
    public let type: MailerAPIEmailAttachmentFileType
    public let value: String
    public let name: String

    public init(
        path: String,
        type: MailerAPIEmailAttachmentFileType? = nil,
        name: String? = nil
    ) throws {
        self.path = path
        let fileURL = URL(fileURLWithPath: path)

        self.value = try fileURL.base64()

        let fileExtension = (path as NSString).pathExtension

        self.type = type ?? .from(extension: fileExtension)
        self.name = name ?? fileURL.lastPathComponent
    }

    public init(
        data: Data,
        type: MailerAPIEmailAttachmentFileType,
        name: String
    ) {
        self.path = nil
        self.value = data.base64EncodedString()
        self.type  = type
        self.name  = name
    }

    public func dictionary() -> [String: String] {
        return [
            "type": type.rawValue,
            "value": value,
            "name": name
        ]
    }

    private enum CodingKeys: String, CodingKey {
        case type, value, name
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(value, forKey: .value)
        try container.encode(name,  forKey: .name)
    }
}

// extension URL {
//     public func base64() throws -> String {
//         try Data(contentsOf: self).base64EncodedString()
//     }
// }

public struct MailerAPIEmailAttachmentsArray: Encodable {
    private(set) var attachments: [MailerAPIEmailAttachment] = []

    public init() {}

    public init(attachments: [MailerAPIEmailAttachment]? = nil) {
        self.attachments = attachments ?? []
    }

    public mutating func add(_ attachment: MailerAPIEmailAttachment) {
        attachments.append(attachment)
    }

    public mutating func add(contentsOf attachmentsArray: [MailerAPIEmailAttachment]) {
        attachments.append(contentsOf: attachmentsArray)
    }

    public mutating func add(
        from paths: [String],
        type: MailerAPIEmailAttachmentFileType
    ) throws {
        for path in paths {
            let fileName = (path as NSString).lastPathComponent
            let attachment = try MailerAPIEmailAttachment(
                path: path,
                type: type,
                name: fileName
            )
            attachments.append(attachment)
        }
    }

    public init(
        paths: [String],
        type: MailerAPIEmailAttachmentFileType
    ) throws {
        self.init()
        try add(from: paths, type: type)
    }

    public func array() -> [[String: String]] {
        attachments.map { $0.dictionary() }
    }

    // older version reliant on dictionary()
    // public func encode(to encoder: Encoder) throws {
    //     var container = encoder.unkeyedContainer()
    //     for dict in attachments.map({ $0.dictionary() }) {
    //         try container.encode(dict)
    //     }
    // }

    // new version with encodable MailerAPIEmailAttachment struct
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for attachment in attachments {
            try container.encode(attachment)
        }
    }
}

public struct ICSBuilder: Encodable {
    /// Converts a Date to an ICS-compliant UTC timestamp string ("yyyyMMdd'T'HHmmss'Z'").
    public static func dateToICS(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    /// Returns the current timestamp in ICS "DTSTAMP" format.
    public static func timestamp() -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let raw = iso.string(from: Date())
        // Strip out hyphens, colons, and fractional seconds
        let cleaned = raw
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
            .components(separatedBy: ".").first ?? raw
        return cleaned
    }

    /// Generates a full iCalendar string for a single VEVENT.
    ///
    /// - Parameters:
    ///   - uid: A unique identifier for the event (default: random UUID).
    ///   - start: The event start date (UTC).
    ///   - end: The event end date (UTC).
    ///   - summary: A brief summary or title for the event.
    ///   - description: A longer description, newlines as "\\n".
    ///   - location: A human-readable location string (can include newlines with "\\n").
    ///   - prodId: An optional product identifier string for the calendar (default: your app).
    public static func event(
        uid: String = UUID().uuidString,
        start: Date,
        end: Date,
        summary: String,
        description: String,
        location: String,
        prodId: String
    ) -> String {
        let dtStamp = timestamp()
        let dtStart = dateToICS(start)
        let dtEnd = dateToICS(end)

        return [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:\(prodId)",
            "BEGIN:VEVENT",
            "UID:\(uid)",
            "DTSTAMP:\(dtStamp)",
            "DTSTART:\(dtStart)",
            "DTEND:\(dtEnd)",
            "SUMMARY:\(escapeText(summary))",
            "DESCRIPTION:\(escapeText(description))",
            "LOCATION:\(escapeText(location))",
            "END:VEVENT",
            "END:VCALENDAR"
        ]
        .joined(separator: "\r\n")
    }

    /// Escapes commas, semicolons, and newlines for ICS compatibility.
    private static func escapeText(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
        return escaped
    }
}

