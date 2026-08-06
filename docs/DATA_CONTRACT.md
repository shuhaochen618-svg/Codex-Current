# Codex Current data contract

## Allowed sources

| Component | Source | Quality | Boundary |
|---|---|---|---|
| Limits | `account/rateLimits/read`, `account/rateLimits/updated` | Official | Multiple buckets and missing fields are valid; dormant model-specific buckets are retained but hidden from the dashboard |
| Reset timeline | `resetsAt`, `windowDurationMins` | Official | Display unavailable when absent; do not infer a weekly window |
| Token activity | `account/usage/read` | Official | Daily buckets and summary values may be null |
| Usage estimate | Locally sampled `usedPercent` changes within the same reset window | Estimated | Requires at least three samples and 30 minutes; display a range and risk level |
| Task activity | Bounded tail scan of session files currently opened by Codex Desktop | Beta | Reads the active turn's request, model/effort, start time, token counters, and boundary events; does not cover arbitrary standalone CLI processes |
| VPN / Proxy | macOS system proxy state and local Clash Verge/Mihomo Unix control socket | Direct local | Reads mode, selected AI node, health and delay; never reads subscription/config files |

## Prohibited sources

- `~/.codex/auth.json` or other credential material;
- parsing or displaying assistant/reasoning content from Codex session files;
- uploading, logging, or separately persisting task request text;
- scraped ChatGPT/Codex web pages;
- token counts presented as an exact conversion to remaining quota time.

## Local persistence

The history archive contains only:

- `windowID`;
- capture timestamp;
- used percentage;
- reset timestamp;
- daily date and token total.

It is stored in `~/Library/Application Support/CodexCurrent/history.json` until the user selects **Clear local history**. A pre-release archive stored under `CodexBar/history.json` is read as a legacy source and migrated to the new location on the next write.

## Degradation rules

1. Unsupported authentication receives an explicit explanation.
2. Missing optional fields render as unavailable.
3. Unknown rate-limit buckets retain backend identity/duration rather than being renamed.
4. Estimates disappear when the observation contract is not met.
5. Task activity and notifications use best-effort language and a Beta badge.
6. VPN status reports partial when Mihomo is running but neither system proxy nor TUN is enabled.
7. A task title falls back to a generic label when no user request is present in the bounded scan; token use stays unavailable until a token event establishes a baseline.

Official reference: [Codex App Server documentation](https://developers.openai.com/codex/app-server/).
