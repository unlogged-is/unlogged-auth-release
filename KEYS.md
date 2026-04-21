# Signing Keys

This file contains the public GPG key used to sign all unlogged Auth release tags.

---

## Release Signing Key

| Field       | Value                                      |
|-------------|--------------------------------------------|
| Name        | unlogged LLC (unlogged Auth build verification) |
| Email       | privacy@unlogged.is                        |
| Key ID      | 5B2B1E5F0FBD988F                           |
| Fingerprint | `2B56 E88C 4F8F 8C32 8DDE  3D5A 5B2B 1E5F 0FBD 988F` |
| Algorithm   | RSA 4096                                   |

---

## Verifying a Release Tag

```bash
git tag -v v1.0.0
```

If the key is not already in your keychain, import it first:

```bash
# Import from this file
gpg --import KEYS.md

# Or fetch from a keyserver
gpg --keyserver keys.openpgp.org --recv-keys 2B56E88C4F8F8C328DDE3D5A5B2B1E5F0FBD988F
```

A valid signature will output:
```
gpg: Good signature from "unlogged LLC (unlogged Auth build verification) <privacy@unlogged.is>"
```

---

## Public Key

```
-----BEGIN PGP PUBLIC KEY BLOCK-----

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
iIt4Bs149yI=
=Kiyz
-----END PGP PUBLIC KEY BLOCK-----
```
