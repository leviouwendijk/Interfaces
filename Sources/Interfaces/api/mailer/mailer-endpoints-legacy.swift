extension MailerAPIEndpoint {
    // plain “base” endpoints
    public static let confirmation        = MailerAPIEndpoint(base: .confirmation)
    public static let issue               = MailerAPIEndpoint(base: .issue)
    public static let follow              = MailerAPIEndpoint(base: .follow)
    public static let expired             = MailerAPIEndpoint(base: .expired)
    // public static let onboarding          = MailerAPIEndpoint(base: .onboarding)
    public static let review              = MailerAPIEndpoint(base: .review)
    public static let check               = MailerAPIEndpoint(base: .check)
    public static let food                = MailerAPIEndpoint(base: .food)
    public static let fetch               = MailerAPIEndpoint(base: .fetch)
    public static let demo                = MailerAPIEndpoint(base: .demo)

    // the “base/sub” combinations
    public static let issueSimple         = MailerAPIEndpoint(base: .issue,        sub: .simple)
    public static let wrongPhone          = MailerAPIEndpoint(base: .wrong,        sub: .phone)
    public static let messageSend         = MailerAPIEndpoint(base: .message,      sub: .send)
    public static let availabilityRequest = MailerAPIEndpoint(base: .availability, sub: .request)
    public static let availabilityDecrypt = MailerAPIEndpoint(base: .availability, sub: .decrypt)
}
