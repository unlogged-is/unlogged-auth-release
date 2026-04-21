# Privacy Policy

**Last updated: April 21, 2026**

## Overview

unlogged Auth is a TOTP authenticator app built on a simple principle: your data is yours. We do not collect it, store it, or transmit it.

---

## Data Collection

**We collect no data.**

unlogged Auth does not collect, transmit, or store any personal information, usage data, analytics, or telemetry of any kind.

---

## How Your Data Is Stored

All data — including your TOTP secrets, account names, and issuer labels — is stored exclusively on your device. Secrets are encrypted using AES-GCM with keys derived via PBKDF2 and stored in the iOS Keychain. Data only ever leaves your device if you explicitly configure an optional backup destination (see [Backups](#icloud--backups)). unlogged LLC never has access to your data regardless of which backup option you choose.

---

## Open Source

unlogged Auth is fully open source. The complete source code is available in this repository.

We believe transparency is the only meaningful foundation for a privacy claim.

---

## Reproducible Builds

unlogged Auth supports reproducible builds. This means the binary distributed on the App Store can be independently verified to match the source code in this repository. You are never asked to trust a black box.

Instructions for verifying the build are available in [BUILDING.md](./BUILDING.md).

---

## Our Commitment to User Privacy

unlogged LLC is committed to never introducing changes that degrade user privacy. Specifically:

- We will never add analytics, telemetry, or data collection of any kind
- We will never integrate advertising or tracking SDKs
- We will never introduce network access for the purpose of transmitting user data
- Features that require network access (e.g. optional cloud backup) are strictly opt-in, clearly documented, and disabled by default

If circumstances outside our control ever force a change to these commitments, such as a legal requirement, we will disclose it clearly in this policy and in the repository's commit history.

---

## Third-Party Services

unlogged Auth does not integrate with any third-party analytics, advertising, or data collection services.

---

## iCloud & Backups

unlogged Auth offers two optional backup methods. Both are strictly opt-in and disabled by default.

### iCloud Backup

unlogged Auth does not use iCloud sync or iCloud Keychain. If you back up your device via iCloud or iTunes/Finder, your encrypted app data may be included in that backup under Apple's standard backup policies. This is controlled entirely by you and Apple — not by us.

### Nextcloud / WebDAV Backup

You may optionally configure a Nextcloud server or any WebDAV-compatible server as a backup destination. When enabled:

- The app transmits only your **encrypted vault** to the server you configure — plaintext secrets never leave your device
- The connection is made directly from your device to your server — unlogged LLC is not involved and has no access to your server or its contents
- Your server credentials are stored locally in the iOS Keychain and are never transmitted to unlogged LLC
- You are responsible for the security and privacy practices of the server you choose

If you use a self-hosted server, you retain full control over your backup data. If you use a third-party Nextcloud provider, their privacy policy applies to data stored on their servers.

---

## Crash Reporting

unlogged Auth does not include any crash reporting or diagnostic data collection. If you experience a bug, you can report it directly via [GitHub Issues](https://github.com/unlogged-is/unlogged-auth-release/issues).

---

## Children's Privacy

unlogged Auth does not collect data from anyone, including children under the age of 13.

---

## Changes to This Policy

Any changes to this policy will be committed to this repository with a revised "Last updated" date and a clear commit message describing what changed. The full history of this policy is publicly auditable via git. We will never silently degrade the privacy protections described here.

---

## Contact

For questions or concerns, open an issue on this repository or contact us at [hello@unlogged.is](mailto:hello@unlogged.is).

---

*Made with 🤍 in Michigan by unlogged LLC*
