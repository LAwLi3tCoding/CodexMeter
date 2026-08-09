# Codex Quota Data Source Research

Date: 2026-07-13

## Decision

CodexMeter reads quota and daily token totals through the documented local Codex App Server protocol. It does not read `~/.codex/auth.json`, query macOS Keychain items, parse raw session transcripts, or call private ChatGPT backend endpoints. For the separate seven-day model ranking, it opens Codex's local thread database read-only and aggregates only model, token-count, and timestamp metadata.

The app launches two isolated instances of the installed CLI as long-lived child processes, one for quota and one for usage:

```text
codex app-server --listen stdio://
```

The transport is newline-delimited JSON using JSON-RPC 2.0 messages without the `jsonrpc` field.

The two request paths refresh concurrently and fail independently. An optional credential-free loopback HTTP(S) proxy can be applied to both child-process environments; remote proxy hosts and proxy URLs containing credentials are rejected.

## Verified local behavior

The implementation target was verified against `codex-cli 0.142.5` on macOS. The installed CLI can generate its protocol schema with:

```text
codex app-server generate-json-schema --experimental --out <directory>
```

The non-secret calls needed by CodexMeter are:

| Method | Purpose | Relevant fields |
| --- | --- | --- |
| `initialize` | Start the protocol session | `userAgent`, `codexHome`, `platformOs` |
| `account/read` | Read the active account | account `type`, `email`, `planType` |
| `account/rateLimits/read` | Read the current quota windows | `limitId`, `limitName`, `usedPercent`, `windowDurationMins`, `resetsAt` |
| `account/rateLimits/updated` | Receive rolling quota updates | sparse `RateLimitSnapshot` |
| `config/read` | Read the effective configured model | `config.model` |
| `account/usage/read` | 30-day usage history | summary and daily usage buckets |

The current schema supports both a backward-compatible `rateLimits` bucket and `rateLimitsByLimitId`. A bucket may contain a `primary` window, a `secondary` window, or only one of them. CodexMeter must therefore render data by duration rather than assuming that `primary` always means five hours and `secondary` always means one week.

## Meaning of the numbers

- `usedPercent` is the percentage consumed within the window.
- Remaining percentage is computed as `100 - usedPercent`, clamped to `0...100`.
- `windowDurationMins` is the quota window length.
- `resetsAt` is the Unix timestamp in seconds for the next reset.
- The protocol does not provide a reliable remaining-message count. Task complexity, model, context, tools, caching, and speed settings affect consumption.
- A UI value such as `3h 42m` means time until the quota window resets, not a promise of 3 hours and 42 minutes of usable model time.

## Ranked source strategy

1. **Codex App Server** — selected; documented, reuses Codex-managed authentication, and exposes account and quota types.
2. **CLI status output** — useful for manual diagnostics, but interactive output is not a stable application API.
3. **Codex thread index** — selected only for approximate model attribution; read `model`, `tokens_used`, and creation timestamps from `state_5.sqlite` without loading user content.
4. **Persisted session JSONL** — rejected for dashboard aggregation because scanning multi-gigabyte raw histories on every refresh is too expensive and exposes unnecessary content.
5. **Other config and state files** — unsuitable because formats may change and credentials may be present.
6. **Private ChatGPT HTTP endpoints** — rejected because no supported public per-user Codex quota REST API was found.

## Security and compatibility boundaries

- Never log App Server responses from `account/read` or `config/read` because they can contain private account or configuration data.
- Never decode, copy, or expose cached access tokens.
- Open the thread index read-only and select only model, token-count, and timestamp columns; never select previews, titles, paths, prompts, responses, or working directories.
- Treat the local model ranking as approximate because it compares cumulative tokens in threads created during the selected period, not turn-level model usage.
- Use Codex-managed ChatGPT authentication; CodexMeter has no token entry field.
- Treat missing fields and unknown enum values as normal compatibility conditions.
- Show an actionable “Codex CLI not found” or “Sign in with Codex CLI” state instead of reading credentials directly.
- App Server is versioned with the installed CLI. CodexMeter keeps decoding narrow and ignores unknown response fields.

## Official references

- [Codex App Server](https://learn.chatgpt.com/docs/app-server)
- [Authentication](https://learn.chatgpt.com/docs/auth)
- [Codex pricing and usage limits](https://learn.chatgpt.com/docs/pricing)
- [Codex CLI developer commands](https://learn.chatgpt.com/docs/developer-commands?surface=cli)
