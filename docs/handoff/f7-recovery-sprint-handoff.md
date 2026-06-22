# F7 Game Load Recovery — Sprint Handoff

> **Live coordination:** read [`f7-agent-coordination.md`](f7-agent-coordination.md) first (agent board, locks, message log). This file is stable reference only.

**Branch:** `fix/f7-gate-stability`  
**PR:** https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7 (merge only after F7 PASS)  
**Last Agent B commit scope:** Phases 0–3 tooling + `ForgeStatus` hardening (nav lock, path centralization, launcher focus, golden-path patterns)

---

## Sprint status (Agent B @ 2026-06-22)

| Phase | Status | Notes |
|-------|--------|-------|
| 0 Usability | **DONE** | `RespectUserForeground` default on; nav lock; minimize script removed (Agent C) |
| 1 Logging paths | **DONE** | `scripts/bannerlord-paths.ps1`; Forge prints tail paths |
| 2 Launcher | **DONE** | SendMessage-first hwnd clicks; passive F7 poll; no IDE minimize |
| 3 MapTransition | **PARTIAL** | StatusFlush try/catch audit; orchestrator already logs `[TBG MAPREADY] StatusFlush ok` |
| 4 F7 cert | **PENDING** | Needs external PS run; game still died MapTransition→MapReady in session `030915` |
| 5 Git push | **DONE** | See commit on `origin/fix/f7-gate-stability` |

---

## Definition of done (unchanged)

1. `Forge.cmd` / `ForgeContinue.cmd` — no-click Continue + log path summary at end.
2. `Run-F7GateContinue.cmd -HookMask 0x0F` — exit **0**, manifest `passFail: PASS`, `stableSeconds >= 60`.
3. Golden path — `mapReady` + `mapReadyStatusFlush` + `tbgReady` (now matches `Blacksmith Guild — Ready:`).
4. Desktop usable during `ForgeContinue` and F7 cert (`RespectUserForeground` — no minimize-other-windows).
5. Clean tree pushed to `origin/fix/f7-gate-stability`.

---

## Output paths to analyze after every run

| File | Location |
|------|----------|
| `BlacksmithGuild_Forge.log` | `%USERPROFILE%\Documents\Mount and Blade II Bannerlord\` |
| `BlacksmithGuild_Phase1.log` | **Documents AND** `<Steam BannerlordRoot>\` (check both) |
| `BlacksmithGuild_Launch.log` | `<Steam BannerlordRoot>\` |
| `BlacksmithGuild_Status.json` | Documents (preferred) + Steam root |
| F7 evidence | `docs/evidence/live-cert/<sessionId>/checkpoint-01-f7-gate/manifest.json` |

Helper: `.\forge.ps1 -CollectDiagnostics` or `scripts/collect-diagnostics.ps1`

---

## Known gaps and risks

| Gap / risk | Mitigation |
|------------|------------|
| Concurrent nav (ForgeContinue + F7) | Nav lock + stop extra terminals |
| Chrome/Signal focus theft | `RespectUserForeground` + SendMessage hwnd clicks (no minimize) |
| Dual Phase1 paths | `bannerlord-paths.ps1` |
| Golden-path grep drift | Updated in `compare-phase1-golden-path.ps1` |
| **MapTransition crash** | Hook mask bisect `0x01`–`0x0F`; vanilla Continue control load |
| Large PR #7 evidence history | Stop adding sessions after PASS |
| Agent context loss | Copy-paste prompt below |

---

## Hook mask bisect (Phase 3/4)

Run from **external PowerShell** (stop `ForgeContinue` / other nav first; user may keep Chrome focused on another monitor):

```powershell
git checkout fix/f7-gate-stability && git pull
foreach ($mask in '0x01','0x03','0x07','0x0F') {
  Write-Host "=== HookMask $mask ===" -ForegroundColor Cyan
  .\Run-F7GateContinue.cmd -HookMask $mask
}
```

| Mask | Immediate hooks |
|------|-----------------|
| `0x01` | StatusFlush only |
| `0x03` | + NotifySetupTracker |
| `0x07` | + InGameNotices |
| `0x0F` | + HotkeyTrace (full immediate set) |

Target Phase1 sequence:

```
[TBG VERSION] Loaded assembly
transition: MapTransition -> MapReady
[TBG MAPREADY] orchestrator tick entered
[TBG MAPREADY] StatusFlush ok
Blacksmith Guild — Ready: campaign map ready
```

---

## Parallel sprint option

| Agent | Model | Owns |
|-------|-------|------|
| **Agent C** | Fast implementation | Launcher scripts, focus, lock (landed) |
| **Agent B** | Thinking / C# | `CampaignMapReadyOrchestrator.cs`, `ForgeStatus.cs`, MapTransition bisect |
| **Agent A** | Coordinator | F7 cert, evidence commit, push, PR #7 merge |

---

## COPY-PASTE HANDOFF PROMPT (give any AI agent verbatim)

---

**HANDOFF — BlacksmithGuild F7 recovery**

Repo: `c:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild`  
Branch: `fix/f7-gate-stability`  
PR: https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7 (merge only after F7 PASS)

**Read first:** `docs/handoff/f7-agent-coordination.md` — claim your agent row (A/B/C), respect file ownership, update message log before finishing.

**Goal:** Autonomous Continue → campaign map ready → F7 gate exit 0 with 60s stability.

**Do not:** run multiple launcher automations; invoke `launcher-auto-nav.ps1` without `-LaunchIntent` / `-BannerlordRoot`; merge PR #7 while gate is red.

**Run cert (external PowerShell; stop ForgeContinue; Chrome on another monitor is OK):**
```
git checkout fix/f7-gate-stability && git pull
.\Run-F7GateContinue.cmd -HookMask 0x0F
```

**Fresh game baseline (PLAY — no dev save):**
```
.\Forge.cmd
# or launcher-only smoke:
.\Run-LauncherNavPlay.cmd
```
Do not run PLAY and F7/Continue concurrently (nav lock + coordination machine lock).

**Smoke launcher only:** `.\Run-LauncherNavNow.cmd` (continue) or `.\Run-LauncherNavPlay.cmd` (play)

**Logs (check BOTH Phase1 paths):**
- `%USERPROFILE%\Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Phase1.log`
- `C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log`
- `<BannerlordRoot>\BlacksmithGuild_Launch.log`
- `%USERPROFILE%\Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Forge.log`

**Evidence:** `docs/evidence/live-cert/<yyyyMMdd-HHmmss>/checkpoint-01-f7-gate/manifest.json`

**Known state:** Launcher clicks work (session `030915`). Game dies in MapTransition before MapReady. Agent C landed RespectUserForeground policy (no minimize).

**Priority tasks:** (1) hook mask bisect `0x01`–`0x0F`, (2) F7 PASS evidence commit, (3) merge PR #7 only on PASS.

**Parallel:** Agent A = cert/evidence; Agent B = C# MapTransition; Agent C = launcher (monitor only unless regression).

---
