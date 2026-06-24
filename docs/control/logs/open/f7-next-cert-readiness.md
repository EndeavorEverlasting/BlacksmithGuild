# F7 Next Cert Readiness Matrix

**Author:** Agent A — Cert / Evidence / Git / PR (co-maintained with Agent D)  
**Branch:** `fix/f7-gate-stability`  
**Gate:** **GREEN (assist)** — Town-to-Town Trade Assist **PASS** @ [`20260624-004036`](../../evidence/live-cert/20260624-004036/checkpoint-01-assistive-town-trade/manifest.json)  
**PR #7:** **HOLD** — assist PASS is product medal; await explicit user merge auth

---

## Old F7 Continue gate — CLOSED (informative infrastructure)

**Session:** [`20260623-205925`](../../evidence/live-cert/20260623-205925/checkpoint-01-f7-gate/manifest.json) · stub: [`session-20260623-205925.md`](session-20260623-205925.md)

Old F7 Continue is **closed as informative infrastructure**, not the product gate.

| Proven | Detail |
|--------|--------|
| Launcher | `launchPath=continue`, `targetMismatch=false`, `continueClick.success=true` |
| Gameplay surface | Quyaz `settlement_menu`; `campaignReady=true`; game alive (`launcher_hosted`) |
| Death class cleared | seq=8115 / post-spawn death — **GONE** on this session |
| Old semantics exposed | `canPollFileInbox=false` at time of cert; golden path expected `MainMenu -> MapTransition`; stale old-gate semantics |

**Do not rerun** old F7 as a **product gate** or MapTransition treadmill.

**Old F7 may be used only** as a **targeted smoke test** when launcher / Continue **automation itself** changes — not to prove in-game assist readiness.

**Medals:**

| Gate | Status |
|------|--------|
| Old F7 Continue PASS | **Not** the current sprint medal |
| Town-to-Town Trade Assist PASS | **Current product medal** @ [`20260624-004036`](../../evidence/live-cert/20260624-004036/checkpoint-01-assistive-town-trade/manifest.json) |

**Next live product cert:** attach-only re-cert from already-open game (see [`assistive-current-session-attach.md`](assistive-current-session-attach.md)).

---

## Town-to-Town Trade Assist — PASS @ `20260624-004036`

| Criterion | Result |
|-----------|--------|
| `passFail` / `exitCode` | PASS / 0 |
| `readinessSurface` | `settlement_menu` @ Quyaz |
| `canPollFileInbox` | `true` |
| `inGameAssistReady` | `true` |
| `AssistiveTownToTownProbe` | ack Success |
| `recommendedNextTown` | Ortysia |
| `tradeExecution` | `advisory_only` |
| `travelCommandMode` | `advisory_only` |
| Fake deltas | none (`fakeGameplayDelta=false`) |

Evidence: [`checkpoint-01-assistive-town-trade/manifest.json`](../../evidence/live-cert/20260624-004036/checkpoint-01-assistive-town-trade/manifest.json)

---

## Hard limits (all certs / preflight)

| Limit | Value | Route on breach |
|-------|-------|-----------------|
| Single cert / preflight wall | **10 min** max (no user auth) | Abort; Agent A |
| Launcher Continue / Safe Mode selection | **45 s** total | Fail-fast; Agent C |
| Per-attempt launcher verify | **3–5 s** | Agent C |
| Post-`settlement_menu` MapTransition wait | **must not** burn 361s | Agent C — 15s semantic mismatch |

---

## Agent identity mapping (from mental model)

| Letter | Identity | Lane | Aliases |
|--------|----------|------|---------|
| **A** | Agent A — Cert / Evidence / Git / PR | Manifest judgment, evidence commit, PR gate | Cert agent, evidence agent |
| **B** | Agent B — Runtime / Readiness / Gameplay safety | `src/**`, MapTransition survival, fail-soft reporting | Runtime agent, readiness agent |
| **C** | Agent C — Launcher / F7 runner / Process detection / Classifier | `scripts/**`, launcher nav, fail-fast poll | Runner agent, launcher agent |
| **D** | Agent D — Docs / Atlas / Integration / Routing board | `docs/**`, coordination, terminology | Atlas agent, archivist |

