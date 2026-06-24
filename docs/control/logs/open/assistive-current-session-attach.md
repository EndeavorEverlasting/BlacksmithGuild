# Assistive current-session attach doctrine

**Owner:** Agent D — Docs / Atlas / Integration  
**Branch:** **`main`** @ `3384c7d`  
**Related:** [`f7-vs-assistive-attach-mode.md`](f7-vs-assistive-attach-mode.md) · [`town-to-town-trade-assist-cert.md`](town-to-town-trade-assist-cert.md)

---

## Core rule

**Do not certify the door when the player is already in the room.**

People know how to start Bannerlord. People need help **inside** Bannerlord — blacksmithing, trading, travel, inventory, stamina, market advice, and safe in-game decisions.

If the game is **already open** and Status proves assist readiness, assistive certs **attach**. They do **not**:

- Relaunch Bannerlord
- Navigate the launcher
- Run old F7 Continue
- Wait for MapTransition / open-map golden-path semantics

Manual Play / Continue is **evidence**, not contamination.

---

## When to attach (no launch)

If Bannerlord is already running and `BlacksmithGuild_Status.json` proves:

| Field | Required |
|-------|----------|
| `readinessSurface` | `settlement_menu`, `map_surface`, or `settlement_interior` |
| `canPollFileInbox` | `true` |
| `inGameAssistReady` | `true` |
| `canAcceptAssistiveCommand` | `true` (when present) |

Then assistive certs **attach to the current session** and run probes.

---

## Preferred command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-town-to-town-trade-assist-cert.ps1 -AttachOnly
```

Equivalent: `-NoLaunch`. Default (no flags) is attach-only.

Optional fallback when attach fails:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-town-to-town-trade-assist-cert.ps1 -LaunchIfNeeded
```

---

## Authoritative attach-only PASS

| Field | Value |
|-------|-------|
| Session | **`20260624-020821`** |
| Evidence | [`manifest.json`](../../evidence/live-cert/20260624-020821/checkpoint-01-assistive-town-trade/manifest.json) |
| `mode` | `assistive_attach` |
| `launchUsed` | **false** |
| `launchPath` | `existing_session` |
| Wall time | ~5s |
| Surface | `settlement_menu` @ Quyaz |
| Probe | `AssistiveTownToTownProbe` ack Success (seq=3) |

**Setup-path PASS (reference):** [`20260624-004036`](../../evidence/live-cert/20260624-004036/checkpoint-01-assistive-town-trade/manifest.json)

---

## Inbox sequence regression (PR #10)

Honest FAILs before fix:

- `20260624-020430` — `assistive_probe_failed` (stale sequence=1)
- `20260624-020644` — `assistive_probe_failed` (same class)

**Root cause:** `Send-ForgeCommand` reused stale sequence=1 after game had consumed sequence=2.

**Protection:** PR #10 — `test-forge-command-sequence-after-prior-ack.ps1` wired in `verify-f7-runner-contract.ps1`. Proves next command becomes sequence=3 even when consumed markers are buried above noisy trace-only tail.

---

## Routing

| Defect | Owner |
|--------|-------|
| Attach-only runner / harvest / inbox sequence | **Agent C** (idle; PR #10 merged) |
| Runtime command / probe / execute | **Agent B** |
| Evidence commit | **Agent A** |
| Doc drift | **Agent D** |

---

## Related docs

- [`external-state-timeline-schema.md`](external-state-timeline-schema.md)
- [`f7-agent-coordination.md`](../../../handoff/f7-agent-coordination.md)
