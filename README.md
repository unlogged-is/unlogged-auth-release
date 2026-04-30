# unlogged Auth

> A privacy-first two-factor authentication app for iOS. No accounts. No cloud. No tracking. Just your codes.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform: iOS](https://img.shields.io/badge/Platform-iOS-lightgrey.svg)](https://developer.apple.com/ios/)
[![Status: Beta](https://img.shields.io/badge/Status-Beta-orange.svg)](https://testflight.apple.com/join/U5Dbbg3g)
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Q5Q81VPRAG)

---

## What is unlogged Auth?

unlogged Auth is a TOTP (Time-Based One-Time Password) authenticator for iOS built around a simple principle: your authentication secrets belong to you, not a server.

Every code is generated on-device. Nothing is transmitted. Nothing is stored in the cloud, unless you choose to. The source code is open for anyone to audit.

---

## Features

- **100% on-device** — TOTP secrets never leave your device
- **No account required** — no sign-up, no email, no tracking
- **AES-GCM encrypted backups** — local encrypted exports you control
- **Biometric unlock** — Face ID / Touch ID support via Keychain
- **RFC 6238 compliant** — compatible with any standard TOTP service
- **Open source** — full source available under GPL-3.0

---

## Privacy

unlogged Auth collects nothing. There are no analytics, no crash reporting services, no third-party SDKs phoning home.


---

## Status

unlogged Auth is currently in **beta**. It is not yet available on the App Store.

If you'd like to join the beta or stay updated on the release:

**[Sign up on TestFlight →](https://testflight.apple.com/join/U5Dbbg3g)**

---

## Tech Stack

- **SwiftUI** — UI framework
- **CryptoKit** — AES-GCM encryption, PBKDF2 key derivation
- **Security framework** — Keychain storage, biometric authentication
- **RFC 6238 / HOTP** — TOTP implementation, no third-party dependencies

---

## Contributing

Contributions are welcome. If you find a bug or have a feature suggestion, please [open an issue](https://github.com/unlogged-is/unlogged-auth-release/issues).

If you'd like to submit a pull request, please open an issue first to discuss the change.

---

## License

unlogged Auth is licensed under the **GNU General Public License v3.0**, with an additional permission for Apple App Store distribution.

See [LICENSE.md](./LICENSE.md) for full terms.

---

## Links

- **Website:** [unlogged.is](https://unlogged.is)
- **App Store:** Coming soon
- **License:** [GPL-3.0 with App Store exception](./LICENSE.md)
- **EULA:** [End User License Agreement](./EULA.md)
