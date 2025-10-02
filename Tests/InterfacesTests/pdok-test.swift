import Testing
import Foundation
import Interfaces

@Suite("PDOKClient")
struct PDOKClientTests {
    let client = PostcodeClient()

    @Test("Valid PDOK suggest returns raw JSON and decodes")
    func validSuggestDecodes() async throws {
        let data = try await client.fetchSuggest(postcode: "1873hv", huisnummer: "51")

        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        #expect((jsonObject as? [String: Any])?["response"] != nil, "Expected top-level 'response' key")

        let model = try client.decodePDOKModel(data: data)
        #expect((model.response.numFound ?? 0) > 0, "numFound should be > 0")
        #expect(!(model.response.docs?.isEmpty ?? true), "docs should not be empty")

        if let name = model.response.docs?.first?.weergavenaam {
            let street = PostcodeClient.extractStreetName(from: name)
            let place  = PostcodeClient.extractWoonplaats(from: name)
            #expect(!street.isEmpty, "Street should not be empty")
            #expect(!place.isEmpty, "Woonplaats should not be empty")
        } else {
            Issue.record("No weergavenaam present in first doc")
        }
    }

    @Test("Invalid input fails with .invalidInput")
    func invalidSuggestFails() async {
        do {
            _ = try await client.fetchSuggest(postcode: "18 16", huisnummer: "")
            Issue.record("Expected .invalidInput error but call succeeded")
        } catch let err as PostcodeClientError {
            switch err {
            case .invalidInput:
                break
            default:
                Issue.record("Expected .invalidInput, got \(err)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
