# Town-to-Town Trade Assist Cert

**Owner:** Agent A — Cert / Evidence / Git / PR (live runs) · **Spec:** Agent D  
**Branch:** `fix/f7-gate-stability`  
**Status:** **PASS** @ [`20260624-004036`](../../evidence/live-cert/20260624-004036/checkpoint-01-assistive-town-trade/manifest.json)  
**Runner:** [`scripts/run-town-to-town-trade-assist-cert.ps1`](../../../scripts/run-town-to-town-trade-assist-cert.ps1)

---

## Authoritative PASS session

| Field | Value |
|-------|-------|
| **Cert name** | Town-to-Town Trade Assist Cert |
| **Authoritative PASS session** | `20260624-004036` |
| **Evidence path** | `docs/evidence/live-cert/20260624-004036/checkpoint-01-assistive-town-trade/manifest.json` |
| **Product result** | PASS |
| **Surface** | `settlement_menu` |
| **Current settlement** | Quyaz |
| **Recommended next town** | Ortysia |
| **Trade execution** | `advisory_only` |
| **Travel command mode** | `advisory_only` |
| **`fakeGameplayDelta`** | `false` |
| **`canPollFileInbox`** | `true` |
| **`inGameAssistReady`** | `true` |
| **`canAcceptAssistiveCommand`** | `true` |

### What this PASS proves

- In-game **assistive command readiness** from a legitimate session (attach + inbox poll OK).
- **Advisory** gameplay output: real settlement context, recommended next town, no fabricated deltas.
- Manual launch / attach path is valid product evidence (`assistiveAttach=true`, `manualLaunchObserved=true`).

### What this PASS does **not** prove

- **Real buy/sell execution** — `tradeExecution=advisory_only` only.
- **Real travel execution** — `travelCommandMode=advisory_only` only.
- Launcher automation purity — that is **F7 infrastructure**, not this product medal.

Future **execute-path** certs must earn their own PASS manifests.

---

## Product framing

Old F7 Continue cert is **closed** as a product merge gate (informative FAIL @ [`20260623-205925`](../../evidence/live-cert/20260623-205925/checkpoint-01-f7-gate/manifest.json)). **Town-to-Town Trade Assist PASS** @ `20260624-004036` is the **current product medal**.

People know how to start the game. People need help **inside** Bannerlord: blacksmithing, trading, travel, inventory, stamina, market intelligence, and safe advisory or execute paths.

**Doctrine:** VanillaLegit + Assistive — automate hands, not consequences. No fake gold, inventory, or trade deltas.

See also: [`f7-vs-assistive-attach-mode.md`](f7-vs-assistive-attach-mode.md) · [`assistive-current-session-attach.md`](assistive-current-session-attach.md)

---

## Preconditions (assistive attach)

| Requirement | Notes |
|-------------|-------|
| Legitimate in-game session | Status.json fresh; external classifier agrees on surface |
| Manual launch OK | User may Play/Continue manually; `assistiveAttach=true` in timeline |
| Classifier before mutation | `Test-F7GuardedActionAllowed` must pass before clicks or dev commands |
| No cert contamination rules | Assistive mode does **not** apply F7 `targetMismatch` / contamination FAIL |

**Blockers before first live run:** *(cleared @ `20260624-004036`)*

| Blocker | Owner | Status |
|---------|-------|--------|
| `canPollFileInbox=true` at `readinessSurface=settlement_menu` | **Agent B** | PASS @ cert |
| `inGameAssistReady=true` in Status.json | **Agent B** | PASS @ cert |
| `AssistiveTownToTownProbe` in registry + dev-command-names | **Agent B** | PASS @ cert |
| Attach runner + evidence harvest | **Agent C** / **A** | PASS (A enriched manifest + artifacts) |

---

## PASS criteria (all required — no manifest, no medal)

Evidence under `docs/evidence/live-cert/<sessionId>/checkpoint-01-assistive-town-trade/` (or equivalent gameplay checkpoint).