**Parallel model:** A, B, C, D may work in parallel. **Live gameplay cert (Agent A)** runs only after B+C unblock assist probe. **Old F7 Continue** is infrastructure/regression only — closed as product gate.

---

## Known clean launcher signature (both baseline sessions)

Both `20260622-185813` and `20260622-192811` prove the launcher path is no longer the primary blocker:

| Field | Required value |
|-------|------------------|
| `launchPath` | `continue` |
| `certTarget` | `continue` |
| `launchSelectedBy` | `automation` |
| `targetMismatch` | `false` |
| `targetMismatchReason` | `null` |
| `failureReason` | `null` (not `contaminated_launch_path`) |
| `gameSpawnRejectedReason` | `null` |
| `gameSpawnAccepted` | `true` |
| `retryCount` | `0` |
| `continueClick.success` | `true` |
| `safeModeNoClicked` | `true` (when Safe Mode appears) |
| `readinessJudged` | `true` |
| `phase1ArtifactState` | `fresh` |
| `statusArtifactState` | `fresh` |
| `evidenceCompleteness.score` | `sufficient` |

**Interpretation:** Continue automation succeeded; cert entered readiness poll honestly. Further FAILs are **runtime death** or **runner poll UX**, not launch contamination.

---

## Known runtime-death signature (current gate blocker)

| Signal | `185813` | `192811` |
|--------|----------|----------|
| Game alive after spawn | ~21s | ~19s |
| `campaignReady` | `false` | `false` |
| `canPollFileInbox` | `true` | `true` |
| Status `sessionReady` | `true` (Quyaz) | `true` |
| Status `settlementReady` | `true` | `true` |
| Status `mapReady` | `false` | progressed (`mapReady=true` in snapshot @ 192811) |
| `goldenPathCheck.firstMissingStep` | `MainMenu -> MapTransition` | `MainMenu -> MapTransition` |
| `priorSessionCrashLikely` | `true` | `true` |
| `gamePhaseAtEnd` | `e` | `e` |
| `passFail` | `FAIL` | `FAIL` |

**Shared death class:** `process_died_before_map_ready` — game exits during MapTransition / StatusFlush while top-level `campaignReady=false`.

### Last trace comparison

| Session | Last trace | CrashContext | B fix markers |
|---------|------------|--------------|---------------|
| `185813` @ `391b186` | `StatusFlush op=SyncForgeStatus stage=begin` seq=29 | `SyncForgeStatus begin` | Pre-`f6370fa` — **no** `session_snapshot_ok` / `stage=end` |
| `192811` @ `5d9fe29` | `StatusFlush op=update_readiness stage=begin` seq=142 | `update_readiness begin` | Post-`f6370fa` — **has** `session_snapshot_ok`, `update_session_ok`; died **after** SyncForgeStatus sub-stages |

**Routing:** **Agent B** — death moved past seq=29 but still no stable survival to 60s / `campaignReady=true`.

### Runner poll waste (192811 only)

| Session | Wall time | Poll after game gone | Runner fix |
|---------|-----------|----------------------|------------|
| `185813` | ~483s | ~421s with `game=gone last=e` | Predates `4863139` |
| `192811` | ~445s | ~360s+ same pattern | Predates `4863139` |

**Routing:** **Agent C** — `4863139` adds `fail_obvious_post_spawn_death` when `game_spawned + gone + last=e`. Next cert must include `4863139+` and expect **≤~10s** post-death poll, not 300s+.

---

## Required manifest fields (next live cert)

Agent A judges **manifest.json only**. Every field below must be present and populated (not null where noted):

### Identity / launch

- `sessionId`, `passFail`, `exitCode`, `startedAtUtc`, `endedAtUtc`
- `launchPath`, `certTarget`, `launchSelectedBy`, `targetMismatch`, `targetMismatchReason`
- `failureReason`, `gameSpawnAccepted`, `gameSpawnRejectedReason`, `spawnAttribution`, `retryCount`
- `readinessJudged`, `launchState`

### Readiness / gate

- `stableSeconds`, `campaignReady`, `canPollFileInbox`
- `phase1TbgReady`, `phase1QuickStartMapReady`, `phase1LastSignal`
- `goldenPathCheck.available`, `goldenPathCheck.firstMissingStep`

