import Foundation
import plate

public enum ApplicationEnvironmentLoaderError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidConfigLine(String)
    case missingEnv(String)

    public var errorDescription: String? {
        switch self {
        case .missingEnv(let key):
            return "Missing environment variable for key \(key)"
        case .invalidConfigLine(let line):
            return "Invalid configuration line: \(line)"
        case .fileNotFound(let path):
            return "File not found at \(path)"
        }
    }
}

public enum ApplicationEnvironmentActorError: Error, LocalizedError {
    case missingEnv(String)

    public var errorDescription: String? {
        switch self {
        case .missingEnv(let key):
            return "Missing environment variable for key \(key)"
        }
    }
}

public struct ApplicationEnvironmentLoader {
    // public static func load(from filePath: String) throws -> [String: String] {
    //     let url = URL(fileURLWithPath: filePath)
    //     guard FileManager.default.fileExists(atPath: url.path) else {
    //         throw ApplicationEnvironmentLoaderError.fileNotFound(filePath)
    //     }
        
    //     let raw = try String(contentsOf: url, encoding: .utf8)
    //     var result: [String: String] = [:]
        
    //     for line in raw.components(separatedBy: .newlines) {
    //         let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    //         guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            
    //         let parts = trimmed
    //         .strippingExportPrefix()
    //         .split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)

    //         guard parts.count == 2 else {
    //             throw ApplicationEnvironmentLoaderError.invalidConfigLine(trimmed)
    //         }
            
    //         let key = parts[0]
    //         .trimmingCharacters(in: .whitespaces)

    //         let value = parts[1]
    //         .trimmingCharacters(in: .whitespaces)
    //         .replacingShellHomeVariable()
    //         .strippingEnclosingQuotes()

    //         result[key] = value
    //     }
        
    //     return result
    // }

    public static func load(from filePath: String) throws -> [String: String] {
        let url = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ApplicationEnvironmentLoaderError.fileNotFound(filePath)
        }

        let raw = try String(contentsOf: url, encoding: .utf8)
        var rawMap: [String: String] = [:]

        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let parts = trimmed
                .strippingExportPrefix()
                .split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)

            guard parts.count == 2 else {
                throw ApplicationEnvironmentLoaderError.invalidConfigLine(trimmed)
            }

            let key = parts[0]
            .trimmingCharacters(in: .whitespaces)

            let valueRaw = String(parts[1])
                .trimmingCharacters(in: .whitespaces)
                .replacingShellHomeVariable()
                .strippingEnclosingQuotes()

            rawMap[key] = valueRaw
        }

        var expanded: [String: String] = [:]
        var matches: [String: String] = [:] 

        let processEnv = CIEnv(ProcessInfo.processInfo.environment)
        let fileEnv    = CIEnv(rawMap)

        for _ in 0..<8 {
            var changed = false
            for (k, v) in rawMap {
                // Merge precedence: expanded-so-far → raw file → process env
                var merged = processEnv
                merged.merge(expanded)
                merged.merge(fileEnv.asDictionary())

                let before = expanded[k]
                let after  = EnvironmentExpander.expand(v, with: merged, matches: &matches, maxPasses: 8)
                if before != after {
                    expanded[k] = after
                    changed = true
                }
            }
            if !changed { break }
        }

        // for storing vars were referenced, stash `matches` somewhere.
        // ApplicationEnvMatches.set(matches) // optional

        return expanded
    }
    
    public static func set(to loadedDictionary: [String: String]) {
        for (key, value) in loadedDictionary {
            setenv(key, value, 1)
        }
    }
}

public struct ApplicationEnvironmentActor {
    public let environmentFile: String // environment filepath

    public init(
        environmentFile: String
    ) throws {
        self.environmentFile = environmentFile
        let dictionary = try ApplicationEnvironmentLoader.load(from: environmentFile)
        ApplicationEnvironmentLoader.set(to: dictionary)
    }

    public static func get(key: String) throws -> String {
        guard let raw = ProcessInfo.processInfo.environment[key],
            !raw.isEmpty
        else {
            throw ApplicationEnvironmentActorError.missingEnv(key)
        }
        return raw
    }
}