| Criterion | Source |
|-----------|--------|
| Legitimate in-game session | Fresh Status + classifier timeline agrees |
| `readinessSurface` ∈ `settlement_menu`, `map_surface`, `settlement_interior` | `BlacksmithGuild_Status.json` |
| `canPollFileInbox=true` | Status.json / manifest |
| `inGameAssistReady=true` | Status.json (Agent B) |
| `AssistiveTownToTownProbe` accepted | Dev command bus / Phase1 log |
| `currentSettlement` emitted | Probe output JSON |
| Inventory / trade / market summary from **real** game state | Probe output |
| `recommendedNextTown` emitted | Probe output |
| Trade result: `execute` or `advisory_only` | Probe result; no fabricated deltas |
| Travel: if execution exists → leave town toward target; else `travelCommandMode=advisory_only` or `unavailable` | Probe + optional travel service |
| Evidence committed + pushed | Agent A |

**Manifest shape (expected):** `mode=assistive`, `probeCommand=AssistiveTownToTownProbe`, `passFail=PASS`, `exitCode=0`.

---

## FAIL examples

| Failure | Class / signal |
|---------|----------------|
| Probe command not in runtime | `assistive_command_not_supported` |
| Stale Status during attach | `stale_status` / classifier `UnknownGameSurface` |
| Fake inventory or gold deltas | `fake_gameplay_delta` |
| DevOverride on personal save without policy | `dev_override_forbidden` |
| Probe rejected by dev bus | `probe_rejected` |
| F7 cert-only: `targetMismatch` during **cert** mode | N/A in assistive attach |

---

## Hard limits (all assist / infra certs)

| Limit | Value | Route on breach |
|-------|-------|-----------------|
| Single cert / preflight wall | **10 min** max (no user auth) | Abort; Agent A |
| Launcher Continue / Safe Mode selection | **45 s** total | Fail-fast; Agent C |
| Per-attempt launcher verify | **3–5 s** | Agent C |
| Post-`settlement_menu` MapTransition wait (F7 infra only) | **must not** burn 361s | Agent C — use 15s semantic mismatch |

---

## Runner entry

**Product cert (forward) — attach to already-running game:**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-town-to-town-trade-assist-cert.ps1 -AttachOnly
```

Default behavior (no flags) is attach-only: no launcher, no F7.

| Switch | Behavior |
|--------|----------|
| `-AttachOnly` / `-NoLaunch` | Attach to existing session only; fail if not attachable |
| `-LaunchIfNeeded` | Attach first; call `launcher-auto-nav.ps1 -LaunchSetup` only if attach fails |

**Attach freshness:** live-ready gate — `canPollFileInbox` + `inGameAssistReady`, or `updatedAt` within 300s. Does not use cert-started mtime.

**Target runtime:** under 60s once `inGameAssistReady=true`.

**Legacy full command (same as default attach-only):**

**Infrastructure regression only (not product medal):**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x0F -CertTarget continue
```

Do **not** use the F7 Continue loop as a 20–30 minute treadmill seeking old-gate PASS.

---

## Next cert slices

### Completed

- Advisory town-to-town probe from Quyaz `settlement_menu` (`20260624-004036`)

### Next

| Slice | Owner |
|-------|-------|
| Attach-only re-cert from already-open game (no relaunch) | **Agent A** (after **Agent C** attach runner) |
| Leave-town / travel **execute** path | **Agent B** |
| Open-map trade **execute** path | **Agent B** |
| Smithing assist cert | **Agent B** / product |

### Routing

| Defect | Owner |
|--------|-------|
| Attach-only runner / harvest | **Agent C** |
| Runtime command / probe | **Agent B** |
| Evidence / manifest / PR | **Agent A** |
| Docs drift | **Agent D** |

---

## Related docs

- [`assistive-current-session-attach.md`](assistive-current-session-attach.md)
- [`f7-next-cert-readiness.md`](f7-next-cert-readiness.md) — old F7 closed; hard limits
- [`session-20260623-205925.md`](session-20260623-205925.md) — baseline informative FAIL
- [`external-state-timeline-schema.md`](external-state-timeline-schema.md)
- [`f7-agent-coordination.md`](../../../handoff/f7-agent-coordination.md)
