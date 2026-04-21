import Foundation

nonisolated enum OTPAuthParser: Sendable {

    static func parse(uri: String) -> OTPToken? {
        guard let url = URL(string: uri),
              url.scheme == "otpauth" else { return nil }

        let typeString = url.host ?? ""
        guard let type = OTPType(rawValue: typeString) else { return nil }

        let rawPath = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
        let path = rawPath.replacingOccurrences(of: "+", with: " ")
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        let secret = queryItems.first(where: { $0.name == "secret" })?.value ?? ""
        guard !secret.isEmpty else { return nil }

        let issuer = (queryItems.first(where: { $0.name == "issuer" })?.value ?? "").replacingOccurrences(of: "+", with: " ")
        let algorithmStr = queryItems.first(where: { $0.name == "algorithm" })?.value?.lowercased() ?? "sha1"
        let digitsStr = queryItems.first(where: { $0.name == "digits" })?.value ?? "6"
        let periodStr = queryItems.first(where: { $0.name == "period" })?.value ?? "30"
        let counterStr = queryItems.first(where: { $0.name == "counter" })?.value ?? "0"

        let algorithm: OTPAlgorithm
        switch algorithmStr {
        case "sha256": algorithm = .sha256
        case "sha512": algorithm = .sha512
        default: algorithm = .sha1
        }

        let digits = Int(digitsStr) ?? 6
        let period = Int(periodStr) ?? 30
        let counter = UInt64(counterStr) ?? 0

        var account = path
        var resolvedIssuer = issuer
        if path.contains(":") {
            let parts = path.split(separator: ":", maxSplits: 1)
            if resolvedIssuer.isEmpty {
                resolvedIssuer = String(parts[0]).trimmingCharacters(in: .whitespaces)
            }
            if parts.count > 1 {
                account = String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }

        return OTPToken(
            issuer: resolvedIssuer,
            account: account,
            secret: secret.uppercased(),
            type: type,
            algorithm: algorithm,
            digits: digits,
            period: period,
            counter: counter
        )
    }

    static func buildURI(from token: OTPToken) -> String {
        var components = URLComponents()
        components.scheme = "otpauth"
        components.host = token.type.rawValue
        let label = token.issuer.isEmpty ? token.account : "\(token.issuer):\(token.account)"
        components.path = "/\(label)"
        var items = [
            URLQueryItem(name: "secret", value: token.secret),
            URLQueryItem(name: "algorithm", value: token.algorithm.rawValue.uppercased()),
            URLQueryItem(name: "digits", value: "\(token.digits)"),
        ]
        if !token.issuer.isEmpty {
            items.append(URLQueryItem(name: "issuer", value: token.issuer))
        }
        if token.type == .totp {
            items.append(URLQueryItem(name: "period", value: "\(token.period)"))
        } else {
            items.append(URLQueryItem(name: "counter", value: "\(token.counter)"))
        }
        components.queryItems = items
        return components.string ?? ""
    }
}
