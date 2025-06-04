import Foundation
import plate

public enum MailerAPIEnvironmentKey: String {
    case apikey = "MAILER_API_KEY" 
    case apiURL = "MAILER_API_BASE_URL"
    case endpoint = "MAILER_API_ENDPOINT_DEFAULT"
    case from = "MAILER_FROM"
    case alias = "MAILER_ALIAS"
    case aliasInvoice = "MAILER_ALIAS_INVOICE"
    case aliasAppointment = "MAILER_ALIAS_APPOINTMENT"
    case domain = "MAILER_DOMAIN"
    case replyTo = "MAILER_REPLY_TO"
    case invoiceJSON = "MAILER_INVOICE_JSON"
    case invoicePDF = "MAILER_INVOICE_PDF"
    case testEmail = "MAILER_TEST_EMAIL"
    case automationsEmail = "MAILER_AUTOMATIONS_EMAIL"
    case quotePath = "MAILER_QUOTE_PATH"
}

public struct MailerAPIEnvironment {
    public static func require(_ key: MailerAPIEnvironmentKey) throws -> String {
        guard let raw = ProcessInfo.processInfo.environment[key.rawValue],
            !raw.isEmpty
        else {
            throw MailerAPIError.missingEnv(key.rawValue)
        }
        return raw
    }

    public static func optional(_ key: MailerAPIEnvironmentKey) -> String? {
        ProcessInfo.processInfo.environment[key.rawValue]
    }
}
