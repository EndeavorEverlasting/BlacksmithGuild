# Sprint 006E — Live cert results

**Status:** Hotfix shipped (v0.0.11) — **live cert pending** (user-run)

**Module version:** v0.0.11

**Plan:** [docs/plans/006e-main-menu-auto-launch.plan.md](plans/006e-main-menu-auto-launch.plan.md)

---

## Zero-click contract

| Entry | Launcher auto | In-game auto (v1.4.6) | Target |
|-------|---------------|------------------------|--------|
| `Forge.cmd` | PLAY | **`SandBoxNewGame`** | Fresh bootstrap → `TBG READY` |
| `ForgeContinue.cmd` | CONTINUE | **`ContinueCampaign`** | Dev save → `TBG DEVSAVE` / `TBG READY` |

Opt-out: `.\forge.ps1 -Launch -LaunchManual` (opens launcher only).

### v1.4.6 InitialState option IDs (from live probe)

| Visible row | Option ID |
|-------------|-----------|
| SandBox (new game) | `SandBoxNewGame` |
| Continue Campaign | `ContinueCampaign` |
| Story Mode new game | `StoryModeNewGame` |
| Resume | `CampaignResumeGame` |

Legacy IDs (`NewGame`, `SandBox`, `Continue`) are **not** registered on v1.4.6 — hotfix v0.0.11 uses fallback chains.

---

## Path A — Bootstrap (Forge.cmd)

```text
Close Bannerlord → Forge.cmd
→ auto PLAY → auto CAUTION Confirm → auto Safe Mode No (if shown)
→ auto SandBoxNewGame → 006C intro skip → culture auto → TBG READY
```

### PASS signals

**`BlacksmithGuild_Launch.log`** (Bannerlord install root):

```text
launcher-auto: clicked PLAY
launcher-auto: Bannerlord.exe detected — handoff to in-game mod
```

**`BlacksmithGuild_Phase1.log`**:

```text
[TBG QUICKSTART] loaded launch intent=play from ...
[TBG QUICKSTART] main menu probe: ... SandBoxNewGame=visible ...
[TBG QUICKSTART] auto-selecting SandBoxNewGame (SandBox).
[TBG QUICKSTART] culture auto-selected: ... (count=N)
[TBG QUICKSTART] transition: CharacterCreation(CharacterCreationCultureStage) -> CharacterCreation(CharacterCreationFaceGeneratorStage)
using vanilla character creation launch; Poll will auto-advance stages.
```

**Must NOT see:** crash reporter `* _*` dialog blocking UI; `Bannerlord.exe running but crash reporter visible — waiting` indefinitely; `ExecuteInitialStateOptionWithId(SandBoxNewGame) failed` without actionable inner reason.

---

## Path B — Daily Continue (ForgeContinue.cmd)

```text
Close Bannerlord → ForgeContinue.cmd
→ auto CONTINUE → auto CAUTION Confirm → auto Safe Mode No (if shown)
→ auto ContinueCampaign → TBG DEVSAVE / TBG READY
```

### PASS signals

**Launch.log:** `clicked CONTINUE`, `Bannerlord.exe detected`

**Phase1.log:** `launch intent: continue`, `auto-selecting ContinueCampaign (Continue Campaign).`

---

## Output files to analyze

```text
<Bannerlord install root>\
  BlacksmithGuild_Launch.log
  BlacksmithGuild_LaunchIntent.json   ← removed after successful menu auto-select
  rgl_log_*.txt                       ← after crash; via -CollectDiagnostics
  diagnostic-summary.txt

Documents\Mount and Blade II Bannerlord\
  BlacksmithGuild_LaunchIntent.json   ← dual-written by Forge; same consume rules
  BlacksmithGuild_Phase1.log
  BlacksmithGuild_Status.json
```

---

## v0.0.11 hotfix root causes (fixed)

| Bug | Symptom | Fix |
|-----|---------|-----|
| Wrong menu IDs | Intent loaded, probe showed `SandBoxNewGame`, no auto-click | Use `SandBoxNewGame` / `ContinueCampaign` fallback chains |
| Culture cast | Stall at culture menu 5s | `GetCultures()` returns `IEnumerable`, not `MBReadOnlyList` |
| Add-Type compile | `[FAIL] open_launcher` — `Invalid expression term 'object'` | C# 5-compatible `out pattern` + `WindowsBase` assembly ref in `launcher-auto-nav.ps1` |
| Layer A no PLAY click | Launch.log stops at `intent=play`; UIA searched desktop root only | Launcher-scoped `FindLauncherRoot()` + `ClickButtonByNameInLauncher()` with name variants |
| Crash reporter blocks funnel | TaleWorlds `* _*` dialog; user must click Yes/No manually | `HasCrashReporterDialog()` + `ClickCrashReporterNo()`; defer handoff until dismissed |
| Menu execute too early | `ExecuteInitialStateOptionWithId` throws `TargetInvocationException` | Strict `InitialState` execute gate + 1.0s warmup; log `InnerException` message |

---

## Crash reporter diagnostics

If the TaleWorlds crash reporter (`* _*` — "The application faced a problem...") appears during cert:

1. Layer A should auto-click **No** (skip upload; faster dev loop). Use **Yes** manually when filing bug reports.
2. Collect engine logs:

```powershell
.\forge.ps1 -CollectDiagnostics
```

3. Analyze under Bannerlord install root:

```text
rgl_log_*.txt
diagnostic-summary.txt
BlacksmithGuild_Launch.log
```

---

## Known gaps (explicit)

| Gap | Notes |
|-----|--------|
| Engine crash root cause | Crash reporter dismiss unblocks UI; may need `-CollectDiagnostics` for `rgl_log` |
| Tutorial skip | Out of scope |
| Launch without Forge | No Layer A; no intent file → in-game auto skipped |
| DPI / multi-monitor | Launcher-scoped UIA helps; may still miss; timeout logs visible launcher buttons |
| CAUTION as GPU overlay | Enter-key fallback if UIA cannot find Confirm |
| Launcher UI redesign | Game update may change button names; probe logs all visible IDs |
| Steam vs MS Store path | Script uses csproj `GameFolder`; document if paths differ |
| Click No loses crash telemetry | Dev loop priority; document Yes for bug reports |
| PLAY name differs by locale | `ClickButtonByNameInLauncher` tries case variants; timeout logs button names |

## Risks

| Risk | Mitigation |
|------|------------|
| Double-click PLAY | One-shot flags per dialog type |
| Safe Mode Yes (default focus) | Explicit **No** by name, not Enter |
| Wrong Forge entry | Forge.cmd vs ForgeContinue.cmd documented in dev-disposable-save |
| Option ID drift | Fallback chains + probe log |
| Culture list empty on first tick | Poll retries each tick; failure logged once |
| SandBoxNewGame still throws after timing fix | `InnerException` log guides next fix |
| Handoff while crash dialog visible | Block handoff until `HasCrashReporterDialog()` is false |

---

## Cert record (fill after live run)

| Path | Result | Date | Notes |
|------|--------|------|-------|
| A — Forge.cmd bootstrap | **PARTIAL PASS** | 2026-06-18 | Launch funnel + culture + face OK; stalled at Family (006F fix) |
| B — ForgeContinue.cmd | **PENDING** | | |
| Add-Type compile smoke | **PASS** | 2026-06-18 | `launcher-auto-nav.ps1` loads UIAHelper; logs `intent=play` |
