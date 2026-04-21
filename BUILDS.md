# Verifiable Builds

This document explains how unlogged Auth releases are built and how you can verify that the source code in this repository matches what was submitted to the App Store.

---

## What We Commit To Per Release

Every release includes the following, attached to a signed git tag:

- The exact Xcode version used to produce the build
- A SHA-256 checksum of the unsigned IPA submitted to Apple
- The Swift package dependencies resolved at build time (`Package.resolved`)

This allows you to verify the *input* to Apple's pipeline. Note that Apple re-signs the binary during App Store processing, so a bit-for-bit match with the downloaded App Store binary is not possible — that is a limitation of Apple's platform, not this project.

---

## Pinned Xcode Version

All releases are built with a pinned Xcode version, recorded in `.xcode-version` at the root of this repository.

Current pinned version: **Xcode 26.4.1 (17E202)**

To install and select the correct version:

1. Download Xcode 26.4.1 from the [Apple Developer portal](https://developer.apple.com/download/all/)
2. Place it at `/Applications/Xcode_26.4.1.app`
3. Select it:
   ```bash
   sudo xcode-select -s /Applications/Xcode_26.4.1.app/Contents/Developer
   ```
4. Confirm:
   ```bash
   xcode-select -p
   xcodebuild -version
   ```

---

## Building From Source

1. Clone the repository and check out the release tag you want to verify:
   ```bash
   git clone https://github.com/unloggedllc/unlogged-auth.git
   cd unlogged-auth
   git checkout v1.0.0  # replace with the release tag
   ```

2. Resolve dependencies:
   ```bash
   xcodebuild -resolvePackageDependencies
   ```

3. Build the archive:
   ```bash
   xcodebuild archive \
     -scheme "unlogged Auth" \
     -configuration Release \
     -archivePath ./build/unloggedAuth.xcarchive \
     CODE_SIGNING_ALLOWED=NO
   ```

4. Export the unsigned IPA:
   ```bash
   xcodebuild -exportArchive \
     -archivePath ./build/unloggedAuth.xcarchive \
     -exportPath ./build/output \
     -exportOptionsPlist ExportOptions.plist
   ```

---

## Verifying the Checksum

Each release tag includes a `CHECKSUMS.txt` file containing the SHA-256 hash of the unsigned IPA. To verify your local build matches:

```bash
shasum -a 256 ./build/output/unloggedAuth.ipa
```

Compare the output against the hash in `CHECKSUMS.txt` for that release tag. A match confirms the binary submitted to Apple was built from the published source.

---

## Signed Release Tags

All release tags are signed with a GPG key. To verify a tag:

```bash
git tag -v v1.0.0
```

The signing key fingerprint is published in [KEYS.md](./KEYS.md).

---

## Reporting Discrepancies

If you find a mismatch between the published checksum and a build you have reproduced, please open an issue immediately. We take build integrity seriously.
