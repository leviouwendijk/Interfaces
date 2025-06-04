// import Foundation

// // 1️⃣ Create the HTTP client (will pull API key & base-URL from your env)
// let client = MailerAPIClient()

// // 2️⃣ Build your payload
// do {
//     let payload = try LeadPayload(
//         endpoint:    .lead,                     // or whatever your enum case is
//         client:      "Jane Doe",
//         dog:         "Fido",
//         // if you have availability data:
//         // availability: .init(start:…, end:…),
//         emailsTo:    ["jane@example.com"],      // to-field
//         emailsCC:    [],                        // cc-field
//         emailsBCC:   [],                        // bcc-field
//         replyTo:     ["support@example.com"],   // replyTo
//         attachments: nil,                       // or an array of MailerAPIEmailAttachment
//         addHeaders:  ["X-My-Header":"value"]    // any custom headers
//     )

//     // 3️⃣ Send it
//     client.send(payload) { result in
//         switch result {
//         case .success(let data):
//             // The server’s JSON-response lives in `data`. If it’s JSON, decode it here:
//             print("Success, got \(data.count) bytes back")
//             if
//                 let json = try? JSONSerialization.jsonObject(with: data, options: []),
//                 let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
//                 let str = String(data: pretty, encoding: .utf8)
//             {
//                 print(str)
//             }

//         case .failure(let error):
//             print("Error sending lead payload:", error)
//         }
//     }

// } catch {
//     // Thrown if your payload init fails (e.g. bad file path in attachments)
//     print("Failed to construct payload:", error)
// }
