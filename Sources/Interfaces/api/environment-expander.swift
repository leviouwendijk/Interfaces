import Foundation

/// Case-insensitive dictionary wrap (lowercases keys on write, case-insensitive read).
internal struct CIEnv {
    internal var store: [String: String] = [:]

    init(_ base: [String: String] = [:]) {
        for (k, v) in base { store[k.lowercased()] = v }
    }

    subscript(key: String) -> String? {
        get { store[key.lowercased()] }
        set { store[key.lowercased()] = newValue }
    }

    mutating func merge(_ other: [String: String]) {
        for (k, v) in other { store[k.lowercased()] = v }
    }

    func asDictionary() -> [String: String] { store }
}

internal enum EnvironmentExpander {
    /// Expand a single string using chained resolution (up to `maxPasses`) and record matches (lowercased).
    static func expand(
        _ raw: String,
        with mergedEnv: CIEnv,
        matches: inout [String: String],
        maxPasses: Int = 8
    ) -> String {
        // 1) ~ expansion
        var s = (raw as NSString).expandingTildeInPath

        // 2) iterative $-expansion to resolve chains
        let env = mergedEnv
        for _ in 0..<maxPasses {
            let (next, changed) = expandOnce(s, env: env, matches: &matches)
            s = next
            if !changed { break }
        }
        return s
    }

    /// Expand a single pass (no recursion) over `input`, replacing $VAR / ${VAR} using `env`.
    /// Returns (expandedString, didChange).
    internal static func expandOnce(
        _ input: String,
        env: CIEnv,
        matches: inout [String: String]
    ) -> (String, Bool) {
        var out = String()
        out.reserveCapacity(input.count + 16)

        let scalars = Array(input.unicodeScalars)
        var i = 0
        var changed = false

        @inline(__always)
        func isIdentStart(_ u: UnicodeScalar) -> Bool {
            (u == "_") || ("A"..."Z" ~= u) || ("a"..."z" ~= u)
        }
        @inline(__always)
        func isIdentCont(_ u: UnicodeScalar) -> Bool {
            isIdentStart(u) || ("0"..."9" ~= u)
        }

        while i < scalars.count {
            let u = scalars[i]

            if u == "$" {
                // Try ${VAR}
                if i + 1 < scalars.count, scalars[i + 1] == "{" {
                    var j = i + 2
                    var nameScalars: [UnicodeScalar] = []
                    if j < scalars.count, isIdentStart(scalars[j]) {
                        nameScalars.append(scalars[j]); j += 1
                        while j < scalars.count, isIdentCont(scalars[j]) {
                            nameScalars.append(scalars[j]); j += 1
                        }
                    }
                    // Expect closing "}"
                    if j < scalars.count, scalars[j] == "}" {
                        let name = String(String.UnicodeScalarView(nameScalars))
                        if let val = env[name] {
                            out.unicodeScalars.append(contentsOf: val.unicodeScalars)
                            matches[name.lowercased()] = val
                            changed = true
                            i = j + 1
                            continue
                        } else {
                            // Unknown; keep literal as-is
                            out.unicodeScalars.append(contentsOf: scalars[i...j])
                            i = j + 1
                            continue
                        }
                    } else {
                        // No closing brace; treat literally
                        out.unicodeScalars.append(u)
                        i += 1
                        continue
                    }
                }

                // Try $VAR
                if i + 1 < scalars.count, isIdentStart(scalars[i + 1]) {
                    var j = i + 2
                    while j < scalars.count, isIdentCont(scalars[j]) { j += 1 }
                    let name = String(String.UnicodeScalarView(scalars[(i + 1)..<j]))
                    if let val = env[name] {
                        out.unicodeScalars.append(contentsOf: val.unicodeScalars)
                        matches[name.lowercased()] = val
                        changed = true
                        i = j
                        continue
                    } else {
                        // Unknown; keep literal
                        out.unicodeScalars.append(contentsOf: scalars[i..<j])
                        i = j
                        continue
                    }
                }

                // Lone "$"
                out.unicodeScalars.append(u)
                i += 1
            } else {
                out.unicodeScalars.append(u)
                i += 1
            }
        }

        return (out, changed)
    }
}
