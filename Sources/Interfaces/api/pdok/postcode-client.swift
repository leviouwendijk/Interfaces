import Foundation

public struct PostcodeClient {
    public var session: URLSession
    public let baseURL: URL

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.pdok.nl/bzk/locatieserver/search/v3_1/suggest")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    public func isValidInput(postcode: String, huisnummer: String) -> Bool {
        let trimmedNum = huisnummer.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedNum.isEmpty && normalizedPostcode(postcode) != nil
    }

    /// Return compact "1816PN" if valid, else nil.
    public func normalizedPostcode(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let compact = s.replacingOccurrences(of: " ", with: "")
        guard compact.count == 6 else { return nil }
        let first4 = compact.prefix(4)
        let last2  = compact.suffix(2)
        guard first4.allSatisfy(\.isNumber), last2.allSatisfy(\.isLetter) else { return nil }
        return compact.uppercased()
    }

    public func decodePDOKModel(data: Data) throws -> PDOKSuggestResponse {
        do {
            return try JSONDecoder().decode(PDOKSuggestResponse.self, from: data)
        } catch {
            throw PostcodeClientError.decodeError(error)
        }
    }

    /// Returns the full decoded PDOK suggest response.
    public func fetchSuggest(postcode: String, huisnummer: String) async throws -> Data {
        guard isValidInput(postcode: postcode, huisnummer: huisnummer),
              let normalized = normalizedPostcode(postcode) else {
            throw PostcodeClientError.invalidInput
        }

        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        comps?.queryItems = [ URLQueryItem(name: "q", value: "\(normalized) \(huisnummer)") ]

        guard let url = comps?.url else { throw PostcodeClientError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 10
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw PostcodeClientError.httpError(status: http.statusCode)
        }

        return data
    }

    /// First doc convenience.
    public func fetchFirstDoc(postcode: String, huisnummer: String) async throws -> PDOKDoc {
        let full = try await fetchSuggest(postcode: postcode, huisnummer: huisnummer)
        let pdok = try decodePDOKModel(data: full)
        if let doc = pdok.response.docs?.first { return doc }
        throw PostcodeClientError.noResults
    }

    /// comma parts, strip postcode tokens, rest = woonplaats.
    public static func extractWoonplaats(from weergavenaam: String) -> String {
        let parts = weergavenaam.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count > 1 else { return "Onbekend" }

        var tokens = parts[1].split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return "Onbekend" }

        func isFourDigits(_ s: String) -> Bool { s.count == 4 && s.allSatisfy(\.isNumber) }
        func isTwoLetters(_ s: String) -> Bool { s.count == 2 && s.allSatisfy(\.isLetter) }
        func isCompactPostcode(_ s: String) -> Bool {
            let c = s.replacingOccurrences(of: " ", with: "")
            guard c.count == 6 else { return false }
            return c.prefix(4).allSatisfy(\.isNumber) && c.suffix(2).allSatisfy(\.isLetter)
        }

        if isCompactPostcode(tokens[0]) {
            tokens.removeFirst()
        } else if tokens.count >= 2 && isFourDigits(tokens[0]) && isTwoLetters(tokens[1]) {
            tokens.removeFirst(2)
        } else if isFourDigits(tokens[0]) {
            tokens.removeFirst()
        }

        let woonplaats = tokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return woonplaats.isEmpty ? "Onbekend" : woonplaats
    }

    /// Street name before the first trailing number token.
    public static func extractStreetName(from weergavenaam: String) -> String {
        let parts = weergavenaam.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let streetPart = parts.first, !streetPart.isEmpty else { return "Onbekend" }

        let tokens = streetPart.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return "Onbekend" }

        var indexOfNumberStart: Int? = nil
        for (idx, token) in tokens.enumerated().reversed() {
            if let c = token.first, c.isNumber { indexOfNumberStart = idx } else if indexOfNumberStart != nil { break }
        }

        let streetTokens: [String]
        if let numIdx = indexOfNumberStart, numIdx > 0 {
            streetTokens = Array(tokens[0..<numIdx])
        } else if indexOfNumberStart == nil {
            streetTokens = tokens
        } else {
            streetTokens = []
        }

        let street = streetTokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return street.isEmpty ? "Onbekend" : street
    }
}

