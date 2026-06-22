# F7 evidence requirements

**Branch:** `fix/f7-gate-stability`  
**Owner:** Agent A (cert / evidence gate)  
**Authority:** [`f7-agent-coordination.md`](../../handoff/f7-agent-coordination.md) · **Recovery index:** [`f7-recovery-index.md`](f7-recovery-index.md)  
**Policy:** No manifest, no medal. Exit 0 without manifest `passFail=PASS` is forgery.

---

## Purpose

Define mandatory artifacts and manifest fields for every F7 Continue gate run (`scripts/run-f7-gate-continue.ps1`). A FAIL is only **useful** when it identifies the **last completed** operation and the **next attempted** operation. If evidence stops at coarse markers (e.g. `[TBG MAPREADY] StatusFlush begin` with no sub-steps), classify as **`instrumentation_insufficient`** and route back to Agent B (runtime trace) and Agent C (runner harvest).

**Baseline gap (session `135217`):** Phase1 ends at line 24 — `StatusFlush begin` — with no `[TBG TRACE]` sub-ops, no `BlacksmithGuild_CrashContext.json`, and no manifest marker fields. See [`Phase1.tail.txt`](../../evidence/live-cert/20260622-135217/checkpoint-01-f7-gate/Phase1.tail.txt).

---

## Mandatory checkpoint directory layout

Every cert writes under:

```
docs/evidence/live-cert/{sessionId}/checkpoint-01-f7-gate/
```

| Artifact | Requirement | Owner | Notes |
|----------|-------------|-------|-------|
| `manifest.json` | **Required** | A (runner writes; A commits) | Must include fields below |
| `Launch.tail.txt` | **Required** | C | Timestamp-filtered tail of `BlacksmithGuild_Launch.log` |
| `Phase1.tail.txt` | **Required** | C | ≥ 200 lines when log has that many since launch; **target 300** on FAIL path post–Agent C |
| `BlacksmithGuild_Status.json` | Copy if present at game root | C | Steam/Documents Bannerlord root |
| `BlacksmithGuild_CrashContext.json` | Copy if present at game root | B writes · C copies | Post–Agent B instrumentation sprint |
| `WindowsCrashEvents.json` | Copy if harvested | C | Or explicit `windowsCrashEventStatus` in manifest |

---

## Manifest — required fields (all runs)

These exist today unless noted **(post-C)**:

| Field | Required | Purpose |
|-------|----------|---------|
| `checkpoint` | yes | Always `checkpoint-01-f7-gate` |
| `sessionId` | yes | `yyyyMMdd-HHmmss` |
| `passFail` | yes | `PASS` or `FAIL` |
| `exitCode` | yes | Runner exit code |
| `startedAtUtc` / `endedAtUtc` | yes | Wall-clock bounds |
| `stableSeconds` | yes | Must be ≥ 60 for PASS |
| `hookMask` / `mapReadyHookMask` | yes | Bisect audit |
| `launchState` | yes | Final launch automation state |
| `continueClick` | yes | Launcher cert audit |
| `campaignReady` | yes | Gate condition |
| `canPollFileInbox` | yes | Gate condition |
| `phase1TbgReady` | yes | Em-dash ready line seen |
| `phase1LastSignal` | yes | Last Phase1 line at poll end |
| `gameProcessRunning` | yes | Process state at harvest |
| `notes` | yes | Human-readable verdict + tags |

### Manifest — enriched fields **(post-C sprint)**

| Field | Purpose |
|-------|---------|
| `evidenceCompleteness` | Checklist object — which artifacts copied / why missing |
| `lastPhase1Marker` | Last `[TBG MAPREADY]` or em-dash ready line in Phase1 tail |
| `lastTraceMarker` | Last `[TBG TRACE]` line (requires Agent B) |
| `lastCrashContextOperation` | From CrashContext JSON `operation` |
| `lastCrashContextStage` | From CrashContext JSON `stage` (`begin` / `ok` / `fail`) |
| `statusJsonCopied` / `crashContextCopied` / `windowsCrashEventCopied` | Booleans |
| `phase1TailLineCount` / `launchTailLineCount` | Line counts in harvested tails |
| `runnerCommandLine` | Full invocation audit |
| `hookMask` (duplicate ok) | Same as env `TBG_MAP_READY_HOOK_MASK` |
| `processTimestamps` | Game start/end if observable |
| `artifactMeta` | Per-file `{ path, bytes, lastWriteUtc }` |
| `windowsCrashEventStatus` | `not_available` \| `query_failed` \| `none_found` \| `copied` |

`verify-f7-runner-contract.ps1` must statically require post-C keys once Agent C lands.

---

## PASS criteria (gate judge)

Agent A certifies PASS **only** when **all** hold:

