import Foundation
import Combine
import SwiftUI

@MainActor
public class VariableStore: ObservableObject, Sendable {
    public static let shared = VariableStore()

    /// maps the variable-names used by your payload structs
    /// (e.g. "name", "dog", "client_name", "invoice_id", etc.)
    @Published public var values: [String: String] = [:]

    public init() {}

    // private init() {
    //   // Optionally pre-populate defaults here
    // }
}

// @MainActor
// @propertyWrapper
// public struct StoredVariable {
//     public let key: String
//     @ObservedObject private var store: VariableStore

//     public var wrappedValue: String {
//         get { store.values[key] ?? "" }
//         nonmutating set { store.values[key] = newValue }
//     }

//     /// You can still override the store if you ever need multiple stores;
//     /// but by default it uses singleton.
//     public init(
//       key: String,
//       store: VariableStore = .shared
//     ) {
//         self.key   = key
//         self.store = store
//     }
// }

@MainActor
@propertyWrapper
public struct StoredVariable: DynamicProperty {
    public let key: String

    // Grab the store out of SwiftUI’s environment
    @EnvironmentObject private var store: VariableStore

    public var wrappedValue: String {
        get { store.values[key, default: ""] }
        nonmutating set { store.values[key] = newValue }
    }

    public init(key: String) {
        self.key = key
    }
}
