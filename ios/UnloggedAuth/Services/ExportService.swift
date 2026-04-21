import Foundation

@MainActor
enum ExportService {

    /// Generates export data as UTF-8 encoded otpauth:// URIs, one per line.
    /// This is the universal format compatible with virtually all 2FA apps.
    static func exportAsURIData(tokens: [OTPToken]) -> Data? {
        guard !tokens.isEmpty else { return nil }
        let text = tokens
            .map { OTPAuthParser.buildURI(from: $0) }
            .joined(separator: "\n")
        return text.data(using: .utf8)
    }
}
