import Foundation

nonisolated enum ImportSource: String, Sendable, CaseIterable, Identifiable {
    case googleAuthenticator = "Google Authenticator"
    case authy = "Authy"
    case microsoftAuthenticator = "Microsoft Authenticator"
    case enteAuth = "ente Auth"
    case twoFAS = "2FAS"
    case bitwarden = "Bitwarden"
    case otpauthURI = "otpauth:// URI"
    case jsonFile = "JSON File"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .googleAuthenticator: return "g.circle.fill"
        case .authy: return "shield.checkered"
        case .microsoftAuthenticator: return "m.circle.fill"
        case .enteAuth: return "e.circle.fill"
        case .twoFAS: return "2.circle.fill"
        case .bitwarden: return "b.circle.fill"
        case .otpauthURI: return "link"
        case .jsonFile: return "doc.text"
        }
    }

    var instructions: String {
        switch self {
        case .googleAuthenticator:
            return "Export from Google Authenticator → Transfer accounts → Export. Screenshot or scan the QR codes, or use the exported file."
        case .authy:
            return "Authy doesn't provide direct export. Use a third-party tool to extract tokens as otpauth:// URIs, then paste them here."
        case .microsoftAuthenticator:
            return "Microsoft Authenticator backup can be restored via cloud sync. For manual transfer, re-scan QR codes from your services."
        case .enteAuth:
            return "In ente Auth, go to Settings → Data → Export. Save the JSON file and import it here."
        case .twoFAS:
            return "In 2FAS, go to Settings → 2FAS Backup → Export. Save the file and import it here."
        case .bitwarden:
            return "In Bitwarden Authenticator, go to Settings → Export. Save the JSON file and import it here."
        case .otpauthURI:
            return "Paste one or more otpauth:// URIs, one per line."
        case .jsonFile:
            return "Import a JSON file containing token data."
        }
    }
}

@MainActor
enum ImportService {

    // MARK: - Smart Import (auto-detects format)

    static func smartImport(_ data: Data) -> [OTPToken] {
        // 1. Try as plain text with otpauth:// URIs
        if let text = String(data: data, encoding: .utf8) {
            let uriTokens = parseURIs(text)
            if !uriTokens.isEmpty { return uriTokens }
        }

        // 2. Try as JSON with known structures
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // 2a. 2FAS format: { "services": [...] }
            if let services = json["services"] as? [[String: Any]] {
                let tokens = services.compactMap { parseTwoFASService($0) }
                if !tokens.isEmpty { return tokens }
            }

            // 2b. ente Auth / Raivo: { "items": [...] } with rawData or otpauth URIs
            if let items = json["items"] as? [[String: Any]] {
                // Try ente format (rawData field with otpauth URIs)
                let enteTokens = items.compactMap { item -> OTPToken? in
                    if let uri = item["rawData"] as? String, uri.hasPrefix("otpauth://") {
                        return OTPAuthParser.parse(uri: uri)
                    }
                    return nil
                }
                if !enteTokens.isEmpty { return enteTokens }

                // Try Bitwarden format (login.totp field)
                let bitwardenTokens = items.compactMap { item -> OTPToken? in
                    guard let login = item["login"] as? [String: Any],
                          let totp = login["totp"] as? String, !totp.isEmpty else { return nil }
                    if totp.hasPrefix("otpauth://") {
                        return OTPAuthParser.parse(uri: totp)
                    }
                    return OTPToken(
                        issuer: item["name"] as? String ?? "",
                        account: (login["username"] as? String) ?? "",
                        secret: totp.uppercased()
                    )
                }
                if !bitwardenTokens.isEmpty { return bitwardenTokens }

                // Try generic items with secret field
                let genericItems = items.compactMap { parseDictAsToken($0) }
                if !genericItems.isEmpty { return genericItems }
            }

            // 2c. Try common wrapper keys
            for key in ["tokens", "accounts", "entries", "data"] {
                if let arr = json[key] as? [[String: Any]] {
                    let tokens = arr.compactMap { parseDictAsToken($0) }
                    if !tokens.isEmpty { return tokens }
                }
            }

            // 2d. Scan all string values for otpauth:// URIs
            let uriTokens = extractURIsFromJSON(json)
            if !uriTokens.isEmpty { return uriTokens }
        }

