# Assistive current-session attach doctrine

**Owner:** Agent D — Docs / Atlas / Integration  
**Branch:** `fix/f7-gate-stability`  
**Related:** [`f7-vs-assistive-attach-mode.md`](f7-vs-assistive-attach-mode.md) · [`town-to-town-trade-assist-cert.md`](town-to-town-trade-assist-cert.md)

---

## Core rule

**Do not certify the door when the player is already in the room.**

People know how to start Bannerlord. The mod should help **inside** Bannerlord — blacksmithing, trading, travel, inventory, stamina, market advice, and safe in-game decisions. Assistive certs attach to the **current legitimate session**; they do not relaunch, reload, or navigate the launcher unless attach fails and `-LaunchIfNeeded` is explicitly chosen.

---

## When to attach (no launch)

If Bannerlord is already running and `BlacksmithGuild_Status.json` proves **all** of:

| Field | Required |
|-------|----------|
| `readinessSurface` | `settlement_menu`, `map_surface`, or `settlement_interior` |
| `canPollFileInbox` | `true` |
| `inGameAssistReady` | `true` |
| `canAcceptAssistiveCommand` | `true` |

Then assistive certs **must**:

- Attach to the current session and run probes
- **Not** relaunch Bannerlord
- **Not** navigate the launcher
- **Not** wait for old MapTransition / open-map golden-path semantics
- **Not** treat manual Play or Continue as contamination

Manual launch is **evidence**, not failure.

---

## Preferred command

After Agent C attach-first runner (`0b5798a`+):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-town-to-town-trade-assist-cert.ps1 -AttachOnly
```

Equivalent: `-NoLaunch`. Default (no flags) is attach-only.

Optional fallback when attach fails:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-town-to-town-trade-assist-cert.ps1 -LaunchIfNeeded
```

---

## Attach freshness gate

Runner uses **live-ready** Status, not cert-start mtime:

- `canPollFileInbox` + `inGameAssistReady`, **or**
- `updatedAt` within **300s** (`StatusFreshSec`)

Target wall time: **under 60s** once `inGameAssistReady=true`.

---

## Authoritative attach PASS reference

| Field | Value |
|-------|-------|
| Session | `20260624-004036` |
| Evidence | [`manifest.json`](../../evidence/live-cert/20260624-004036/checkpoint-01-assistive-town-trade/manifest.json) |
| `assistiveAttach` | `true` |
| `manualLaunchObserved` | `true` |
| Surface | `settlement_menu` @ Quyaz |
| Probe | `AssistiveTownToTownProbe` ack Success |

---

## Routing

| Defect | Owner |
|--------|-------|
| Attach-only runner / harvest / classifier | **Agent C** |
| Runtime command / probe / inbox readiness | **Agent B** |
| Evidence commit / manifest / PR | **Agent A** |
| Doc drift | **Agent D** |

---

## Related docs

- [`external-state-timeline-schema.md`](external-state-timeline-schema.md)
- [`f7-agent-coordination.md`](../../../handoff/f7-agent-coordination.md)
