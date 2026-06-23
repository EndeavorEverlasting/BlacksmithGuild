# F7 Next Cert Readiness Matrix

**Author:** Agent A — Cert / Evidence / Git / PR  
**Branch:** `fix/f7-gate-stability` @ `0e312e5`  
**Mental model:** [`docs/handoff/f7-agent-mental-model.mmd`](../../../handoff/f7-agent-mental-model.mmd)  
**Gate:** RED — no PASS manifest  
**PR #7:** **HOLD**

---

## Agent identity mapping (from mental model)

| Letter | Identity | Lane | Aliases |
|--------|----------|------|---------|
| **A** | Agent A — Cert / Evidence / Git / PR | Manifest judgment, evidence commit, PR gate | Cert agent, evidence agent |
| **B** | Agent B — Runtime / Readiness / Gameplay safety | `src/**`, MapTransition survival, fail-soft reporting | Runtime agent, readiness agent |
| **C** | Agent C — Launcher / F7 runner / Process detection / Classifier | `scripts/**`, launcher nav, fail-fast poll | Runner agent, launcher agent |
| **D** | Agent D — Docs / Atlas / Integration / Routing board | `docs/**`, coordination, terminology | Atlas agent, archivist |

**Parallel model:** A, B, C, D may work in parallel. **Live F7 cert (Agent A)** waits until B or C lands a relevant fix **or** user explicitly authorizes a diagnostic cert.

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
launchState = fail_contaminated_launch_path | fail_obvious_post_spawn_death | fail_game_gone_definitive
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
| **Runtime survival past update_readiness** | `0e312e5` after `f6370fa` | B | **LANDED** — stabilization lightweight flush; cert pending |
| Optional: manifest fields `obviousFailApplied`, `gameAliveDurationSeconds` | TBD | C | Nice-to-have |
| **User authorization** | Explicit "run diagnostic cert" | User | Required if B fix not landed |

**Agent A live cert gate (pick one):**

1. Agent B commits runtime survival fix addressing `update_readiness` / MapTransition death — **LANDED** (pull latest, preflight, cert) **OR**
2. Agent C commits additional runner manifest audit fields **OR**
3. User explicitly authorizes diagnostic cert (expect FAIL; measure wall-time + markers)

**Do not run blind live cert** without pulling latest B fix and running preflight.

---

## PR #7 HOLD statement

PR #7 remains **HOLD** until **all** of:

- `manifest.passFail = PASS`
- `exitCode = 0`
- `stableSeconds >= 60`
- `campaignReady = true`
- `canPollFileInbox = true`
- `launchPath = continue`
- `targetMismatch = false`
- Evidence committed under `docs/evidence/live-cert/<sessionId>/` and pushed
- **User explicitly authorizes merge**

No merge on clean-launcher FAIL. No merge on runner UX improvement alone. No merge on build PASS.

---

## Preflight commands (Agent A, before next authorized cert)

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
git fetch origin && git checkout fix/f7-gate-stability && git pull origin fix/f7-gate-stability
git merge-base --is-ancestor 4863139 HEAD  # must exit 0
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-log-grep-patterns.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-f7-runner-contract.ps1
Get-Process Bannerlord,TaleWorlds.MountAndBlade.Launcher,Watchdog -ErrorAction SilentlyContinue | Stop-Process -Force
# claim automation lock in f7-agent-coordination.md
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x0F -CertTarget continue
```

---

## Evidence baseline pointers

| Session | Commit | Path |
|---------|--------|------|
| `185813` | `391b186` | `docs/evidence/live-cert/20260622-185813/checkpoint-01-f7-gate/` |
| `192811` | `5d9fe29` | `docs/evidence/live-cert/20260622-192811/checkpoint-01-f7-gate/` |
