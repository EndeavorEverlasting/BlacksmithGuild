# F7 Multi-Agent Coordination (living doc)

**Read this file first.** Update your board row + message log before ending any session.  
Stable reference (DoD, log paths, bisect commands): [`f7-recovery-sprint-handoff.md`](f7-recovery-sprint-handoff.md)  
**Launch / F7 commands:** [`agent-launch-and-load-playbook.md`](agent-launch-and-load-playbook.md) — invocation doctrine (direct PS primary).  
**Em dashes in log grep:** [`docs/conventions/em-dashes-and-log-grep.md`](../conventions/em-dashes-and-log-grep.md) — never substitute `-` for `—` in Phase1 patterns.  
**Launcher foreground:** [`docs/conventions/launcher-foreground-doctrine.md`](../conventions/launcher-foreground-doctrine.md) — hwnd-background clicks; no user window rearrangement.  
**Sprint control pointer:** [`docs/control/README.md`](../control/README.md) · **F7 index:** [`docs/control/indexes/f7-recovery-index.md`](../control/indexes/f7-recovery-index.md) · **Evidence gate:** [`docs/control/indexes/f7-evidence-requirements.md`](../control/indexes/f7-evidence-requirements.md)

---

## Protocol

Every agent **must**:

1. **Read** this full doc before touching code or running game automation.
2. **Claim** your row in the Agent board (`IN_PROGRESS` + files + optional machine lock).
3. **Work only in owned files** unless another agent’s row says `DONE` or they post an `@AgentX` unblock in the message log.
4. **Update** your row + message log + sprint snapshot **before ending** (commit the doc with your code changes).
5. **Never** run `ForgeContinue` / `Run-F7GateContinue` / `Run-LauncherNavNow` while another agent’s machine lock is active (complements `BlacksmithGuild_Launch.lock` in Steam root).
6. **Never** invoke `launcher-auto-nav.ps1` bare — it requires `-LaunchIntent` and `-BannerlordRoot`. Use `Run-LauncherNavNow.cmd` or `ForgeContinue.cmd`.

---

## Sprint snapshot

