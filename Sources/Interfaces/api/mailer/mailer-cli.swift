import Foundation
import plate
import Structures

public struct MailerCLIStateVariables {
    public let invoiceId: String
    public let fetchableCategory: String
    public let fetchableFile: String
    public let finalEmail: String
    public let finalSubject: String
    public let finalHtml: String
    public let includeQuote: Bool
    
    public init(
        invoiceId: String,
        fetchableCategory: String,
        fetchableFile: String,
        finalEmail: String,
        finalSubject: String,
        finalHtml: String,
        includeQuote: Bool
    ) {
        self.invoiceId = invoiceId
        self.fetchableCategory = fetchableCategory
        self.fetchableFile = fetchableFile
        self.finalEmail = finalEmail
        self.finalSubject = finalSubject
        self.finalHtml = finalHtml
        self.includeQuote = includeQuote
    }
} 

public enum MailerCLIArgError: Error {
    case missingArgumentComponents
}

public struct MailerCLIArguments {
    public let client: String
    public let email: String
    public let dog: String
    public let route: MailerAPIRoute?
    public let endpoint: MailerAPIEndpoint?
    public let availabilityJSON: String?
    public let appointmentsJSON: String?
    public let needsAvailability: Bool
    public let stateVariables: MailerCLIStateVariables
    
    public init(
        client: String,
        email: String,
        dog: String,
        route: MailerAPIRoute?,
        endpoint: MailerAPIEndpoint?,
        availabilityJSON: String?,
        appointmentsJSON: String?,
        needsAvailability: Bool,
        stateVariables: MailerCLIStateVariables
    ) {
        self.client = client
        self.email = email
        self.dog = dog
        self.route = route
        self.endpoint = endpoint
        self.availabilityJSON = availabilityJSON
        self.appointmentsJSON = appointmentsJSON
        self.needsAvailability = needsAvailability
        self.stateVariables = stateVariables
    }

    public func string(_ includeBinaryName: Bool = false) throws -> String {
        guard let r = route, let e = endpoint else {
            throw MailerCLIArgError.missingArgumentComponents
        }

        var components: [String] = []

        if includeBinaryName {
            components.insert("mailer", at: 0)
        }

        switch r {
        case .invoice:
            components.append("invoice \(stateVariables.invoiceId) --responder")
            if e == .expired {
                components.append("--expired")
            }

        case .template: 
            components.append("template-api \(stateVariables.fetchableCategory) \(stateVariables.fetchableFile)")

        case .custom:
            components.append("custom-message --email \"\(stateVariables.finalEmail)\" --subject \"\(stateVariables.finalSubject)\" --body \"\(stateVariables.finalHtml)\"")

            if  stateVariables.includeQuote {
                components.append(" --quote")
            }

        case .appointment:
            components.append(r.rawValue)
            components.append("'\(appointmentsJSON ?? "")'")

            components.append("--client \"\(client)\"")
            components.append("--email \"\(email)\"")
            components.append("--dog \"\(dog)\"")

            // components.append("--appointments-json '\(appointmentsJSON ?? "")'")

        default:
            components.append(r.rawValue)
            components.append("--client \"\(client)\"")
            components.append("--email \"\(email)\"")
            components.append("--dog \"\(dog)\"")

            if !(e == .issue || e == .confirmation || e == .review) {
                components.append("--\(e.rawValue)")
            }

            if needsAvailability {
                components.append("--availability-json '\(availabilityJSON ?? "")'")
            }
        }

        let compacted = components.compactMap { $0 }
        return compacted.joined(separator: " ")
    }
}

public func executeMailerCLI(_ arguments: String) throws {
    do {
        let home = Home.string()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh") // Use Zsh directly
        process.arguments = ["-c", "source ~/dotfiles/.vars.zsh && \(home)/sbm-bin/mailer \(arguments)"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let outputString = String(data: outputData, encoding: .utf8) ?? ""
        let errorString = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus == 0 {
            print("mailer executed successfully:\n\(outputString)")
        } else {
            print("Error running mailer:\n\(errorString)")
            throw NSError(domain: "mailer", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorString])
        }
    } catch {
        print("Error running commands: \(error)")
        throw error
    }
}
