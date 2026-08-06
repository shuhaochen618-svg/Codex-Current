# Codex Current release checklist

Use this checklist for a public GitHub release. A successful local build is necessary but does not by itself establish product validation or safe public distribution.

## 1. Freeze release identity

- [x] Confirm product name (`Codex Current`) and repository slug (`Codex-Current`).
- [ ] Select and add an explicit `LICENSE`.
- [x] Set the publisher-controlled bundle identifier to `io.github.shuhaochen618-svg.codexcurrent`.
- [ ] Add the production app icon and verify all required sizes.
- [ ] Confirm version parity across `Support/Info.plist`, `README.md`, `README.zh-CN.md`, and `CHANGELOG.md`.

## 2. Verify implementation

- [ ] Run `./scripts/test.sh`.
- [ ] Run `./scripts/smoke-app-server.sh` with a supported ChatGPT/Codex login.
- [ ] Run `./scripts/smoke-local-status.sh` with the supported Codex Desktop and Clash Verge/Mihomo setup.
- [ ] Confirm both English and Simplified Chinese layouts.
- [ ] Confirm compact and expanded layouts at minimum and maximum window sizes.
- [ ] Verify history clearing and notification permissions.
- [ ] Recheck the field-level claims in `docs/DATA_CONTRACT.md` against current behavior.

## 3. Validate the product

- [ ] Complete seven consecutive days of genuine owner use without a severe data or stability defect.
- [ ] Record defects, causes, and unresolved limitations separately from successful technical checks.
- [ ] Reconfirm that Task activity still deserves the Beta label for the current Codex Desktop format.

## 4. Sign and notarize

- [ ] Build the Release configuration with a Developer ID Application certificate.
- [ ] Enable hardened runtime and verify entitlements.
- [ ] Submit the archive to Apple's notarization service.
- [ ] Staple and validate the notarization ticket.
- [ ] Verify the app on a clean supported Mac without local developer exceptions.

## 5. Prepare GitHub Release

- [ ] Run `./scripts/package-release.sh` after the signed build flow is wired into `scripts/build-app.sh`.
- [ ] Verify the ZIP SHA-256 from a clean download.
- [ ] Copy the matching `CHANGELOG.md` section into the release notes.
- [ ] Attach the notarized artifact and checksum.
- [ ] Mark prerelease status accurately if any release gate remains incomplete.
- [ ] Test every README download and documentation link after publication.
