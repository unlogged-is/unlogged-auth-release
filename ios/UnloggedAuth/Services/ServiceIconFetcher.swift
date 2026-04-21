import SwiftUI
import UIKit

@Observable
@MainActor
class ServiceIconFetcher {
    private var cache: [String: URL] = [:]
    private var previewCache: [String: URL] = [:]
    private var failedLookups: [String: Date] = [:]
    private let cacheDirectory: URL
    private static let retryInterval: TimeInterval = 86400 // 24 hours
    private static let minIconDimension: CGFloat = 32

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("service_icons")
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        loadCacheManifest()
        loadPreviewCache()
    }

    func iconURL(for issuer: String) -> URL? {
        let key = normalizeIssuer(issuer)
        return cache[key]
    }

    func fetchIcons(for tokens: [OTPToken]) {
        for token in tokens where !token.issuer.isEmpty {
            Task { await fetchIcon(for: token.issuer, account: token.account) }
        }
    }

    func fetchIcon(for issuer: String, account: String = "") async {
        let key = normalizeIssuer(issuer)
        guard !key.isEmpty, cache[key] == nil else { return }

        // Skip if recently failed (retry after 24 hours)
        if let failedDate = failedLookups[key],
           Date().timeIntervalSince(failedDate) < Self.retryInterval {
            return
        }

        // Try Simple Icons first (clean branded SVG icons)
        if await tryFetchSimpleIcon(for: key) {
            return
        }

        // Fall back to favicon-based sources
        let domains = domainGuesses(for: key, issuer: issuer, account: account)

        for domain in domains {
            if await tryFetchFavicon(key: key, domain: domain) {
                return
            }
        }

        failedLookups[key] = Date()
    }

    /// When a token's issuer is renamed, migrate the cached icon to the new key
    /// and try fetching a proper icon for the new name in the background.
    func migrateIcon(fromIssuer oldIssuer: String, toIssuer newIssuer: String) {
        let oldKey = normalizeIssuer(oldIssuer)
        let newKey = normalizeIssuer(newIssuer)
        guard !newKey.isEmpty, oldKey != newKey else { return }

        // Copy the old cached icon to the new key so it shows immediately
        if let oldURL = cache[oldKey], cache[newKey] == nil {
            let newFile = cacheDirectory.appendingPathComponent("\(newKey).png")
            try? FileManager.default.copyItem(at: oldURL, to: newFile)
            cache[newKey] = newFile
            saveCacheManifest()
        }

        // Try to fetch a proper icon for the new name in the background
        failedLookups.removeValue(forKey: newKey)
        Task { await fetchIcon(for: newIssuer) }
    }

    // MARK: - Simple Icons

    private func tryFetchSimpleIcon(for key: String) async -> Bool {
        // Use the bundled Simple Icons database for matching
        guard let entry = SimpleIconsDatabase.shared.lookup(issuer: key) else { return false }

        let urlString = "https://cdn.simpleicons.org/\(entry.slug)"
        guard let url = URL(string: urlString) else { return false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let svgString = String(data: data, encoding: .utf8) else { return false }

            guard let pathData = Self.extractSVGPathData(from: svgString),
                  let cgPath = SVGPathParser.parse(pathData) else { return false }

            let brandColor = UIColor(hexString: entry.hex)
            guard let image = Self.renderIcon(path: cgPath, brandColor: brandColor),
                  let pngData = image.pngData() else { return false }

            let localFile = cacheDirectory.appendingPathComponent("\(key).png")
            try pngData.write(to: localFile)
            cache[key] = localFile
            saveCacheManifest()
            return true
        } catch {
            return false
        }
    }

    private static func extractSVGPathData(from svg: String) -> String? {
        let pattern = #"d="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: svg, range: NSRange(svg.startIndex..., in: svg)),
              let range = Range(match.range(at: 1), in: svg) else { return nil }
        return String(svg[range])
    }

    private static func renderIcon(path: CGPath, brandColor: UIColor, size: CGFloat = 128) -> UIImage? {
        // Determine icon foreground color based on background luminance
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        brandColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        let iconColor: UIColor = luminance > 0.7 ? .black : .white

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let context = ctx.cgContext
            let rect = CGRect(x: 0, y: 0, width: size, height: size)

            // Rounded rectangle background
            let bgPath = UIBezierPath(roundedRect: rect, cornerRadius: size * 0.22)
            brandColor.setFill()
            bgPath.fill()

            // Scale and center the SVG path (viewBox is 0 0 24 24)
            let padding = size * 0.2
            let iconArea = rect.insetBy(dx: padding, dy: padding)

            let pathBounds = path.boundingBoxOfPath
            guard !pathBounds.isEmpty, pathBounds.width > 0, pathBounds.height > 0 else { return }

            let scaleX = iconArea.width / pathBounds.width
            let scaleY = iconArea.height / pathBounds.height
            let scale = min(scaleX, scaleY)

            let scaledW = pathBounds.width * scale
            let scaledH = pathBounds.height * scale
            let tx = iconArea.minX + (iconArea.width - scaledW) / 2 - pathBounds.minX * scale
            let ty = iconArea.minY + (iconArea.height - scaledH) / 2 - pathBounds.minY * scale

            var transform = CGAffineTransform(translationX: tx, y: ty).scaledBy(x: scale, y: scale)

            if let scaledPath = path.copy(using: &transform) {
                context.setFillColor(iconColor.cgColor)
                context.addPath(scaledPath)
                context.fillPath()
            }
        }
    }

    // MARK: - Favicon fetching (fallback)

    private func tryFetchFavicon(key: String, domain: String) async -> Bool {
        let sources = faviconURLs(for: domain)
        for sourceURL in sources {
            guard let url = URL(string: sourceURL) else { continue }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      data.count > 500 else { continue }

                guard let image = UIImage(data: data),
                      image.size.width >= Self.minIconDimension,
                      image.size.height >= Self.minIconDimension else { continue }

                guard let pngData = image.pngData() else { continue }

                let localFile = cacheDirectory.appendingPathComponent("\(key).png")
                try pngData.write(to: localFile)
                cache[key] = localFile
                saveCacheManifest()
                return true
            } catch {
                continue
            }
        }
        return false
    }

    private func faviconURLs(for domain: String) -> [String] {
        [
            "https://icon.horse/icon/\(domain)",
            "https://t0.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=https://\(domain)&size=128",
            "https://icons.duckduckgo.com/ip3/\(domain).ico",
        ]
    }

    // MARK: - Normalization

    private func normalizeIssuer(_ issuer: String) -> String {
        var name = issuer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if let parenRange = name.range(of: #"\s*\(.*\)"#, options: .regularExpression) {
            name.removeSubrange(parenRange)
        }

        let suffixes = ["account", "authenticator", "auth", "2fa", "login", "security", "verification", "app"]
        for suffix in suffixes {
            if name.hasSuffix(" \(suffix)") {
                name = String(name.dropLast(suffix.count + 1))
            }
        }

        let prefixes = ["my ", "the "]
        for prefix in prefixes {
            if name.hasPrefix(prefix) {
                name = String(name.dropFirst(prefix.count))
            }
        }

        return name.replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Domain guessing (for favicon fallback)

    private func domainGuesses(for key: String, issuer: String = "", account: String = "") -> [String] {
        var guesses: [String] = []

        // Highest priority: if the issuer itself looks like a domain
        if let issuerDomain = Self.extractDomain(fromIssuer: issuer) {
            guesses.append(issuerDomain)
        }

        // Third: known domains lookup
        if let domain = Self.knownDomains[key] {
            if !guesses.contains(domain) {
                guesses.append(domain)
            }
        } else {
            for (known, domain) in Self.knownDomains {
                if key.hasPrefix(known) && key.count > known.count {
                    if !guesses.contains(domain) {
                        guesses.append(domain)
                    }
                    break
                }
            }
        }

        // Fourth: prefix matching for longer keys
        if key.count > 8 {
            for length in stride(from: min(key.count - 1, 12), through: 3, by: -1) {
                let prefix = String(key.prefix(length))
                if let domain = Self.knownDomains[prefix], !guesses.contains(domain) {
                    guesses.append(domain)
                    break
                }
            }
        }

        // Last resort: common TLD guesses
        for tld in ["com", "io", "org", "net", "co", "app", "dev"] {
            let guess = "\(key).\(tld)"
            if !guesses.contains(guess) {
                guesses.append(guess)
            }
        }

        return guesses
    }

    /// Detect if an issuer string looks like a domain (e.g., "login.example.com")
    private static func extractDomain(fromIssuer issuer: String) -> String? {
        let trimmed = issuer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Strip common URL prefixes
        var candidate = trimmed
        for prefix in ["https://", "http://", "www."] {
            if candidate.hasPrefix(prefix) {
                candidate = String(candidate.dropFirst(prefix.count))
            }
        }
        // Remove trailing paths
        if let slashIndex = candidate.firstIndex(of: "/") {
            candidate = String(candidate[..<slashIndex])
        }
        // Must look like a domain: contains a dot, no spaces, reasonable length
        guard candidate.contains("."),
              !candidate.contains(" "),
              candidate.count >= 4,
              candidate.count <= 253 else { return nil }
        return candidate
    }

    // MARK: - Cache persistence

    private var manifestURL: URL {
        cacheDirectory.appendingPathComponent("manifest.json")
    }

    private func loadCacheManifest() {
        guard let data = try? Data(contentsOf: manifestURL),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        for (key, path) in dict {
            let url = cacheDirectory.appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: url.path) {
                cache[key] = url
            }
        }
    }

    private func saveCacheManifest() {
        let dict = cache.mapValues { $0.lastPathComponent }
        if let data = try? JSONEncoder().encode(dict) {
            try? data.write(to: manifestURL)
        }
    }

    // MARK: - Icon picker support

    /// Type alias so views can reference the entry type through ServiceIconFetcher.
    typealias SimpleIconEntry = SimpleIconsDatabase.IconEntry

    /// All icons from the bundled database, for the picker.
    static var availableIcons: [SimpleIconEntry] {
        SimpleIconsDatabase.shared.icons
    }

    /// Search icons by query (for the picker).
    static func searchIcons(query: String) -> [SimpleIconEntry] {
        SimpleIconsDatabase.shared.search(query: query)
    }

    /// Fetch a specific Simple Icon and cache it under the given issuer key.
    /// Used by the icon picker to assign a chosen icon to a token.
    func fetchSpecificIcon(slug: String, hex: String, forIssuer issuer: String) async -> Bool {
        let key = normalizeIssuer(issuer)
        guard !key.isEmpty else { return false }

        let urlString = "https://cdn.simpleicons.org/\(slug)"
        guard let url = URL(string: urlString) else { return false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let svgString = String(data: data, encoding: .utf8) else { return false }

            guard let pathData = Self.extractSVGPathData(from: svgString),
                  let cgPath = SVGPathParser.parse(pathData) else { return false }

            let brandColor = UIColor(hexString: hex)
            guard let image = Self.renderIcon(path: cgPath, brandColor: brandColor),
                  let pngData = image.pngData() else { return false }

            let localFile = cacheDirectory.appendingPathComponent("\(key).png")
            try pngData.write(to: localFile)
            cache[key] = localFile
            failedLookups.removeValue(forKey: key)
            saveCacheManifest()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Preview icon support (for icon picker)

    /// Returns cached preview icon URL for a given slug, if available.
    func previewIconURL(for slug: String) -> URL? {
        previewCache[slug]
    }

    /// Fetches and caches a preview icon for the picker. Returns the local file URL.
    func fetchPreviewIcon(slug: String, hex: String) async -> URL? {
        if let cached = previewCache[slug] { return cached }

        let urlString = "https://cdn.simpleicons.org/\(slug)"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let svgString = String(data: data, encoding: .utf8) else { return nil }

            guard let pathData = Self.extractSVGPathData(from: svgString),
                  let cgPath = SVGPathParser.parse(pathData) else { return nil }

            let brandColor = UIColor(hexString: hex)
            guard let image = Self.renderIcon(path: cgPath, brandColor: brandColor, size: 64),
                  let pngData = image.pngData() else { return nil }

            let localFile = cacheDirectory.appendingPathComponent("preview_\(slug).png")
            try pngData.write(to: localFile)
            previewCache[slug] = localFile
            savePreviewCache()
            return localFile
        } catch {
            return nil
        }
    }

    private var previewManifestURL: URL {
        cacheDirectory.appendingPathComponent("preview_manifest.json")
    }

    private func loadPreviewCache() {
        guard let data = try? Data(contentsOf: previewManifestURL),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        for (slug, filename) in dict {
            let fileURL = cacheDirectory.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                previewCache[slug] = fileURL
            }
        }
    }

    private func savePreviewCache() {
        let dict = previewCache.mapValues { $0.lastPathComponent }
        if let data = try? JSONEncoder().encode(dict) {
            try? data.write(to: previewManifestURL)
        }
    }

    // MARK: - Known domains (favicon fallback)

    private static let knownDomains: [String: String] = [
        "google": "google.com",
        "googleaccount": "google.com",
        "gmail": "google.com",
        "youtube": "youtube.com",
        "github": "github.com",
        "gitlab": "gitlab.com",
        "microsoft": "microsoft.com",
        "microsoftaccount": "microsoft.com",
        "outlook": "outlook.com",
        "hotmail": "outlook.com",
        "live": "live.com",
        "office365": "office.com",
        "azure": "azure.microsoft.com",
        "apple": "apple.com",
        "appleid": "apple.com",
        "icloud": "icloud.com",
        "amazon": "amazon.com",
        "amazonwebservices": "aws.amazon.com",
        "aws": "aws.amazon.com",
        "facebook": "facebook.com",
        "meta": "meta.com",
        "twitter": "twitter.com",
        "x": "x.com",
        "instagram": "instagram.com",
        "linkedin": "linkedin.com",
        "snapchat": "snapchat.com",
        "tiktok": "tiktok.com",
        "pinterest": "pinterest.com",
        "reddit": "reddit.com",
        "tumblr": "tumblr.com",
        "mastodon": "mastodon.social",
        "threads": "threads.net",
        "bluesky": "bsky.app",
        "discord": "discord.com",
        "slack": "slack.com",
        "telegram": "telegram.org",
        "signal": "signal.org",
        "whatsapp": "whatsapp.com",
        "zoom": "zoom.us",
        "teams": "teams.microsoft.com",
        "skype": "skype.com",
        "webex": "webex.com",
        "proton": "proton.me",
        "protonmail": "proton.me",
        "protonvpn": "protonvpn.com",
        "tutanota": "tutanota.com",
        "tuta": "tuta.com",
        "fastmail": "fastmail.com",
        "mailchimp": "mailchimp.com",
        "sendgrid": "sendgrid.com",
        "mailfence": "mailfence.com",
        "zohomail": "zoho.com",
        "zoho": "zoho.com",
        "yahoo": "yahoo.com",
        "dropbox": "dropbox.com",
        "box": "box.com",
        "onedrive": "onedrive.com",
        "googledrive": "drive.google.com",
        "mega": "mega.nz",
        "pcloud": "pcloud.com",
        "sync": "sync.com",
        "nextcloud": "nextcloud.com",
        "owncloud": "owncloud.com",
        "cloudflare": "cloudflare.com",
        "digitalocean": "digitalocean.com",
        "linode": "linode.com",
        "akamai": "akamai.com",
        "heroku": "heroku.com",
        "netlify": "netlify.com",
        "vercel": "vercel.com",
        "render": "render.com",
        "railway": "railway.app",
        "fly": "fly.io",
        "flyio": "fly.io",
        "supabase": "supabase.com",
        "firebase": "firebase.google.com",
        "mongodb": "mongodb.com",
        "planetscale": "planetscale.com",
        "npm": "npmjs.com",
        "npmjs": "npmjs.com",
        "pypi": "pypi.org",
        "docker": "docker.com",
        "dockerhub": "hub.docker.com",
        "kubernetes": "kubernetes.io",
        "terraform": "terraform.io",
        "hashicorp": "hashicorp.com",
        "vagrant": "vagrantup.com",
        "jenkins": "jenkins.io",
        "circleci": "circleci.com",
        "travisci": "travis-ci.com",
        "githubactions": "github.com",
        "sentry": "sentry.io",
        "datadog": "datadoghq.com",
        "newrelic": "newrelic.com",
        "grafana": "grafana.com",
        "pagerduty": "pagerduty.com",
        "opsgenie": "opsgenie.com",
        "launchpad": "launchpad.net",
        "sourceforge": "sourceforge.net",
        "codeberg": "codeberg.org",
        "replit": "replit.com",
        "stackblitz": "stackblitz.com",
        "codesandbox": "codesandbox.io",
        "gitea": "gitea.com",
        "crates": "crates.io",
        "rubygems": "rubygems.org",
        "packagist": "packagist.org",
        "nuget": "nuget.org",
        "sonatype": "sonatype.com",
        "jfrog": "jfrog.com",
        "atlassian": "atlassian.com",
        "jira": "atlassian.com",
        "confluence": "atlassian.com",
        "trello": "trello.com",
        "bitbucket": "bitbucket.org",
        "notion": "notion.so",
        "asana": "asana.com",
        "monday": "monday.com",
        "clickup": "clickup.com",
        "linear": "linear.app",
        "basecamp": "basecamp.com",
        "airtable": "airtable.com",
        "figma": "figma.com",
        "sketch": "sketch.com",
        "canva": "canva.com",
        "adobe": "adobe.com",
        "adobecreativecloud": "adobe.com",
        "invision": "invisionapp.com",
        "dribbble": "dribbble.com",
        "behance": "behance.net",
        "miro": "miro.com",
        "okta": "okta.com",
        "auth0": "auth0.com",
        "onelogin": "onelogin.com",
        "duo": "duo.com",
        "duosecurity": "duo.com",
        "jumpcloud": "jumpcloud.com",
        "ping": "pingidentity.com",
        "pingidentity": "pingidentity.com",
        "bitwarden": "bitwarden.com",
        "1password": "1password.com",
        "onepassword": "1password.com",
        "lastpass": "lastpass.com",
        "dashlane": "dashlane.com",
        "keeper": "keepersecurity.com",
        "keepersecurity": "keepersecurity.com",
        "nordpass": "nordpass.com",
        "enpass": "enpass.io",
        "roboform": "roboform.com",
        "nordvpn": "nordvpn.com",
        "expressvpn": "expressvpn.com",
        "mullvad": "mullvad.net",
        "mullvadvpn": "mullvad.net",
        "surfshark": "surfshark.com",
        "privateinternetaccess": "privateinternetaccess.com",
        "pia": "privateinternetaccess.com",
        "windscribe": "windscribe.com",
        "ivpn": "ivpn.net",
        "tailscale": "tailscale.com",
        "stripe": "stripe.com",
        "paypal": "paypal.com",
        "venmo": "venmo.com",
        "cashapp": "cash.app",
        "squareup": "squareup.com",
        "square": "squareup.com",
        "wise": "wise.com",
        "transferwise": "wise.com",
        "revolut": "revolut.com",
        "robinhood": "robinhood.com",
        "fidelity": "fidelity.com",
        "schwab": "schwab.com",
        "charlesschwab": "schwab.com",
        "etrade": "etrade.com",
        "tdameritrade": "tdameritrade.com",
        "vanguard": "vanguard.com",
        "chase": "chase.com",
        "bankofamerica": "bankofamerica.com",
        "wellsfargo": "wellsfargo.com",
        "usaa": "usaa.com",
        "capitalone": "capitalone.com",
        "americanexpress": "americanexpress.com",
        "amex": "americanexpress.com",
        "discover": "discover.com",
        "citi": "citi.com",
        "citibank": "citi.com",
        "plaid": "plaid.com",
        "coinbase": "coinbase.com",
        "binance": "binance.com",
        "kraken": "kraken.com",
        "gemini": "gemini.com",
        "kucoin": "kucoin.com",
        "bybit": "bybit.com",
        "bitfinex": "bitfinex.com",
        "bitstamp": "bitstamp.net",
        "cryptocom": "crypto.com",
        "crypto.com": "crypto.com",
        "ftx": "ftx.com",
        "blockchain": "blockchain.com",
        "blockchain.com": "blockchain.com",
        "metamask": "metamask.io",
        "phantom": "phantom.app",
        "ledger": "ledger.com",
        "trezor": "trezor.io",
        "bitget": "bitget.com",
        "okx": "okx.com",
        "gate": "gate.io",
        "gateio": "gate.io",
        "upbit": "upbit.com",
        "nexo": "nexo.com",
        "celsius": "celsius.network",
        "blockfi": "blockfi.com",
        "steam": "steampowered.com",
        "steamcommunity": "steampowered.com",
        "valve": "steampowered.com",
        "epic": "epicgames.com",
        "epicgames": "epicgames.com",
        "ea": "ea.com",
        "electronicarts": "ea.com",
        "origin": "ea.com",
        "ubisoft": "ubisoft.com",
        "ubisoftconnect": "ubisoft.com",
        "riotgames": "riotgames.com",
        "riot": "riotgames.com",
        "blizzard": "blizzard.com",
        "battlenet": "blizzard.com",
        "battle.net": "blizzard.com",
        "activision": "activision.com",
        "xbox": "xbox.com",
        "playstation": "playstation.com",
        "sony": "sony.com",
        "nintendo": "nintendo.com",
        "gog": "gog.com",
        "itch": "itch.io",
        "itchio": "itch.io",
        "humblebundle": "humblebundle.com",
        "humble": "humblebundle.com",
        "roblox": "roblox.com",
        "namecheap": "namecheap.com",
        "godaddy": "godaddy.com",
        "ovh": "ovh.com",
        "hetzner": "hetzner.com",
        "vultr": "vultr.com",
        "hostinger": "hostinger.com",
        "bluehost": "bluehost.com",
        "siteground": "siteground.com",
        "dreamhost": "dreamhost.com",
        "ionos": "ionos.com",
        "gandi": "gandi.net",
        "hover": "hover.com",
        "porkbun": "porkbun.com",
        "dynadot": "dynadot.com",
        "name.com": "name.com",
        "cloudns": "cloudns.net",
        "dnsimple": "dnsimple.com",
        "route53": "aws.amazon.com",
        "squarespace": "squarespace.com",
        "wix": "wix.com",
        "webflow": "webflow.com",
        "shopify": "shopify.com",
        "wordpress": "wordpress.com",
        "etsy": "etsy.com",
        "ebay": "ebay.com",
        "alibaba": "alibaba.com",
        "aliexpress": "aliexpress.com",
        "woocommerce": "woocommerce.com",
        "magento": "magento.com",
        "bigcommerce": "bigcommerce.com",
        "gumroad": "gumroad.com",
        "patreon": "patreon.com",
        "kofi": "ko-fi.com",
        "ko-fi": "ko-fi.com",
        "substack": "substack.com",
        "medium": "medium.com",
        "hubspot": "hubspot.com",
        "salesforce": "salesforce.com",
        "zendesk": "zendesk.com",
        "freshdesk": "freshdesk.com",
        "intercom": "intercom.com",
        "mailgun": "mailgun.com",
        "postmark": "postmarkapp.com",
        "spotify": "spotify.com",
        "netflix": "netflix.com",
        "disneyplus": "disneyplus.com",
        "disney": "disneyplus.com",
        "hulu": "hulu.com",
        "hbo": "hbo.com",
        "hbomax": "hbo.com",
        "max": "max.com",
        "appletv": "tv.apple.com",
        "primevideo": "primevideo.com",
        "crunchyroll": "crunchyroll.com",
        "twitch": "twitch.tv",
        "soundcloud": "soundcloud.com",
        "deezer": "deezer.com",
        "tidal": "tidal.com",
        "evernote": "evernote.com",
        "todoist": "todoist.com",
        "grammarly": "grammarly.com",
        "duolingo": "duolingo.com",
        "coursera": "coursera.org",
        "udemy": "udemy.com",
        "khanacademy": "khanacademy.org",
        "edx": "edx.org",
        "pluralsight": "pluralsight.com",
        "codecademy": "codecademy.com",
        "leetcode": "leetcode.com",
        "hackerrank": "hackerrank.com",
        "samsung": "samsung.com",
        "samsungaccount": "samsung.com",
        "synology": "synology.com",
        "qnap": "qnap.com",
        "ubiquiti": "ui.com",
        "unifi": "ui.com",
        "ui": "ui.com",
        "opnsense": "opnsense.org",
        "pfsense": "pfsense.org",
        "proxmox": "proxmox.com",
        "truenas": "truenas.com",
        "portainer": "portainer.io",
        "ifttt": "ifttt.com",
        "zapier": "zapier.com",
        "twilio": "twilio.com",
        "openai": "openai.com",
        "chatgpt": "openai.com",
        "anthropic": "anthropic.com",
        "claude": "anthropic.com",
        "huggingface": "huggingface.co",
        "crowdstrike": "crowdstrike.com",
        "sophos": "sophos.com",
        "malwarebytes": "malwarebytes.com",
        "norton": "norton.com",
        "avast": "avast.com",
        "eset": "eset.com",
        "kaspersky": "kaspersky.com",
        "wordfence": "wordfence.com",
        "snyk": "snyk.io",
        "sonarqube": "sonarqube.org",
        "1blocker": "1blocker.com",
    ]
}

// MARK: - UIColor hex string initializer

private extension UIColor {
    convenience init(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
