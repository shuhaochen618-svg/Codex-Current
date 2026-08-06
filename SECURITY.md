# Security policy

## Supported version

Security fixes currently target the latest V1 release line.

| Version | Supported |
|---|---|
| 1.x | Yes |
| < 1.0 | No |

## Reporting a vulnerability

Please use GitHub's **Report a vulnerability** private security-advisory flow for this repository. Do not open a public issue for a vulnerability involving credential access, task-content exposure, local socket access, unsafe file permissions, or release signing.

Include:

- the affected version or commit;
- a minimal reproduction;
- the expected and observed privacy boundary;
- impact and any known workaround.

Do not include real credentials, authentication files, complete conversation content, VPN subscription URLs, or other users' data. A sanitized reproduction is preferred.

## Security boundaries

Codex Current must not:

- read `~/.codex/auth.json` or other credential material;
- upload, log, or separately persist task request text;
- parse or display assistant or reasoning content;
- read VPN subscription files or secret-bearing configuration files;
- present a local estimate as official account data.

The complete source and storage boundaries are defined in [docs/DATA_CONTRACT.md](docs/DATA_CONTRACT.md).
