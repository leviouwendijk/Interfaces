// import Foundation

// public struct NumbersParserInvoiceData: Decodable {
//     public let client_name:   String
//     public let email:         String
//     public let invoice_id:    String
//     public let due_date:      String
//     public let product_line:  String
//     public let revenue_amount:String
//     public let amount:        String
//     public let vat_percentage:String
//     public let vat_amount:    String
//     public let terms_total:   String
//     public let terms_current: String

//     public static func load() throws -> NumbersParserInvoiceData {
//         let path = environment(MailerAPIEnvironmentKey.invoiceJSON.rawValue)
//         let data = try Data(contentsOf: URL(fileURLWithPath: path))
//         let root = try JSONSerialization.jsonObject(with: data) as? [String:Any]
//         guard let inv = root?["Invoices"] as? [String:String] else {
//             throw NSError(domain:"ParsedInvoiceData", code:1,
//                           userInfo:[NSLocalizedDescriptionKey:"Malformed JSON at \(path)"])
//         }
//         let jsonData = try JSONSerialization.data(withJSONObject: inv, options: [])
//         return try JSONDecoder().decode(NumbersParserInvoiceData.self, from: jsonData)
//     }

//     public static func export(
//         invoiceId: String, 
//         close: Bool = false,
//         returnToResponder: Bool = false
//     ) throws {
//         try executeNumbersParser(
//             invoiceId: invoiceId,
//             close: close,
//             returnToResponder: returnToResponder
//         )
//     }
// }

// public func executeNumbersParser(invoiceId: String, close: Bool, returnToResponder: Bool) throws {
//     do {
//         let home = Home.string()
//         let process = Process()
//         process.executableURL = URL(fileURLWithPath: "/bin/zsh") // Use Zsh directly

//         let base = "source ~/.zprofile && \(home)/sbm-bin/numbers-parser --close \(close) --adjust-before-exporting --value \(invoiceId)"
//         let cmd = returnToResponder ? base + " --responder" : base

//         process.arguments = ["-c", cmd]
        
//         let outputPipe = Pipe()
//         let errorPipe = Pipe()
//         process.standardOutput = outputPipe
//         process.standardError = errorPipe

//         try process.run()
//         process.waitUntilExit()

//         let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
//         let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
//         let outputString = String(data: outputData, encoding: .utf8) ?? ""
//         let errorString = String(data: errorData, encoding: .utf8) ?? ""

//         if process.terminationStatus == 0 {
//             print("numbers-parser executed successfully:\n\(outputString)")
//         } else {
//             print("Error running numbers-parser:\n\(errorString)")
//             throw NSError(domain: "numbers-parser", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorString])
//         }
//     } catch {
//         print("Error running numbers-parser: \(error)")
//         throw error
//     }
// }
