import Foundation
import SwiftUI
import Contacts
import plate

enum ContactsError: LocalizedError {
    case accessDenied
    case underlying(Error)
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Contacts access was denied by the user."
        case .underlying(let e):
            return e.localizedDescription
        }
    }
}

public func requestContactsAccess() async throws {
    let store = CNContactStore()
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        store.requestAccess(for: .contacts) { granted, error in
            if let error = error {
                continuation.resume(throwing: ContactsError.underlying(error))
            } else if !granted {
                continuation.resume(throwing: ContactsError.accessDenied)
            } else {
                continuation.resume(returning: ())
            }
        }
    }
}

public func fetchContacts() throws -> [CNContact] {
    let store = CNContactStore()
    let keys: [CNKeyDescriptor] = [
        CNContactGivenNameKey,
        CNContactFamilyNameKey,
        CNContactEmailAddressesKey,
        CNContactPostalAddressesKey
    ] as [CNKeyDescriptor]
    
    let request = CNContactFetchRequest(keysToFetch: keys)
    var results: [CNContact] = []
    
    do {
        try store.enumerateContacts(with: request) { contact, _ in
            results.append(contact)
        }
        return results
    } catch {
        throw ContactsError.underlying(error)
    }
}

// @MainActor
nonisolated // make nonisolated so it can be called on any thread
public func loadContacts() async throws -> [CNContact] {
    try await requestContactsAccess()
    return try fetchContacts()
}

// extension CNContactStore {
//     /// Requests access to Contacts, then fetches and returns them.
//     /// - Throws: `ContactsError.accessDenied` if the user refuses,
//     ///           or `ContactsError.underlying(_)` for any fetch error.
//     public func fetchContacts() async throws -> [CNContact] {
//         // 1. Ask permission
//         let granted = try await withCheckedThrowingContinuation { cont in
//             requestAccess(for: .contacts) { granted, error in
//                 if let error = error {
//                     cont.resume(throwing: ContactsError.underlying(error))
//                 } else if !granted {
//                     cont.resume(throwing: ContactsError.accessDenied)
//                 } else {
//                     cont.resume(returning: true)
//                 }
//             }
//         }
        
//         // 2. If granted, enumerate
//         guard granted else {
//             // (should never hit, since we threw on !granted above)
//             throw ContactsError.accessDenied
//         }

//         let keys: [CNKeyDescriptor] = [
//             CNContactGivenNameKey,
//             CNContactFamilyNameKey,
//             CNContactEmailAddressesKey,
//             CNContactPostalAddressesKey
//         ] as [CNKeyDescriptor]
        
//         let request = CNContactFetchRequest(keysToFetch: keys)
//         var results: [CNContact] = []
        
//         do {
//             try enumerateContacts(with: request) { contact, _ in
//                 results.append(contact)
//             }
//             return results
//         } catch {
//             throw ContactsError.underlying(error)
//         }
//     }
// }
