# Product brief: Codex Current v1.0

## Product statement

A native macOS floating monitor for people who use Codex heavily enough to care about both quota continuity and the health of their Codex work.

The first public product is a modular monitor, not a third-party widget platform. Users choose which built-in cards appear, reorder them, and switch between compact and expanded presentation.

## Primary user

A ChatGPT/Codex account user who uses Codex frequently, watches quota windows, and wants a lightweight view of usage, task activity, and VPN health without keeping the Codex UI open.

This is an intersection persona: quota monitoring and Codex-environment awareness belong to the same user.

## Core job

Answer one question at a glance:

> Can I continue using Codex smoothly right now, and are my quota, tasks, and VPN healthy?

## MVP components

1. **Codex limits** — relevant official rate-limit buckets, remaining percentage, and plan metadata when present. Dormant model-specific buckets are hidden until they show usage.
2. **Reset timeline** — actual reset timestamps for every returned bucket.
3. **Usage activity** — official daily token activity plus a clearly labelled local estimate derived from observed rate-limit changes.
4. **Task activity (Beta)** — running-task list from sessions currently opened by Codex Desktop, with a short request summary, model/effort, elapsed time, and per-turn token use.
5. **VPN / Proxy** — Clash Verge/Mihomo process, system proxy/TUN state, routing mode, AI group node, node health, and recent latency.

Default visible components: limits, task activity, and VPN/proxy status.

## Interaction model

- Menu-bar entry always available.
- Floating panel can be shown, hidden, moved, resized within limits, and pinned above other windows.
- Compact mode retains the single most important value from each enabled component.
- Expanded mode exposes the evidence and context behind the value.
- The task card defaults to an aggregate summary. Its disclosure reveals a task list inside a height-capped, independently scrollable detail area so many concurrent tasks do not stretch the floating window.
- Users can show, hide, and reorder built-in components.
- Important low-quota, detected task, and VPN-disconnection events may generate native notifications.

## Data truth policy

Every value is visibly classified:

- **Official** — returned by a documented Codex/OpenAI endpoint.
- **Local** — read directly from bounded on-device operating-system, process, or local-socket state.
- **Estimated** — calculated from local observations and displayed as a range, never false precision.
- **Beta** — useful but not guaranteed complete, currently task observation.
- **Unavailable** — no reliable value exists; the UI says so instead of inventing one.

Rate-limit windows are rendered dynamically. Five-hour and seven-day labels appear only when those durations are actually returned. An unused model-specific bucket is retained as source data but omitted from the dashboard until its usage rises above zero.

## Privacy

- Local processing and storage only for monitoring history.
- No application account or cloud sync.
- No auth-file scraping.
- Task monitoring reads a bounded tail of sessions currently opened by Codex Desktop. It displays a normalized, 72-character maximum summary of the current user request plus model, effort, start time, and token counters.
- Task request text is processed only in memory and is not uploaded, logged, or separately persisted. Assistant and reasoning content is not parsed or displayed.
- Permanent local history until the user clears it.

## First-release boundary

### Included

- macOS 14+;
- ChatGPT/Codex account authentication;
- five built-in components;
- English and Simplified Chinese chosen by system locale;
- manual GitHub Release download and manual updates;
- free distribution;
- owner-led development and roadmap.

### Explicit non-goals

- CPU/GPU/memory monitoring;
- Claude, Cursor, or other AI tools;
- third-party runtime plugin system;
- accounts, telemetry, cloud history, or sync;
- Windows/Linux;
- automatic updates;
- arbitrary canvas layout or theme editor.

## Validation

The initial success criterion is personal retention: the owner voluntarily keeps the app running for seven consecutive days because it is genuinely useful.

Technical completion is separate from product validation. Passing builds and tests means the implementation is ready for use; it does not establish the seven-day product outcome.

## Deferred release decisions

- production icon and wider brand identity;
- source license and contribution policy;
- Developer ID/notarized public release;
- whether task monitoring should later include standalone Codex CLI processes;
- adapters for VPN clients other than Clash Verge/Mihomo.