### Process detection audit

- `gameProcessRunning`, `gameAliveConfidence`, `gameProcessDetectionMethod`
- `gameProcessCandidates`, `processDetectionLastSeenUtc`
- `processTimestamps.gameStartUtc`, `processTimestamps.gameEndUtc`

### Evidence harvest

- `evidenceCompleteness.score`, `evidenceCompleteness.missing`
- `lastTraceMarker`, `lastCrashContextOperation`, `lastCrashContextStage`, `lastCrashContextArea`
- `phase1ArtifactState`, `statusArtifactState`, `crashContextArtifactState`
- `phase1TailLineCount`, `Launch.tail.txt`, `Phase1.tail.txt` present

### Artifacts

- `manifest.json`, `Launch.tail.txt`, `Phase1.tail.txt`
- `BlacksmithGuild_Status.json` copied (freshness recorded)
- `BlacksmithGuild_CrashContext.json` copied when present

---

## PASS criteria (all required — no manifest, no medal)

```text
manifest exists under docs/evidence/live-cert/<sessionId>/checkpoint-01-f7-gate/
passFail = PASS
exitCode = 0
stableSeconds >= 60
campaignReady = true
canPollFileInbox = true
launchPath = continue
certTarget = continue
targetMismatch = false
readinessJudged = true
evidenceCompleteness.score = sufficient
gameProcessRunning = true during stability window (or strong alive signal documented)
Phase1/Status artifacts fresh for cert window
evidence committed and pushed by Agent A
PR #7 merge ONLY after above + explicit user authorization
```

**Good runtime signs (not sufficient alone):**

- `RefreshSuppressed`, `ReadinessPromoted`, `GuardCleared`, `SettlementMenuDetected`, `OrchestratorAllowed`
- `Blacksmith Guild — Ready:` (em dash) or `phase1TbgReady=true`
- StatusFlush sub-stages complete with `stage=ok` or honest `stage=failed` + `stage=end` — never silent `begin`-only

---

## Immediate FAIL criteria (abort honest; do not poll for minutes)

```text
targetMismatch = true
launchPath != continue (when certTarget=continue)
failureReason = contaminated_launch_path
gameSpawnRejectedReason = pre_intent_game_spawn
launchState = fail_contaminated_launch_path | fail_obvious_post_spawn_death | fail_game_gone_definitive | fail_settlement_menu_semantic_mismatch
process died before map-ready (manifest notes or failureReason)
game_spawned + game gone + phase1LastSignal = e + not everMapReady (4863139+)
gameAliveDurationSeconds < 60 AND campaignReady = false AND stableSeconds = 0
evidenceCompleteness.score != sufficient
manifest missing core fields listed above
exitCode = 0 without passFail = PASS (forgery — reject)
```

**Wall-time expectation post-`4863139`:** If game dies with `last=e`, cert should FAIL within **~10 seconds** of death, not full `PollTimeoutSec`.

---

## Commits / fixes required before next live cert

| Gate | Commit / condition | Owner | Status |
|------|-------------------|-------|--------|
| Obvious post-spawn fail-fast | `4863139`+ on branch | C | **LANDED** |
| Safe Mode before Continue retry | `1e27bfb`+ | C | **LANDED** |
| Pre-intent spawn rejection | `740b604`+ | C | **LANDED** |
| Contamination guard | `77059f8`+ | C | **LANDED** |
| SyncForgeStatus fail-soft (partial) | `f6370fa` | B | **LANDED** — 192811 progressed past seq=29 but still died |
| **Runtime survival past update_readiness** | `cc6fbac` | B | **SUPERSEDED** — grace OK; death @ `200917` seq=8115 (fixed @ `e891b33`) |
| **Post-unblock fail-soft + surface telemetry** | `e891b33` | B | **VALIDATED** @ `204227` — past seq=8115; `settlement_menu_open` defer; surface fields present |
| **Runner false game-gone + harvest** | `705d2be` | C | **VALIDATED** (202052, 195817, 200917) |
| **Runner poll tooling exception** | A/C fixes | A/C | **FIXED** @ poll hardening — `205925` full 361s poll |
| **MapTransition timeout at settlement_menu** | `9bdc759` | C | **LANDED** — 15s `fail_settlement_menu_semantic_mismatch` |
| `canPollFileInbox @ settlement_menu` | `e4c261d` | B | **LANDED** — validated @ `20260624-004036` |
| **AssistiveTownToTownProbe** | `e4c261d` | B | **LANDED** — PASS @ `20260624-004036` |
| **Attach-only assist re-cert** | TBD | A/C | **NEXT** — open game, no relaunch |
| Optional: manifest fields `obviousFailApplied`, `gameAliveDurationSeconds` | TBD | C | Nice-to-have |
| **User authorization** | Explicit merge auth | User | Required for PR #7 merge |

