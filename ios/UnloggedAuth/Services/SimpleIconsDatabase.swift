import Foundation

/// Loads the bundled Simple Icons database and provides fast issuer-to-icon matching.
/// Uses the same matching strategy as Ente Auth: exact slug match, alias match,
/// normalized prefix match, and word-based fuzzy matching.
struct SimpleIconsDatabase: Sendable {

    struct IconEntry: Identifiable, Sendable {
        let id: String       // slug (unique, used for CDN URL)
        let title: String    // display name
        let slug: String
        let hex: String      // brand color (no #)
        let aliases: [String]
    }

    /// All icons sorted by title.
    let icons: [IconEntry]

    /// Lookup index: lowercased slug -> IconEntry
    private let slugIndex: [String: IconEntry]

    /// Lookup index: lowercased/normalized names (title, aliases, stripped) -> slug
    private let nameIndex: [String: String]

    // MARK: - Loading

    static let shared: SimpleIconsDatabase = {
        guard let url = Bundle.main.url(forResource: "simple-icons", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return SimpleIconsDatabase(icons: [], slugIndex: [:], nameIndex: [:])
        }

        struct RawEntry: Decodable {
            let t: String   // title
            let s: String   // slug
            let h: String   // hex
            let a: [String]? // aliases (aka)
        }

        guard let raw = try? JSONDecoder().decode([RawEntry].self, from: data) else {
            return SimpleIconsDatabase(icons: [], slugIndex: [:], nameIndex: [:])
        }

        var entries: [IconEntry] = []
        var slugIdx: [String: IconEntry] = [:]
        var nameIdx: [String: String] = [:]

        for item in raw {
            let entry = IconEntry(
                id: item.s,
                title: item.t,
                slug: item.s,
                hex: item.h,
                aliases: item.a ?? []
            )
            entries.append(entry)
            slugIdx[item.s] = entry

            // Index by slug
            nameIdx[item.s] = item.s

            // Index by normalized title
            let normTitle = normalize(item.t)
            nameIdx[normTitle] = item.s

            // Index by lowercased title
            nameIdx[item.t.lowercased()] = item.s

            // Index by aliases
            for alias in item.a ?? [] {
                nameIdx[normalize(alias)] = item.s
                nameIdx[alias.lowercased()] = item.s
            }
        }

        let sorted = entries.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }

        return SimpleIconsDatabase(icons: sorted, slugIndex: slugIdx, nameIndex: nameIdx)
    }()

    // MARK: - Lookup

    /// Find the best matching icon for an issuer name.
    /// Tries: exact slug, exact title, normalized match, prefix match, word match.
    func lookup(issuer: String) -> IconEntry? {
        let raw = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        let lowered = raw.lowercased()
        let normalized = Self.normalize(raw)

        // 1. Exact match on slug or normalized name
        if let slug = nameIndex[normalized], let entry = slugIndex[slug] {
            return entry
        }
        if let slug = nameIndex[lowered], let entry = slugIndex[slug] {
            return entry
        }
        if let entry = slugIndex[normalized] {
            return entry
        }

        // 2. Strip common suffixes (like Ente does)
        let stripped = Self.stripCommonSuffixes(normalized)
        if stripped != normalized {
            if let slug = nameIndex[stripped], let entry = slugIndex[slug] {
                return entry
            }
        }

        // 3. Prefix match: issuer starts with a known name
        //    e.g. "Google Workspace" -> "google"
        for (name, slug) in nameIndex {
            if name.count >= 3 && normalized.hasPrefix(name) {
                if let entry = slugIndex[slug] { return entry }
            }
        }

        // 4. Known name starts with issuer (short issuer matches longer slug)
        //    e.g. "AWS" might not be a slug, but check aliases
        for (name, slug) in nameIndex {
            if normalized.count >= 2 && name.hasPrefix(normalized) && name.count <= normalized.count + 5 {
                if let entry = slugIndex[slug] { return entry }
            }
        }

        return nil
    }

    /// Search icons by query (for the icon picker).
    func search(query: String) -> [IconEntry] {
        guard !query.isEmpty else { return icons }
        let q = query.lowercased()
        return icons.filter { entry in
            entry.title.lowercased().contains(q) ||
            entry.slug.contains(q) ||
            entry.aliases.contains { $0.lowercased().contains(q) }
        }
    }

    // MARK: - Normalization

    /// Normalize a name for matching: lowercase, strip non-alphanumeric, apply replacements.
    /// Mirrors the Simple Icons slugging algorithm.
    static func normalize(_ input: String) -> String {
        var s = input.lowercased()

        // Simple Icons slug replacements
        s = s.replacingOccurrences(of: "+", with: "plus")
        s = s.replacingOccurrences(of: ".", with: "dot")
        s = s.replacingOccurrences(of: "&", with: "and")

        // Unicode normalization (NFD) then strip non-ascii
        s = s.decomposedStringWithCanonicalMapping

        // Remove everything except a-z, 0-9
        s = String(s.unicodeScalars.filter { scalar in
            (scalar.value >= 0x61 && scalar.value <= 0x7A) || // a-z
            (scalar.value >= 0x30 && scalar.value <= 0x39)    // 0-9
        })

        return s
    }

    /// Strip common authenticator suffixes.
    private static func stripCommonSuffixes(_ name: String) -> String {
        let suffixes = [
            "authenticator", "auth", "2fa", "account", "login",
            "security", "verification", "app", "mfa", "totp",
            "twofactor", "identity", "sso"
        ]
        var result = name
        for suffix in suffixes {
            if result.hasSuffix(suffix) && result.count > suffix.count {
                result = String(result.dropLast(suffix.count))
            }
        }
        return result
    }
}
