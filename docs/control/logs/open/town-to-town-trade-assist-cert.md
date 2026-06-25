# Town-to-Town Trade Assist Cert

**Owner:** Agent A — Cert / Evidence / Git / PR (live runs) · **Spec:** Agent D  
**Branch:** **`main`** @ `09f039f`  
**Status:** **PASS** — advisory @ `004036`/`020821` · travel execute @ `032408` (PR #11 **MERGED**)  
**Runner (advisory):** [`scripts/run-town-to-town-trade-assist-cert.ps1`](../../../scripts/run-town-to-town-trade-assist-cert.ps1)  
**Execute cert:** Agent C runner on `fix/pr11-unattended-execute-cert-runner` (separate until merged)

---

## Completed product medals

| Session | Path | Notes |
|---------|------|-------|
| **`20260624-032408`** | [`manifest.json`](../../evidence/live-cert/20260624-032408/checkpoint-01-assistive-travel-execute/manifest.json) | **Travel execute** PASS — Quyaz → Ortysia (`travelCommandMode=execute`, `launchUsed=true`, PR #11) |
| **`20260624-004036`** | [`manifest.json`](../../evidence/live-cert/20260624-004036/checkpoint-01-assistive-town-trade/manifest.json) | Town-to-Town Trade Assist **PASS** with launcher setup path (advisory) |
| **`20260624-020821`** | [`manifest.json`](../../evidence/live-cert/20260624-020821/checkpoint-01-assistive-town-trade/manifest.json) | **Attach-only** advisory PASS (`launchUsed=false`, `mode=assistive_attach`, ~5s) |

### Honest FAILs (regression context — PR #10)

| Session | `failureClass` | Cause |
|---------|----------------|-------|
| `20260624-020430` | `assistive_probe_failed` | Stale inbox sequence=1 after game consumed seq=2 |
| `20260624-020644` | `assistive_probe_failed` | Same class — fixed before `020821` PASS |

**PR #10** (`test-forge-command-sequence-after-prior-ack.ps1`) protects: next command becomes sequence=3 even when consumed markers are buried above noisy trace-only tail.

---

## Authoritative PASS fields (both sessions)

| Field | Value |
|-------|-------|
| **Cert name** | Town-to-Town Trade Assist Cert |
| **Surface** | `settlement_menu` @ Quyaz |
| **Recommended next town** | Ortysia |
| **Trade execution** | `advisory_only` |
| **Travel command mode** | `advisory_only` |
| **`fakeGameplayDelta`** | `false` |
| **`canPollFileInbox`** | `true` |
| **`inGameAssistReady`** | `true` |
| **`canAcceptAssistiveCommand`** | `true` |

### Current product state

- **Travel execute** proven on `main` @ PR #11 — `AssistiveLeaveTownAndTravel` with `execute=true` (`032408`).
- **Advisory probe** remains valid product evidence (`004036`, `020821`).
- **Trade** still `advisory_only` — no real buy/sell execution yet.
- **Attach-only execute cert** not run — optional Agent A follow-up (`launchUsed=false`).
- **No fake gold**, **no fake inventory**, **no fake travel**.

### What PASS proves (by lane)

**Advisory (`004036`, `020821`):**

- In-game assistive command readiness from a legitimate session.
- Advisory gameplay output: settlement context, recommended next town, no fabricated deltas.

**Travel execute (`032408`):**

- Real leave-town + map travel toward target settlement (`actualExecutionObserved=true`).
- `certSummaryPassCandidate=true`; movement observation passed.
- Probe lane remains advisory-only (no travel side effects on probe command).

### What this PASS does **not** prove

- **Real buy/sell execution** — `tradeExecution=advisory_only` only.
- **Attach-only execute path** — `032408` used launch-assisted cert (`launchUsed=true`).
- **Execute inbox ack within timeout** — ack timed out; execution JSON proved PASS.
- Launcher automation purity — F7 infrastructure, not product medal for assist lanes.

---

## Product framing

Old F7 Continue cert is **closed** as infrastructure (informative FAIL @ [`20260623-205925`](../../evidence/live-cert/20260623-205925/checkpoint-01-f7-gate/manifest.json)). **Town-to-Town Trade Assist** on **`main`** is the **product gate**.

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

- Advisory town-to-town probe from Quyaz `settlement_menu` (`20260624-004036` — setup path)
- Attach-only advisory PASS from existing session (`20260624-020821`, `launchUsed=false`)
- Inbox sequence regression coverage (**PR #10**)
- **Travel execute** from settlement menu (`20260624-032408`, PR #11 **MERGED**)

### Next (product lane)

1. **Runtime gameplay state machine** — Agent B @ `69263a9` (rebase onto `09f039f`)
2. **Unattended execute cert runner** — Agent C @ `70e5404` (rebase onto `09f039f`)
3. **Optional attach-only execute cert** — Agent A
4. **Open-map trade execute** where safe
5. **Smithing assist cert**
6. **Trade + smithing route loop** (`feat/006c-4*` — rebase if revived)

### Routing

| Defect | Owner |
|--------|-------|
| Unattended execute runner / harvest | **Agent C** @ `70e5404` |
| Runtime state machine / trade execute | **Agent B** @ `69263a9` |
| Evidence / manifest / optional attach-only execute | **Agent A** |
| Docs drift | **Agent D** |

---

## Related docs

- [`assistive-current-session-attach.md`](assistive-current-session-attach.md)
- [`f7-next-cert-readiness.md`](f7-next-cert-readiness.md) — old F7 closed; hard limits
- [`session-20260623-205925.md`](session-20260623-205925.md) — baseline informative FAIL
- [`external-state-timeline-schema.md`](external-state-timeline-schema.md)
- [`blacksmithguild-agent-coordination.md`](../../../handoff/blacksmithguild-agent-coordination.md)
