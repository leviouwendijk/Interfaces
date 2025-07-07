import Foundation
import SwiftUI
import Contacts
import plate
import Extensions

extension String {
    public func extractClientDog() throws -> MailerAPIClientVariable {
        try splitClientDog(from: self)
    }
}

extension String {
    nonisolated // make nonisolated so it can be called on any thread
    public func filteredClientContacts(
        uponEmptyReturn: EmptyQueryBehavior = .all,
        fuzzyTolerance: Int = 2
    ) async throws -> [CNContact] {
        let allContacts = try await loadContacts()

        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (uponEmptyReturn == .all) ? allContacts : []
        }

        let tokens = trimmed
            .normalizedForClientDogSearch
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        return allContacts.filter { contact in
            let haystack = contact.searchableWords()

            return tokens.allSatisfy { token in
                haystack.contains(where: { word in
                    if word.contains(token) { return true }
                    return word.levenshteinDistance(to: token) <= fuzzyTolerance
                })
            }
        }
    }
}
