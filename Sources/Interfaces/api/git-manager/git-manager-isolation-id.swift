import CryptoKit
import Foundation

public struct GitManagerIsolationID:
    Sendable,
    Codable,
    Hashable,
    CustomStringConvertible
{
    public let semanticKey: String

    public init(
        _ semanticKey: String
    ) throws {
        let semanticKey = semanticKey.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !semanticKey.isEmpty else {
            throw GitManagerIsolationIDError.emptySemanticKey
        }

        self.semanticKey = semanticKey
    }

    public var slug: String {
        Self.slug(
            semanticKey
        )
    }

    public var digest: String {
        let bytes = SHA256.hash(
            data: Data(
                semanticKey.utf8
            )
        )

        return bytes
            .prefix(6)
            .map {
                String(
                    format: "%02x",
                    $0
                )
            }
            .joined()
    }

    public var value: String {
        "\(slug)-\(digest)"
    }

    public var description: String {
        value
    }

    public func branchName(
        prefix: String = "agentic"
    ) -> String {
        let prefix = Self.slug(
            prefix
        )

        guard !prefix.isEmpty else {
            return value
        }

        return "\(prefix)/\(value)"
    }

    public var pathComponent: String {
        value
    }
}

public enum GitManagerIsolationIDError:
    Error,
    LocalizedError,
    Sendable,
    Equatable
{
    case emptySemanticKey

    public var errorDescription: String? {
        switch self {
        case .emptySemanticKey:
            return "Git isolation semantic key cannot be empty."
        }
    }
}

private extension GitManagerIsolationID {
    static func slug(
        _ value: String
    ) -> String {
        var result = ""
        var pendingDash = false

        for scalar in value
            .lowercased()
            .unicodeScalars
        {
            let code = scalar.value
            let isLowercaseASCII = (97...122).contains(code)
            let isDigitASCII = (48...57).contains(code)

            if isLowercaseASCII || isDigitASCII {
                if pendingDash,
                   !result.isEmpty
                {
                    result.append("-")
                }

                pendingDash = false
                result.unicodeScalars.append(
                    scalar
                )
            } else {
                pendingDash = true
            }

            if result.count >= 48 {
                break
            }
        }

        return result
            .trimmingCharacters(
                in: CharacterSet(
                    charactersIn: "-"
                )
            )
    }
}