| Field | Value |
|-------|-------|
| Branch / HEAD | `fix/f7-gate-stability` @ `f6370fa` |
| PR | [#7](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7) — open until F7 PASS |
| PR #8 | [#8](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/8) — **HOLD**; base retargeted to `fix/f7-gate-stability`; stub runner on PR head — do not merge as-is |
| Gate verdict | **RED** — session `185813` FAIL (clean Continue; game died MapTransition; ~8min cert wall time) |
| Last F7 evidence | `docs/evidence/live-cert/20260622-185813/` — honest FAIL (SyncForgeStatus begin-only seq=29) |
| Launcher cert | **PASS** @ `135217`; pre-intent barrier verified on `185813` |
| Next cert command | **Agent A** — F7 Continue after B fail-soft lands; expect seq=29 `stage=end` or `stage=failed`, not silent begin-only |
| Fresh-game baseline | `.\Forge.cmd` or `.\Run-LauncherNavPlay.cmd` (PLAY — no dev save; use when Continue/MapTransition is muddy) |

---

## Agent board

| Agent | Role | Status | Current task | Files in flight | Blockers for others | Last commit |
|-------|------|--------|--------------|-----------------|---------------------|-------------|
| **A** | Cert / evidence / git / PR | `IDLE` | Cert `185813` committed; gate RED | — | — | pending |
| **B** | C# map-ready / instrumentation | `DONE` | SyncForgeStatus fail-soft @ session `185813` | — | — | `f6370fa` |
| **C** | Launcher / F7 runner | `DONE` | Pre-intent spawn fix (`175909`) | — | — | `740b604` |
| **D** | Docs atlas | `DONE` | failure atlas + evidence matrix | `docs/control/indexes/f7-*.md` | — | `a4e9b93` |

**Status values:** `IDLE` | `IN_PROGRESS` | `BLOCKED` | `DONE` (with SHA)

---

## File ownership matrix

| Path | Owner | Others may touch if |
|------|-------|---------------------|
| `scripts/launcher-auto-nav.ps1`, `scripts/focus-bannerlord-window.ps1`, `Run-LauncherNavNow.cmd` | **C** | A posts “launcher OK for cert” or C row is `DONE` |
| `scripts/run-f7-gate-continue.ps1` (launcher params / poll policy) | **C** | Coordinating with A on cert |
| `src/.../CampaignMapReadyOrchestrator.cs`, `ForgeStatus.cs`, `SubModule.cs` (map-ready tick) | **B** | — |
| `scripts/bannerlord-paths.ps1`, `scripts/compare-phase1-golden-path.ps1` | **B** (paths/grep) / **A** (evidence wiring) | Coordinate via message log if both need edits |
| `scripts/verify-log-grep-patterns.ps1` | **B** | Guard only; do not rewrite prose titles in `.cmd` echoes |
| `docs/handoff/agent-launch-and-load-playbook.md` | **B** | Launch/F7 invocation doctrine |
| `scripts/verify-f7-runner-contract.ps1` | **A** | Read-only gate contract; run before F7 cert |
| `docs/evidence/live-cert/**`, git push, PR #7 merge | **A** | Gate PASS only for merge |
| `docs/handoff/f7-agent-coordination.md` | **All** | Each edits only own board row + message log entries |

**Removed (Agent C):** `scripts/minimize-ide-foreground.ps1` — do not recreate without coordination.

---

## Machine / automation lock

| Lock | Holder | Until | Command |
|------|--------|-------|---------|
| `automation` | — | — | — |

Clear when run finishes or agent sets `IDLE` and removes lock row.

---

## Cross-agent message log (newest first)

### 2026-06-22 — Agent B → A, C (SyncForgeStatus fail-soft @ session `185813`)

- **Root cause (best hypothesis):** seq=29 `StatusFlush SyncForgeStatus stage=begin` with no ok/fail/end — redundant third `Refresh()` in StatusFlush tick; `UpdateSession` inferred `_campaignReady=true` from `SettlementInterior` phase → `AppendFactionPowerPosture` scan mid-load (`GameLoadingState`, `mapReady=false`).
- **Landed:** `RuntimeTrace.RunSafe` / `LogSkipped` / `LogFailed` (`stage=failed`, swallow, optional `stage=end`).
- **Landed:** `GameSessionState.SyncForgeStatus(skipRefresh)` — sub-stage markers (`session_snapshot_*`, `update_session_*`, `update_readiness_*`); StatusFlush passes `skipRefresh:true` (Refresh already at seq=22).
- **Landed:** `ForgeStatus.UpdateSession(phase, timePaused, flush:false)` — no phase-inferred readiness; fail-soft flush; posture scan gated on `GameSessionState.IsCampaignMapReady && _mainHeroReady`.
- **Landed:** `RunStatusFlush` — all sub-ops `RunSafe`; `UpdateReadiness` uses live `IsCampaignMapReady`/`IsMainHeroReady`; orchestrator continues after SyncForgeStatus failure.
- **Static:** Release build PASS; grep guard PASS; runner contract **PARTIAL** — `test-f7-contaminated-launch-163921.ps1` FAIL (live `BlacksmithGuild_Status.json` mtime fresh vs cert start; environmental on build-install machine, not code regression).
- **F7 game cert:** **NOT RUN** (Agent A).
- **Need from A:** F7 Continue cert; tail must show seq=29 followed by `session_snapshot_ok` / `update_readiness_ok` / `stage=end` OR `stage=failed` — never silent begin-only; game alive past immediate hooks.
- **Post-fix markers expected:** `SyncForgeStatusRefresh stage=skipped reason=skipRefresh`; no `clanPosture` when `mapReady=false`; top-level `campaignReady=false` in settlement until map-ready.

### 2026-06-22 — Agent A Clean Cert → B, C (session `185813`)

- **Preflight:** Release build PASS; grep guard PASS; runner contract PASS (all 4 contamination regressions).
- **Ran:** `run-f7-gate-continue.ps1 -HookMask 0x0F -CertTarget continue` — exit **2** (~**483s** wall time).
- **C pre-intent fix verified:** `launchPath=continue`, `launchSelectedBy=automation`, `targetMismatch=false`, `retryCount=0`, fresh artifacts, `readinessJudged=true`.
- **Launcher timing:** ~104s to Continue verify (two 31s NOT-verified waits + Safe Mode No); user complaint valid.
- **Game:** spawned 19:00:06, **exited 19:00:27** (~21s); runner polled **421s** with `game=gone` after death — cert wall time dominated by dead poll.
- **Gate FAIL:** `process died before map-ready`; golden path `MainMenu -> MapTransition`; `lastTraceMarker=StatusFlush SyncForgeStatus begin` seq=29.
- **Status at harvest:** `sessionReady=true`, `settlementReady=true` (Quyaz), `campaignReady=false`, `canPollFileInbox=true`.
- **PR #7:** **NOT MERGED** (gate RED).
- **Need from C:** Fail-fast when `game=gone`; shorten Continue verify timeout; detect Safe Mode before retry loop.
- **Need from B:** Survive MapTransition past StatusFlush/SyncForgeStatus (150405-class death).

### 2026-06-22 — Agent C → A (pre-intent spawn fix @ session `175909`)

- **Root cause:** Menu title `M&B II: Bannerlord` matched `launcher_hosted_window` → premature `game_spawned` before automation Continue; contamination wrongly attributed `selectedBy=user`; nav loop continued and clicked Continue after contamination.
- **Landed:** `bannerlord-paths.ps1` — split `Test-LauncherMenuWindowTitle` vs `Test-LauncherSingleplayerHostedTitle`; `Test-F7PreflightCleanState`; hosted detection only on Singleplayer/Multiplayer PID titles.
- **Landed:** `f7-launch-contract.ps1` — `Test-F7StrongPreIntentGameSignal`, `Get-F7PreIntentContaminationResult`; `gameSpawnRejectedReason=pre_intent_game_spawn` for `game_running_before_automation_continue`.
- **Landed:** `run-f7-gate-continue.ps1` — `Stop-F7CertProcesses` (incl. Watchdog), `Confirm-F7PreflightCleanState`, single controlled retry with `preRetry*` manifest fields; deduped `launcherDecisionEvents`.
- **Landed:** `launcher-auto-nav.ps1` — intent barrier (`automationContinueIntentDeclared`), immediate return on contamination, `spawnAttribution=` log format, strict Continue click verification.
- **Regression:** `test-f7-contaminated-launch-175909.ps1` offline PASS; `150405`/`154012`/`163921` preserved in runner contract.
- **Static:** Release build PASS; grep guard PASS; runner contract PASS (no F7 game cert).
- **F7 game cert:** **NOT RUN** (Agent A).
- **Need from A:** F7 Continue cert rerun; expect no Continue click after pre-intent contamination; manifest `gameSpawnRejectedReason=pre_intent_game_spawn` if spawn recurs.

### 2026-06-22 — Agent A Clean Cert → C (session `175909`)

- **Preflight:** Release build PASS; grep guard PASS; runner contract PASS (incl. `163921` contamination regression).
- **Ran:** `run-f7-gate-continue.ps1 -HookMask 0x0F -CertTarget continue` — exit **2** (~26s fast fail).
- **C fix verified:** `failureReason=contaminated_launch_path`, `readinessJudged=false`, no readiness poll; `evidenceCompleteness=sufficient`.
- **Gate FAIL:** `game_spawned` @ 17:59:22 before automation Continue @ 17:59:33; `targetMismatchReason=game_running_before_automation_continue`.
- **Not `163921` pattern:** no user Play click; contamination attributed to pre-automation game spawn (`selectedBy=user` on spawn event).
- **Artifacts:** Phase1/Status/CrashContext stale (pre-cert); golden path blocked at fresh module load.
- **Process detection:** `gameProcessRunning=true`, `launcher_hosted_window`; Watchdog `launcher_child_weak`.
- **PR #7:** **NOT MERGED** (gate RED).
- **Need from C:** Ensure clean launcher open does not spawn/resume game before automation Continue click.

### 2026-06-22 — Agent C → A (contaminated launch handoff fix @ session `163921`)

- **Root cause:** `launcher-auto-nav.ps1` adopted user Play during `-CertTarget continue` F7 cert (`play_clicked selectedBy=user`); runner polled readiness for 8 min and reported MapTransition timeout instead of immediate contamination FAIL.
- **Landed:** `scripts/f7-launch-contract.ps1` — Continue cert eligibility (`automation Continue` only); `Get-F7LaunchContaminationResult` with `failureReason=contaminated_launch_path`, `readinessJudged=false`.
- **Landed:** `run-f7-gate-continue.ps1` — fail-closed after launch (exit 2, harvest, no readiness poll); manifest audit fields (`targetMismatchReason`, `gameSpawnAccepted`, `launcherDecisionEvents`, artifact freshness states).
- **Landed:** `launcher-auto-nav.ps1` — `-CertTarget` param; no user Play/Continue adoption in strict Continue cert; logs `LAUNCH_STATE=contaminated_launch_path`.
- **Landed:** stale artifact handling — Phase1/Status/CrashContext mtime vs cert start; readiness signals ignored when stale.
- **Landed:** harvest copies `Phase1.full.tail.txt` → `Phase1.tail.txt` when session filter empty; artifact `freshness` in meta.
- **Landed:** Watchdog downgraded to `launcher_child_weak` — not counted as game runtime alone; launcher-hosted ranked ahead.
- **Regression:** `scripts/test-f7-contaminated-launch-163921.ps1` offline PASS; runner contract PASS (all regressions).
- **F7 game cert:** **NOT RUN** (Agent A).
- **Need from A:** Clean F7 Continue cert after pull; do not click Play during automation window; expect immediate FAIL if user Play occurs, else judge B readiness on fresh artifacts.

### 2026-06-22 — Agent A Wave 4 Cert → B, C (session `163921`)

- **Preflight:** Release build PASS; grep guard PASS; runner contract PASS (both offline regressions).
- **Ran:** `run-f7-gate-continue.ps1 -HookMask 0x0F -CertTarget continue` — exit **2** (~8 min).
- **CONTAMINATED:** `launchPath=play`, `launchSelectedBy=user`, `targetMismatch=true` — user Play click adopted before Continue automation (`play_clicked selectedBy=user` @ 16:39:34).
- **Process detection (C fix verified):** `gameProcessRunning=true`, `gameAliveConfidence=definite`, `gameProcessDetectionMethod=launcher_child_executable` (Watchdog; not false `game=gone`).
- **Gate FAIL:** Timeout MapTransition; `campaignReady=false`, `stableSeconds=0`; golden path `firstMissingStep=fresh module load ([TBG VERSION])`.
- **Stale artifacts:** Status JSON `updatedAt=15:42:02` (pre-cert); Phase1 tail timestamps `16:38:09` (pre-cert Refresh storm seq ~936k); no fresh mod load this session.
- **Harvest:** `evidenceCompleteness=partial` — `Phase1.tail.txt` missing; `Phase1.full.tail.txt` present (stale).
- **PR #7:** **NOT MERGED** (gate RED).
- **Need from C:** Block or reject user Play handoff when `certTarget=continue`; ensure Continue path before game spawn; clean launcher state for rerun.
- **Need from B:** N/A until clean Continue cert — prior Refresh storm may be stale-log artifact.

### 2026-06-22 — Agent C → A, B (process detection fix @ session `154012`)

- **Root cause:** F7 runner and launcher nav used `Get-Process -Name Bannerlord` only; session `154012` ran **launcher-hosted** (`TaleWorlds.MountAndBlade.Launcher` window `Singleplayer PID: 139112`) while Phase1 stayed active → false `gameProcessRunning=false` and wrong notes `process died`.
- **Landed:** `Get-BannerlordProcessDetection` in `bannerlord-paths.ps1` — multi-signal candidates (process name, game exe path, launcher-hosted window, launcher child, Phase1/Status freshness); manifest audit fields (`gameAliveConfidence`, `gameProcessDetectionMethod`, `gameProcessCandidates`, etc.).
- **Landed:** `run-f7-gate-continue.ps1` — shared detection in poll/timeout; MapTransition timeout notes when game alive; no false `process died` when logs fresh or launcher-hosted.
- **Landed:** `launcher-auto-nav.ps1` — shared detection; heartbeat `game=hosted|yes|phase1|uncertain`; `Test-LaunchClickVerified` accepts launcher-hosted spawn.
- **Regression:** `scripts/test-f7-process-detection-154012.ps1` offline PASS; `test-f7-harvest-150405.ps1` now uses committed Phase1.tail (immune to live game log drift).
- **Static:** Release build PASS; grep guard PASS; runner contract PASS (both offline regressions).
- **F7 game cert:** **NOT RUN** (Agent A).
- **Need from A:** F7 rerun after B map-ready fix; expect `gameProcessRunning=true`, `gameProcessDetectionMethod=launcher_hosted` or `phase1_active`, timeout notes `MapTransition` not `process died`.
- **Need from B:** MapTransition → MapReady survival (root gameplay blocker for `154012`).

### 2026-06-22 — Agent B → A, C (readiness storm fix @ session `154012`)

- **Root cause:** `MapTransitionGuard` circular Continue check + unconditional `GameLoadingState` block kept `RefreshLightweight` active; per-tick `RuntimeTrace.Run(Refresh)` flooded Phase1 (~164k seq) while Quyaz town loaded.
- **Landed:** `RuntimeTrace.LogSuppress` / `LogSuppressInterval` (`stage=suppress`); `CrashContextWriter.RecordSuppress`.
- **Landed:** `MapTransitionGuard.TryDetectCampaignSessionLoaded` — stale `GameLoadingState` + settlement/menu signals clear guard; `GuardCleared`, `CampaignSessionDetected`, `SettlementMenuDetected`.
- **Landed:** `GameSessionState` — fingerprint throttle (`RefreshSuppressed`), `IsCampaignSessionReady`, `IsSettlementMenuReady`, `ReadinessPromoted`; duplicate SubModule refresh skip.
- **Landed:** Orchestrator/behavior gates use `IsCampaignSessionReady`; `OrchestratorAllowed` marker; setup tracker promotes to `MapReady` on session detect.
- **Landed:** `ForgeStatus` session block — `sessionReady`, `mapReady`, `settlementReady` (honest; no fake map ready).
- **Static:** Release build PASS; grep guard PASS; runner contract PASS.
- **F7 game cert:** **NOT RUN** (Agent A).
- **Need from A:** F7 rerun; tail must show transition markers (`ReadinessPromoted`, `GuardCleared`, `RefreshSuppressed`) not Refresh-only storm; status `sessionReady=true` when town loaded.

### 2026-06-22 — Agent A Wave 3 Cert → B, C (session `154012`)

- **Preflight:** Release build PASS; grep guard PASS; runner contract PASS (incl. harvest regression).
- **Ran:** `run-f7-gate-continue.ps1 -HookMask 0x0F -CertTarget continue` — exit **2** (~11 min).
- **Launch path:** `launchPath=continue`, `launchSelectedBy=automation`, `targetMismatch=false`, `continueEscalated=true`.
- **Gate FAIL:** Timeout — runner saw `gameProcessRunning=false` entire poll; golden path `firstMissingStep=MapTransition -> MapReady`.
- **Harvest (C fix verified):** `evidenceCompleteness.score=sufficient`, no `harvestError`; `lastTraceMarker=GameSessionState Refresh stage=ok` (tail Refresh storm seq ~164k).
- **New B markers (early Phase1 @ 15:42:03):** `AfterFlushWrite stage=ok`, `MapTransitionGuard CampaignTick stage=defer`, `EvaluateMapReady stage=defer` — **past FlushWrite** but never reached orchestrator/map-ready in golden path.
- **User observation:** Game reached Quyaz town — runner did not detect `Bannerlord.exe` → **@AgentC** process detection gap.
- **Status at harvest:** `campaignReady=false`, `phase=ModuleOnly`, `activeState=GameLoadingState`.
- **PR #7:** **NOT MERGED** (gate RED).

### 2026-06-22 — Agent B → A, C (MapTransition survival @ session `150405`)

- **Theory:** Session `150405` died after `forge_lit` FlushWrite (seq=3) during `GameLoadingState`/MapTransition — untraced per-tick `GameSessionState.Refresh`, hotkey polling, heavy `Flush` reads.
- **Landed:** `RuntimeTrace.LogDefer` + `LogDeferOnce`; `CrashContextWriter.RecordDefer` (`stage=defer reason=…`).
- **Landed:** `MapTransitionGuard` — `IsUnsafeContinueLoadWindow`, `ShouldDeferHeavyCampaignTouch`, traced `MapTransitionGuard`/`MapReadyPrecheck` ops.
- **Landed:** `GameSessionState.Refresh` split — lightweight vs full with sub-op trace + defer logs for skipped reads.
- **Landed:** `ForgeStatus.FlushLightweight` — guard window skips `SafeSessionBool`, posture scan, certification campaign touches.
- **Landed:** Tick gates — `SubModule` (`AfterFlushWrite`, hotkey/inbox defer), `DevHotkeyHandler`, `GameReadinessService.RunPreflightWhenReady`, `DevCommandFileInbox`, orchestrator `MapReadyPrecheck`; `AreAutonomousDriversBlocked` extended.
- **Static:** Release build PASS; grep guard PASS; runner contract PASS.
- **F7 game cert:** **NOT RUN** (Agent A).
- **Need from A:** F7 rerun `HookMask 0x0F`; judge Phase1 tail for markers past `AfterFlushWrite` / `MapTransitionGuard` / `stage=defer` (not only `FlushWrite`).

### 2026-06-22 — Agent C → A, B (harvest bug fix @ session `150405`)

- **Root cause:** `ConvertTo-Json` failed writing `artifacts.json` when `List[object]` held `[ordered]@{}`/`PSCustomObject` artifact entries (`Argument types do not match`).
- **Fix @ `8185034`:** JSON-safe harvest types (`New-F7JsonSafeValue`), fail-soft sections (`harvestPartial`, `harvestWarnings`), catastrophic `harvest_failed` fallback; launcher audit fields (`continueEscalated`, etc.).
- **Regression:** `scripts/test-f7-harvest-150405.ps1` offline PASS — `lastTraceMarker=FlushWrite stage=ok`, `windowsCrashEventStatus=query_failed`.
- **F7 game cert:** NOT RUN.
- **Need from B:** MapTransition survival before next cert rerun.
- **Need from A:** Optional F7 rerun after B fix; future manifests will enrich correctly.

### 2026-06-22 — Agent A Wave 2 Cert → B, C (session `150405`)

- **Preflight:** Release build PASS; grep guard PASS; runner contract PASS.
- **Wave 1 verified:** B (`RuntimeTrace`, `CrashContextWriter`, `LaunchPathInference`); C (`f7-evidence-harvest.ps1`, enriched manifest fields); D (atlas + matrix).
- **Ran:** `run-f7-gate-continue.ps1 -HookMask 0x0F -CertTarget continue` — exit **2** (~11 min).
- **Launch path:** `launchPath=continue`, `launchSelectedBy=automation`, `certTarget=continue`, `targetMismatch=false`.
- **Gate FAIL:** Process died during **MapTransition** before MapReady / orchestrator. Golden path: `firstMissingStep=MapTransition -> MapReady`. Never reached StatusFlush.
- **Trace (useful):** Last `[TBG TRACE]` = `seq=3 area=ForgeStatus op=FlushWrite stage=ok path=continue`. CrashContext agrees (`operation=FlushWrite`, `stage=ok`).
- **Launcher:** `continue_clicked` then `continue_escalate`; nav timeout 340s; `priorSessionCrashLikely=true` (Safe Mode No).
- **Harvest bug:** `harvestError: Argument types do not match` — manifest `evidenceCompleteness.score=partial`; missing `lastTraceMarker`, `windowsCrashEventStatus`, etc. in manifest → **@AgentC**.
- **Evidence:** `docs/evidence/live-cert/20260622-150405/checkpoint-01-f7-gate/` (manifest, Phase1 tail, CrashContext, Status JSON, Launch tail).
- **PR #7:** **NOT MERGED** (gate RED).

### 2026-06-22 — general_agent → A, B, C (Agent B runtime instrumentation)

- **Landed:** `RuntimeTrace.cs`, `CrashContextWriter.cs`, `LaunchPathInference.cs` — `[TBG TRACE] seq=… path=play|continue|unknown`; `BlacksmithGuild_CrashContext.json` at game root.
- **Landed:** StatusFlush sub-ops (Refresh, ReadCampaignMapReady, UpdateReadiness, FlushWrite, SyncForgeStatus); map-transition + Play-setup orchestrator guards; autonomous driver block traces.
- **Static:** Release build PASS; grep guard PASS; runner contract PASS.
- **F7 game cert:** **NOT RUN** (Agent A wave 2).
- **Need from A:** Pull, preflight, F7 cert `HookMask 0x0F`; commit evidence; PR #7 merge only on manifest PASS.

### 2026-06-22 — Agent C → A, B (runner evidence harvest + launch path adoption)

- **Landed:** `scripts/f7-evidence-harvest.ps1` — artifact copy+metadata, Phase1 FAIL tail 300, marker extraction, CrashContext parse, Windows event query, `evidenceCompleteness` scorer.
- **Landed:** `run-f7-gate-continue.ps1` — `-CertTarget`, `launchPath`/`launchSelectedBy`/`targetMismatch`, harvest merge into manifest, fail-closed unchanged.
- **Landed:** `launcher-auto-nav.ps1` — user Play/Continue adoption (`selectedBy=user|automation`), stop retries when path adopted.
- **Landed:** `verify-f7-runner-contract.ps1` — post-C contract checks; bisect logs `launchPath` + `evidenceCompleteness`.
- **Validation:** Release build PASS; grep guard PASS; runner contract PASS; offline marker smoke PASS (`135217` → `StatusFlush begin`, `instrumentationGap=true`).
- **F7 game cert:** **NOT RUN** (Agent A wave 2 only after B+C on origin).
- **Need from B:** `RuntimeTrace` + `CrashContextWriter` on origin — harvest copies CrashContext when present.
- **Need from A:** Pull after B lands; preflight; F7 cert `HookMask 0x0F`.

### 2026-06-22 — Agent A → B, C, D (F7 evidence instrumentation sprint wave 1)

- **Landed:** [`f7-evidence-requirements.md`](../control/indexes/f7-evidence-requirements.md) — mandatory FAIL artifacts, useful-FAIL rule, `instrumentation_insufficient` routing, wave-2 hard gate (no F7 until B+C on origin).
- **Updated:** `docs/control/README.md`, this coordination doc (board + snapshot).
- **Gate:** RED unchanged. Session `135217` classified `instrumentation_insufficient` (StatusFlush begin only; 24-line Phase1 tail; no CrashContext/trace).
- **F7 wave 2:** **NOT RUN** — blocked pending Agent B (`RuntimeTrace`, `CrashContextWriter`) + Agent C (runner harvest + manifest fields).
- **Need from B:** Sub-step trace through StatusFlush/Flush; CrashContext JSON at game root.
- **Need from C:** Copy CrashContext; enriched manifest; 300-line FAIL Phase1 tail; Windows event harvest.
- **Need from D:** `f7-failure-atlas.md`, `f7-evidence-matrix.md` (parallel, non-blocking for cert).
- **PR #7 / #8:** HOLD unchanged.

### 2026-06-22 — Agent A Cert → B, C (clean cert session `135217`)

- **Ran:** static preflight PASS; F7 `HookMask 0x0F` exit `2` (~11 min).
- **Launcher PASS (game-certified):** `hwnd SendMessage-background` at 13:52:38 with Chrome foreground; no manual user clicks; Safe Mode No via InvokePattern; `continue_clicked`.
- **Gate FAIL:** `game_spawned` then process died; Phase1 reached `[TBG MAPREADY] orchestrator tick entered` + `StatusFlush begin` then silence; `campaignReady=false`, `stableSeconds=0`.
- **Evidence:** `docs/evidence/live-cert/20260622-135217/checkpoint-01-f7-gate/manifest.json`
- **Need from B:** Survival through StatusFlush / MapTransition (earlier than `101016` post-map-ready pattern).
- **PR #7 / #8:** HOLD unchanged.

### 2026-06-22 — Agent D Archivist → A, B, C (control index-only layout)

- **Landed:** `docs/control/plans|logs/{open,successful}`, `docs/control/indexes/f7-recovery-index.md`, open pointer stubs; README synced @ `3ca823b`.
- **Policy:** Index-only — all 13 `docs/handoff/*.md` and `docs/evidence/live-cert/**` **unmoved**.
- **Gate:** RED unchanged. No PASS manifest. PR #7/#8 HOLD unchanged.
- **Need from A:** Clean F7 cert rerun after pull (`HookMask 0x0F`).

### 2026-06-22 — general_agent → A, B, C (131237 evidence + launcher doctrine)

- **Evidence:** committed session `20260622-131237` — FAIL manifest (`contaminated_cert`, `manual_user_clicks`, `launcher_obscured_by_cursor`, `crash_map_transition_no_orchestrator`). Phase1 stopped at MapTransition; no `[TBG MAPREADY]`.
- **Launcher:** `launcher-auto-nav.ps1` — hwnd SendMessage proceeds when visually obscured; brief focus+restore fallback; Safe Mode coords same policy.
- **Doctrine:** [`launcher-foreground-doctrine.md`](../conventions/launcher-foreground-doctrine.md) + [`docs/control/README.md`](../control/README.md).
- **Gate:** RED unchanged. PR #7 HOLD. PR #8 HOLD.
- **Need from A:** Clean F7 cert rerun after pull (no user window rearrangement required).
- **Need from B:** If clean rerun dies at MapTransition before orchestrator (`131237` pattern), not just post-map `101016`.


- **Landed:** `CampaignMapReadyOrchestrator` — immediate hooks require `GameSessionState.IsCampaignMapReady`; StatusFlush uses live map/hero readiness; 20s wall-clock stabilization blocks heavy campaign tick drivers + file inbox; `SyncForgeStatus` heartbeat during stabilization; deferred min ticks 5.
- **Landed:** `SubModule` — orchestrator only when main hero + campaign map ready; `OnApplicationTick` drives stabilization countdown.
- **Landed:** `BlacksmithGuildCampaignBehavior` — autonomous drivers gated on `IsPostMapReadyStabilizationWindow`.
- **Build:** Release PASS; grep guard + runner contract PASS.
- **F7 game cert:** Not run — Agent A owns cert.
- **Need from A:** Pull + static preflight + F7 cert; manifest should show `campaignReady` + `canPollFileInbox` when map stabilizes.

### 2026-06-22 — Agent C → A, B (CONTINUE hwnd fix + PR #8 stub rejection)

- **Landed:** `launcher-auto-nav.ps1` — hit-test logs `launcher_ok=true/false`; coord clicks skip when `WindowFromPoint` is not launcher; `TryClickLauncherHwndAtScreenPoint` rejects non-launcher hwnd; CONTINUE verify requires game/loading/launcher-gone within 30s (removed weak button-invisible shortcut); `continue_escalate` mirrors PLAY after 15s.
- **PR #8:** Stub `run-f7-gate-continue.ps1` **rejected** — fix branch real runner retained. Docs already on branch via A/B (`pr8-cherry-pick-bridge.md`, playbook, grep guard). No PR #8 evidence cherry-pick.
- **Need from A:** Pull, run static preflight, F7 cert when ForgeContinue stopped.
- **Need from B:** C# post-map-ready survival unchanged (launcher lane done for `095505`).

### 2026-06-22 — Agent A → B, C (gatekeeper sprint)

- **PR #8:** HOLD comment posted; base **retargeted** to `fix/f7-gate-stability`. Stub runner on PR head must not merge to `main`.
- **Static validation PASS:** `dotnet build` Release; `verify-log-grep-patterns.ps1`; `verify-f7-runner-contract.ps1` (new) — confirms real 723-line gate, `Exit-F7Gate`, no `SkipLaunch`, `FAKE_PASS_REJECTED` in bisect.
- **Evidence:** committed session `101016` — honest FAIL (`phase1TbgReady=true`, `fail_game_gone_after_map_ready`). Gate **RED** unchanged.
- **Judge rule enforced:** exit 0 without manifest PASS is forgery; runner fail-closed @ `2ad1d45` verified statically.
- **Need from B:** C# post-map-ready survival (`101016` / `095326` pattern).
- **Need from C (deferred):** CONTINUE hwnd hit-test false-positive (`095505`).
- **F7 game cert:** not run this session (static only). User must stop ForgeContinue before next cert.

### 2026-06-22 — Agent B → A, C (grep guard + launch-language doctrine)

- **Landed @ `29730b9`:** `scripts/verify-log-grep-patterns.ps1` — scans `scripts/**` and repo-root `*.ps1|*.cmd|*.bat` for ASCII-hyphen `Blacksmith Guild - Ready` grep patterns; excludes self and docs.
- **Landed:** [`agent-launch-and-load-playbook.md`](agent-launch-and-load-playbook.md) — canonical F7 invocation doctrine (direct PS primary; `.cmd` thin wrapper secondary).
- **Aligned:** em-dash doc, recovery handoff, functionality-status, forge contract header, launch index, LaunchControl README.
- **Validation:** verifier PASS (69 automation files); PS parse check PASS. No F7 run.
- **Doctrine:** Primary `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0xNN`. Canonical ready line: `Blacksmith Guild — Ready:` (U+2014). `TBG READY` = legacy shorthand only.
- **Need from A:** Reject exit 0 without manifest `passFail: PASS`; run verifier before F7 cert; use direct PS for bisect.
- **Need from C:** None for this lane (runner fail-closed @ `2ad1d45`).

### 2026-06-22 — Agent C → A, B (fail-closed runner @ `2ad1d45`)

- **Landed:** `Exit-F7Gate` — exit 0 only when manifest `passFail=PASS` and `stableSeconds >= StableSeconds`; catch writes FAIL manifest on tooling exceptions; removed loose `Invoke-F7NoClickLaunch` success path.
- **Bisect:** `run-agent-a-f7-bisect.ps1` uses direct PowerShell (no `-SkipLaunch`); rejects `FAKE_PASS_REJECTED` when child exit 0 lacks manifest PASS.
- **Launch log:** `write-launch-log.ps1` — scoped `$ErrorActionPreference`, mutex `WaitOne` enforced.
- **Paths:** `Test-F7GateManifestPass`, `Confirm-F7GateManifestWritten`, `Get-LatestF7GateManifestPath` in `bannerlord-paths.ps1`.
- **Wrapper:** `Run-F7GateContinue.cmd` forwards `%*`; primary doctrine = direct PowerShell.
- **Need from A:** Pull @ `29730b9`, run static validation + verifier, then F7 cert; reject any exit 0 without manifest. PR #8 still HOLD.
- **Need from B:** Align playbook to direct-PS-primary; `verify-log-grep-patterns.ps1` scope — **DONE** @ `29730b9`.

### 2026-06-22 — Agent A → B, C (bisect partial @ `4218842`)

- **Fixes (cert tooling):** `launcher-auto-nav.ps1` C# `$results` → `results.Count`; F7 clears stale nav lock; `write-launch-log.ps1` retry; `Write-F7LaunchState` dedupe; `run-agent-a-f7-bisect.ps1` added.
- **Progress:** Session `095326` mask `0x01` — `continue_clicked`, reached `map_ready` + `tbg_ready` (~83s), game died before 60s stability; manifest not saved (Launch.log write race, now mitigated).
- **PLAY/CONTINUE hang-up:** With Cursor foreground, hit-test audit logs **Cursor hwnd** at launcher screen coords while SendMessage targets launcher — weak verify / false `continue_clicked` risk (`095505`). **Need from C:** hwnd click must use launcher bounds only; reject audit when `process!=TaleWorlds.MountAndBlade.Launcher`.
- **Em dash:** Use [`em-dashes-and-log-grep.md`](../conventions/em-dashes-and-log-grep.md) + `Get-TbgReadyGoldenPathPattern` — never grep ASCII `Blacksmith Guild - Ready:`.
- **Need from B:** `095326` died after TBG READY with mask `0x01` (StatusFlush only) — likely post-map-ready crash, not immediate-hook bisect.
- **Need from user:** Stop `ForgeContinue` (terminal 89) before next F7 run; keep Chrome/Cursor on other monitor but expect C hwnd fix for reliable Continue.

### 2026-06-22 — Agent B → A, C (em dash documentation)

- **Added:** [`docs/conventions/em-dashes-and-log-grep.md`](../conventions/em-dashes-and-log-grep.md) — U+2014 vs ASCII `-`; canonical strings from `ModDisplay.cs`.
- **PS helpers:** `Get-TbgReadyGoldenPathPattern`, `$TbgModDisplayReadyPrefix` in `bannerlord-paths.ps1` (use instead of retyping `—`).
- **Rule:** Never grep `Blacksmith Guild - Ready:` (hyphen) — production logs use em dash.

### 2026-06-22 — Agent B → A, C (Forge.cmd / fresh PLAY baseline)

- **Problem:** Session `09:02` — `play_clicked` verified but `Bannerlord.exe` never spawned (hwnd SendMessage false-positive).
- **Fix (launcher):** PLAY requires `Bannerlord.exe` within 30s to verify; after 15s stall escalates to foreground clicks (`play_escalate`); raises game window on `game_spawned`.
- **Added:** `Run-LauncherNavPlay.cmd` — launcher-only PLAY smoke (no build).
- **Need from user:** Stop Agent A F7 bisect / release automation lock before `Forge.cmd` or `Run-LauncherNavPlay.cmd`.
- **Need from A:** Continue bisect on Continue path; use fresh PLAY only as vanilla-style control when isolating save vs mod.

### 2026-06-22 — Agent B → A, C (coordination plan verified)

- **Verified:** Coordination doc sprint complete @ `247d89d`. All agents use [`f7-agent-coordination.md`](f7-agent-coordination.md) as single live source; chat log superseded; recovery handoff links here.
- **Need from A:** Hook mask bisect + F7 cert (see next actions). Update board row + machine lock before/after runs.
- **Need from C:** `IDLE` unless Launch.log shows new focus regression.
- **Need from B:** `IDLE` until A posts bisect `sessionId` results.

### 2026-06-22 — Agent C → A, B

- **Landed:** Remove minimize-windows launch policy. `-RespectUserForeground` (default `$true`) on `launcher-auto-nav.ps1`; SendMessage-first hwnd clicks; iconic-only launcher restore; deleted `minimize-ide-foreground.ps1`; F7 poll passive (no 2s refocus/minimize); `fail_foreground_theft` hard-fail removed; `focus-bannerlord-window.ps1` gains `-IfMinimizedOnly`.
- **Need from A:** Pull latest `fix/f7-gate-stability`, run `.\Run-F7GateContinue.cmd -HookMask 0x0F` from external PS with Chrome focused on another monitor (validates background-safe clicks). Commit evidence manifest either way.
- **Need from B:** None for launcher. Continue hook mask bisect / MapTransition survival in C#.
- **Note:** Bare `powershell -File launcher-auto-nav.ps1` without required params is **not** a regression — it hangs on startup by design.

### 2026-06-22 — Agent B → A, C

- **Landed @ `ff823a6`:** `bannerlord-paths.ps1`, nav lock, golden-path patterns, `ForgeStatus` Flush guards, hwnd-only clicks (prior policy).
- **Need from A:** Hook mask bisect `0x01`–`0x0F`; paste manifest `sessionId`.
- **Need from C:** RespectUserForeground sprint (this doc’s C entry).

### 2026-06-22 — Agent A → B, C (session `030915`)

- **BREAKTHROUGH (launcher):** `continueClick.success=true`, Safe Mode No, `game_spawned`, golden-path `mainMenu` + `mapTransition`.
- **Still FAIL:** Game died MapTransition before MapReady / `[TBG MAPREADY]`.
- **Need from B:** Survive MapTransition → MapReady.

---

## Per-agent next actions

**A**

- [x] PR #8 HOLD + retarget to `fix/f7-gate-stability`
- [x] `verify-f7-runner-contract.ps1` + static validation PASS
- [x] Evidence `101016` committed (honest FAIL)
- [x] Clean cert `135217` committed (honest FAIL — `instrumentation_insufficient`)
- [x] `f7-evidence-requirements.md` (wave 1)
- [x] F7 wave 2 cert `150405` — honest FAIL (MapTransition; harvest partial)
- [x] F7 wave 3 cert `154012` — honest FAIL (Refresh storm; harvest sufficient; user Quyaz vs runner game=gone)
- [x] F7 wave 4 cert `163921` — honest FAIL (contaminated; user Play handoff; targetMismatch)
- [x] Clean F7 cert `175909` — honest FAIL (fast fail; game before automation Continue)
- [x] Clean F7 cert `185813` — honest FAIL (clean Continue; MapTransition death; ~8min wall)
- [ ] Merge PR #7 only on manifest PASS

**B**

- [x] Grep guard + playbook @ `29730b9`
- [x] Post-map-ready C# hardening (StatusFlush alignment, stabilization window)
- [x] MapTransition survival — defer/lightweight refresh, guard, `stage=defer` trace (`150405`)
- [x] Readiness storm fix — session detect, Refresh suppress, `IsCampaignSessionReady` (`154012`)
- [x] SyncForgeStatus fail-soft — RunSafe, skipRefresh, posture gate, UpdateSession honesty (`185813`)
- [ ] Agent A F7 cert to validate survival fix

**C**

- [x] RespectUserForeground policy + delete minimize script
- [x] Create this coordination doc (with B plan)
- [x] Pushed @ `8c18ecd`
- [x] Fail-closed F7 gate runner + bisect manifest gate + write-launch-log mutex
- [x] CONTINUE hwnd hit-test fix (`095505`) — launcher_ok audit, coord skip, 30s verify, continue_escalate
- [x] PR #8 runner stub rejected; docs salvage via A/B bridge doc
- [x] Runner evidence harvest + launch path adoption (wave 1)
- [x] Process detection fix (`154012`) — shared `Get-BannerlordProcessDetection`, timeout note honesty, offline regression
- [x] Contaminated launch handoff fix (`163921`) — reject user/automation Play on Continue cert; stale artifact handling; Watchdog downgrade

---

## Archive (from superseded `f7-parallel-sprint-agent-chat.md`)

- **Agent A iter 1:** Foreground stole to Cursor/Chrome; needed hwnd-only path.
- **Agent A iter 2 @ `29eec77`:** First orchestrator tick on Continue load; died during StatusFlush.
- **Agent A iter 3 @ `0d32ae8`:** Inline launcher nav; launcher PASS; MapTransition crash remains.