1. Runner exit code **0** (`Exit-F7Gate` fail-closed guard satisfied).
2. Repo manifest at `docs/evidence/live-cert/{sessionId}/checkpoint-01-f7-gate/manifest.json` exists and is committed.
3. `passFail` = `"PASS"`.
4. `stableSeconds` ≥ **60**.
5. `campaignReady` = **true**.
6. `canPollFileInbox` = **true** (or equivalent gate signals per `Test-F7GateCondition`).
7. Phase1 shows em-dash ready (`Blacksmith Guild — Ready:`) or `phase1TbgReady` = true.

**PR #7 merge:** only after a committed PASS manifest on `fix/f7-gate-stability`.

---

## FAIL criteria — honest FAIL vs useless FAIL

### Honest FAIL (acceptable)

- Process died at a **named sub-operation** with trace + CrashContext agreement.
- Example (target post-B): last `stage=ok` = `Refresh`, next `stage=begin` = `FlushWrite` → route fix to B.
- Manifest `notes` tags failure mode (`fail_statusflush_begin`, `fail_game_gone_after_map_ready`, etc.).

### Useless FAIL — `instrumentation_insufficient`

Trigger when **any** of:

| Condition | Action |
|-----------|--------|
| Last Phase1 marker is only `[TBG MAPREADY] StatusFlush begin` with no `[TBG TRACE]` after it | Route **Agent B** |
| No `lastTraceMarker` in manifest and no `[TBG TRACE]` in Phase1 tail | Route **Agent B** |
| `crashContextCopied` = false and game died mid-StatusFlush | Route **Agent B** + **Agent C** |
| `phase1TailLineCount` < 200 when Phase1 log has ≥ 200 session lines | Route **Agent C** |
| Missing `evidenceCompleteness` post-C | Route **Agent C** |

Do **not** treat such a FAIL as proof of fix or regression — re-run cert only after B+C land.

---

## Useful FAIL identification rule

For every FAIL manifest review, Agent A must record:

| Question | Source |
|----------|--------|
| **Last completed marker** | Last `[TBG TRACE] … stage=ok` or last MAPREADY line before silence |
| **Next attempted marker** | Last `[TBG TRACE] … stage=begin` or `CrashContext.lastBegin` |
| **Agreement** | CrashContext `operation`/`stage` matches Phase1 tail terminus |
| **Routing** | B = runtime / C# · C = runner harvest · both if completeness gap |

If only coarse `StatusFlush begin` appears → set manifest `notes` suffix `instrumentation_insufficient` and **do not merge PR #7**.

---

## Pre-flight (before any F7 cert)

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
git checkout fix/f7-gate-stability
git pull origin fix/f7-gate-stability
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-log-grep-patterns.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-f7-runner-contract.ps1
```

### Hard gate — do not run F7 until:

| Dependency | Proof on `origin/fix/f7-gate-stability` |
|------------|----------------------------------------|
| Agent B | `RuntimeTrace.cs`, `CrashContextWriter.cs`; `[TBG TRACE]` in StatusFlush path |
| Agent C | `Save-CheckpointEvidence` copies CrashContext; manifest enriched fields; contract verifier updated |

Agent D atlas/matrix docs are **informational** — not blocking cert.

---

## F7 cert command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x0F
```

- No manual clicks; Chrome/Cursor foreground allowed (launcher game-certified @ `135217`).
- Stop `ForgeContinue` / release automation lock before run.
- Commit entire `docs/evidence/live-cert/{sessionId}/` tree regardless of PASS/FAIL.
- Update [`f7-agent-coordination.md`](../../handoff/f7-agent-coordination.md) message log.

---

## Doctrine reminders (Blacksmith Guild)

- VanillaLegit + Assistive — automate hands, not consequences.
- Do not teleport, fake gold/inventory/smelt, inject Smithing 275, or use DevOverride on personal saves.
- Build PASS ≠ game PASS. Implemented ≠ certified.

---

## Session compliance snapshot (pre-sprint)

| Session | manifest | Phase1.tail | Status JSON | CrashContext | Trace sub-ops | Verdict |
|---------|----------|-------------|-------------|--------------|---------------|---------|
| `135217` | yes | 24 lines | no | no | no | **instrumentation_insufficient** |
| `131237` | yes | yes | varies | no | no | contaminated cert |
| `101016` | yes | yes | yes | no | no | post-map-ready FAIL |
| `095326` | yes | yes | varies | no | no | died after TBG READY |
| `030915` | yes | yes | varies | no | no | MapTransition FAIL |

See [`f7-evidence-matrix.md`](f7-evidence-matrix.md) (Agent D) and [`f7-failure-atlas.md`](f7-failure-atlas.md) when landed.

---

## Related docs

- [`f7-recovery-index.md`](f7-recovery-index.md)
- [`f7-failure-atlas.md`](f7-failure-atlas.md) *(Agent D)*
- [`f7-evidence-matrix.md`](f7-evidence-matrix.md) *(Agent D)*
- [`../README.md`](../README.md)
- [`../../conventions/em-dashes-and-log-grep.md`](../../conventions/em-dashes-and-log-grep.md)