**Agent A live cert gate:**

1. ~~Agent B assist inbox + probe~~ **PASS** @ `20260624-004036`
2. **Next:** attach-only re-cert from already-open game (**Agent C** runner + **Agent A** evidence)
3. Old F7: infrastructure smoke only when launcher automation changes

**Status JSON semantics (unchanged top-level `campaignReady`):** reflects `IsCampaignMapReady` (MapState active). New session fields disambiguate surface:

| Field | Quyaz town menu example |
|-------|-------------------------|
| `sessionReady` | `true` |
| `campaignReady` / `mapReady` | may be `true` (MapState) |
| `readinessSurface` | `settlement_menu` |
| `settlementMenuOpen` | `true` |
| `campaignMapSurfaceOpen` | `false` |

F7 Continue **product** PASS at settlement menu requires manifest criteria **and** assistive forward path — old golden-path-only gate is closed. Evidence must show surface fields clearly.

**Do not run blind old-F7 treadmill** seeking legacy MapTransition PASS.

---

## PR #7 HOLD statement

PR #7 remains **HOLD** until **explicit user merge authorization**.

- **Town-to-Town Trade Assist PASS** exists @ `20260624-004036` — this is the **current product medal**.
- **Old F7 Continue PASS** is **not** required for the current sprint medal.
- Do **not** merge without user authorization.

Legacy F7 PASS criteria apply only if repo policy explicitly requires old infrastructure gate PASS:

- `manifest.passFail = PASS`
- `exitCode = 0`
- `stableSeconds >= 60`
- `campaignReady = true`
- `canPollFileInbox = true`
- `launchPath = continue`
- `targetMismatch = false`
- Evidence committed under `docs/evidence/live-cert/<sessionId>/` and pushed

No merge on clean-launcher FAIL. No merge on runner UX improvement alone. No merge on build PASS.

---

## Preflight commands (Agent A, before authorized cert)

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
git fetch origin && git checkout fix/f7-gate-stability && git pull origin fix/f7-gate-stability
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-log-grep-patterns.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-f7-runner-contract.ps1
Get-Process Bannerlord,TaleWorlds.MountAndBlade.Launcher,Watchdog -ErrorAction SilentlyContinue | Stop-Process -Force
# claim automation lock in f7-agent-coordination.md
# Product cert (attach-only — preferred):
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-town-to-town-trade-assist-cert.ps1 -AttachOnly
# Optional infra validation only (expect ~15s semantic FAIL post-9bdc759):
# powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x0F -CertTarget continue
```

---

## Evidence baseline pointers

| Session | Commit | Path |
|---------|--------|------|
| `185813` | `391b186` | `docs/evidence/live-cert/20260622-185813/checkpoint-01-f7-gate/` |
| `192811` | `5d9fe29` | `docs/evidence/live-cert/20260622-192811/checkpoint-01-f7-gate/` |
| `202052` | `319588f` | `docs/evidence/live-cert/20260622-202052/` — B validated; C false fail @ 61s |
| `195817` | `b19dcb3` | Death seq=8063 immediate post-`StabilizationEnd` |
| `200917` | cert commit | Death seq=8115 after `HeavyFlushUnblocked` — grace lifecycle validated |
| `204227` | fd2a190 | B validated; poll abort Access denied (fixed in later commits) |
| `205925` | `2207468` | `docs/evidence/live-cert/20260623-205925/checkpoint-01-f7-gate/` — closed infrastructure FAIL |
| `004036` | `c13e75b` | `docs/evidence/live-cert/20260624-004036/checkpoint-01-assistive-town-trade/` — **product PASS** (advisory) |