        // 3. Try as JSON array
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            // Try as 2FAS service array
            let twoFASTokens = arr.compactMap { parseTwoFASService($0) }
            if !twoFASTokens.isEmpty { return twoFASTokens }

            // Try as generic token array
            let tokens = arr.compactMap { parseDictAsToken($0) }
            if !tokens.isEmpty { return tokens }
        }

        // 4. Try decoding as our own formats
        if let tokens = try? JSONDecoder().decode([OTPToken].self, from: data) {
            return tokens
        }
        if let payload = try? JSONDecoder().decode(ExportPayload.self, from: data) {
            return payload.tokens
        }

        return []
    }

    // MARK: - URI Parsing

    static func parseURIs(_ text: String) -> [OTPToken] {
        let lines = text.components(separatedBy: .newlines)
        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("otpauth://") else { return nil }
            return OTPAuthParser.parse(uri: trimmed)
        }
    }

    // MARK: - Dictionary Parsers

    private static func parseTwoFASService(_ service: [String: Any]) -> OTPToken? {
        guard let secret = service["secret"] as? String ?? (service["otp"] as? [String: Any])?["secret"] as? String,
              !secret.isEmpty else { return nil }

        let name = service["name"] as? String ?? ""
        let issuer = service["issuer"] as? String ?? name

        let otp = service["otp"] as? [String: Any]
        let typeStr = (otp?["tokenType"] as? String ?? service["type"] as? String ?? "TOTP").lowercased()
        let algStr = (otp?["algorithm"] as? String ?? "SHA1").lowercased()
        let digits = otp?["digits"] as? Int ?? 6
        let period = otp?["period"] as? Int ?? 30
        let counter = otp?["counter"] as? Int ?? 0

        return OTPToken(
            issuer: issuer,
            account: service["account"] as? String ?? name,
            secret: secret.uppercased(),
            type: typeStr.contains("hotp") ? .hotp : .totp,
            algorithm: parseAlgorithm(algStr),
            digits: digits,
            period: period,
            counter: UInt64(counter)
        )
    }

    private static func parseDictAsToken(_ dict: [String: Any]) -> OTPToken? {
        // Try otpauth URI in common fields
        for key in ["rawData", "uri", "otpauth", "url", "totp"] {
            if let uri = dict[key] as? String, uri.hasPrefix("otpauth://") {
                return OTPAuthParser.parse(uri: uri)
            }
        }

        // Try direct secret field
        guard let secret = dict["secret"] as? String ?? dict["key"] as? String,
              !secret.isEmpty else { return nil }

        let typeStr = (dict["type"] as? String ?? dict["tokenType"] as? String ?? "totp").lowercased()
        let algStr = (dict["algorithm"] as? String ?? "sha1").lowercased()

        return OTPToken(
            issuer: dict["issuer"] as? String ?? dict["name"] as? String ?? dict["service"] as? String ?? "",
            account: dict["account"] as? String ?? dict["email"] as? String ?? dict["username"] as? String ?? "",
            secret: secret.uppercased(),
            type: typeStr.contains("hotp") ? .hotp : .totp,
            algorithm: parseAlgorithm(algStr),
            digits: dict["digits"] as? Int ?? 6,
            period: dict["period"] as? Int ?? 30,
            counter: (dict["counter"] as? Int).map { UInt64($0) } ?? dict["counter"] as? UInt64 ?? 0
        )
    }

    private static func extractURIsFromJSON(_ json: Any) -> [OTPToken] {
        var tokens: [OTPToken] = []
        if let str = json as? String, str.hasPrefix("otpauth://") {
            if let token = OTPAuthParser.parse(uri: str) { tokens.append(token) }
        } else if let dict = json as? [String: Any] {
            for value in dict.values { tokens.append(contentsOf: extractURIsFromJSON(value)) }
        } else if let arr = json as? [Any] {
            for value in arr { tokens.append(contentsOf: extractURIsFromJSON(value)) }
        }
        return tokens
    }

    private static func parseAlgorithm(_ str: String) -> OTPAlgorithm {
        switch str.lowercased() {
        case "sha256": return .sha256
        case "sha512": return .sha512
        default: return .sha1
        }
    }
}
