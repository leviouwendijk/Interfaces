import Foundation
import Combine
import SwiftUI
import plate

// invoice - /issue, /expired, /issue/simple
public struct MailerAPIInvoiceVariables: Encodable {
    public var name:          String
    public var client_name:   String
    public var email:         String
    public var invoice_id:    String
    public var due_date:      String
    public var product_line:  String
    public var amount:        String
    public var vat_percentage:String
    public var vat_amount:    String
    public var total:         String
    public var terms_total:   String
    public var terms_current: String

    public init(
        clientName:    String,
        email:         String,
        invoiceId:     String,
        dueDate:       String,
        productLine:   String,
        amount:        String,
        vatPercentage: String,
        vatAmount:     String,
        total:         String,
        termsTotal:    String,
        termsCurrent:  String
    ) {
        self.name           = clientName
        self.client_name    = clientName
        self.email          = email
        self.invoice_id     = invoiceId
        self.due_date       = dueDate
        self.product_line   = productLine
        self.amount         = amount
        self.vat_percentage = vatPercentage
        self.vat_amount     = vatAmount
        self.total          = total
        self.terms_total    = termsTotal
        self.terms_current  = termsCurrent
    }

    // init with blank defaults
    public init() {
        self.name           = ""
        self.client_name    = ""
        self.email          = ""
        self.invoice_id     = ""
        self.due_date       = ""
        self.product_line   = ""
        self.amount         = ""
        self.vat_percentage = ""
        self.vat_amount     = ""
        self.total          = ""
        self.terms_total    = ""
        self.terms_current  = ""
    }
}

// lead -- /confirmation, /follow, /check
public struct MailerAPILeadVariables: Encodable {
    public let name:       String
    public let dog:        String

    // public let time_range: [String:[String:String]]?
    public let time_range: MailerAPIAvailabilityContent?

    public init(
        name:       String,
        dog:        String,
        availability schedules: [MailerAPIWeekday: MailerAPIDaySchedule]? = nil
    ) {
        self.name       = name
        self.dog        = dog
        if let schedules = schedules {
            self.time_range = MailerAPIAvailabilityContent(from: schedules)
        } else {
            self.time_range = nil
        }
    }
}

// quote -- /issue, /follow
public struct MailerAPIQuoteVariables: Encodable {
    public let name:       String
    public let dog:        String

    public init(name: String, dog: String) {
        self.name = name
        self.dog  = dog
    }
}

// affiliate -- /food
public struct MailerAPIAffiliateVariables: Encodable {
    public let name:       String
    public let dog:        String

    public init(name: String, dog: String) {
        self.name = name
        self.dog  = dog
    }
}

// service -- /follow, /onboarding
public struct MailerAPIServiceVariables: Encodable {
    public let name:       String
    public let dog:        String

    public init(name: String, dog: String) {
        self.name = name
        self.dog  = dog
    }
}

// resolution -- /review, /onboarding
public struct MailerAPIResolutionVariables: Encodable {
    public let name:       String
    public let dog:        String

    public init(name: String, dog: String) {
        self.name = name
        self.dog  = dog
    }
}

// custom -- /message/send
public struct MailerAPICustomVariables: Encodable {
    public let body:       String
    // public let time_range: [String:[String:String]]?
    public let time_range: MailerAPIAvailabilityContent?

    public init(
        body:         String,
        availability schedules: [MailerAPIWeekday: MailerAPIDaySchedule]? = nil
    ) {
        self.body = body
        if let schedules = schedules {
            self.time_range = MailerAPIAvailabilityContent(from: schedules)
        } else {
            self.time_range = nil
        }
    }
}

// custom -- /template/fetch
public struct MailerAPITemplateVariables: Encodable {
    public let category:    String
    public let file:        String

    public init(category: String, file: String) {
        self.category = category
        self.file     = file
    }
}


// appointment -- /confirmation
public struct MailerAPIAppointmentVariables: Encodable {
    public let name:         String
    public let dog:          String
    public let appointments: [MailerAPIAppointmentContent]

    // public let ics_files:    [String]?  // base64‐encoded ICS blobs
    // handle ICS in payload initializer?

    public init(
        name:         String,
        dog:          String,
        appointments: [MailerAPIAppointmentContent]
    ) {
        self.name         = name
        self.dog          = dog
        self.appointments = appointments
    }
}

// content of appointment var 
public struct MailerAPIAppointmentContent: Encodable {
    public let date:     String
    public let time:     String
    public let day:      String
    public let street:   String
    public let number:   String
    public let area:     String
    public let location: String

    public init(
        date:     String,
        time:     String,
        day:      String,
        street:   String,
        number:   String,
        area:     String,
        location: String
    ) {
        self.date     = date
        self.time     = time
        self.day      = day
        self.street   = street
        self.number   = number
        self.area     = area
        self.location = location
    }
}

// output full time_range dictionary
public struct MailerAPIAvailabilityContent: Encodable {
    public let schedule: [MailerAPIWeekday: MailerAPIDayAvailabilityContent]

    public init(from schedules: [MailerAPIWeekday: MailerAPIDaySchedule]) {
        var map: [MailerAPIWeekday: MailerAPIDayAvailabilityContent] = [:]
        let df: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f
        }()
        for (day, sched) in schedules {
            guard sched.enabled else { continue }
            map[day] = .init(
                start: df.string(from: sched.start),
                end:   df.string(from: sched.end)
            )
        }
        self.schedule = map
    }

    public func time_range() -> [String: [String: String]] {
        schedule.reduce(into: [:]) { out, pair in
            let (day, avail) = pair
            out[day.rawValue] = [
                "start": avail.start,
                "end":   avail.end
            ]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(time_range())
    }
}

// time range slot
public struct MailerAPIDayAvailabilityContent: Codable {
    public let start: String
    public let end:   String

    public init(
        start:        String,
        end:          String
    ) {
        self.start        = start
        self.end          = end
    }
}

public enum MailerAPIWeekday: String, RawRepresentable, CaseIterable, Identifiable, Encodable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
    public var id: String { rawValue }

    public var dutch: String {
        switch self {
            case .monday: return "Maandag"
            case .tuesday: return "Dinsdag"
            case .wednesday: return "Woensdag"
            case .thursday: return "Donderdag"
            case .friday: return "Vrijdag"
            case .saturday: return "Zaterdag"
            case .sunday: return "Zondag"
        }
    }
}

public struct MailerAPIDaySchedule: Encodable {
    public var enabled: Bool
    public var start:   Date
    public var end:     Date

    public init(defaultsFor day: MailerAPIWeekday) {
        let cal   = Calendar.current
        let today = Date()
        func at(_ hour: Int, _ minute: Int) -> Date {
            return cal.date(
              bySettingHour: hour,
              minute: minute,
              second: 0,
              of: today
            )!
        }

        switch day {
        case .monday:
            enabled = true
            start   = at(18, 0)
            end     = at(21, 0)
        case .tuesday:
            enabled = true
            start   = at(10, 0)
            end     = at(21, 0)
        case .wednesday:
            enabled = true
            start   = at(18, 0)
            end     = at(21, 0)
        case .thursday:
            enabled = true
            start   = at(18, 0)
            end     = at(21, 0)
        case .friday:
            enabled = true
            start   = at(10, 0)
            end     = at(21, 0)
        case .saturday:
            enabled = true
            start   = at(18, 0)
            end     = at(21, 0)
        case .sunday:
            enabled = true
            start   = at(18, 0)
            end     = at(21, 0)
        }
    }
}
