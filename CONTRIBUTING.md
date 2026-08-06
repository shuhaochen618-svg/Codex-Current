# Contributing to Codex Current

Thank you for helping improve Codex Current. V1.0 keeps a deliberately narrow product boundary: official Codex quota visibility, local Codex Desktop task awareness, and Clash Verge/Mihomo health on macOS.

## Before opening an issue

- Search existing issues first.
- For a bug, include the macOS version, Codex installation source, authentication type, and the smallest reproducible sequence.
- Do not include account identity, authentication files, API keys, full task prompts, conversation content, VPN subscription URLs, or proxy secrets.
- State which value was labelled **Official**, **Local**, **Estimated**, **Beta**, or **Unavailable** when the problem occurred.

## Before proposing a feature

Explain the user problem and the data source needed to solve it. A proposal should preserve the guarantees in [docs/DATA_CONTRACT.md](docs/DATA_CONTRACT.md). Features that require credential scraping, web-page scraping, prompt uploading, or false-precision quota conversion are out of scope.

Please open an issue before implementing a substantial feature. This avoids work on changes that do not fit the V1 product boundary.

## Development checks

Run all deterministic checks:

```sh
./scripts/test.sh
```

For source-specific changes, also run the relevant privacy-limited smoke check:

```sh
./scripts/smoke-app-server.sh
./scripts/smoke-local-status.sh
```

Keep English and Simplified Chinese localization keys aligned. Do not add logging that exposes account identity, quota values, task titles, selected VPN nodes, or conversation content.

## Pull requests and licensing

An open-source license has not yet been selected. External code pull requests should not be accepted until a license and contribution policy are added. Documentation-only issue reports and design discussion remain welcome.
