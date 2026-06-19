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

**Must NOT see:** 40s idle on `InitialState`; `stage stalled for 5s at CharacterCreationCultureStage`.

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

---

## Known gaps (explicit)

| Gap | Notes |
|-----|--------|
| Tutorial skip | Out of scope |
| Launch without Forge | No Layer A; no intent file → in-game auto skipped |
| DPI / multi-monitor | UI Automation may miss buttons; use `-LaunchManual` fallback |
| CAUTION as GPU overlay | Enter-key fallback if UIA cannot find Confirm |
| Launcher UI redesign | Game update may change button names; probe logs all visible IDs |
| Steam vs MS Store path | Script uses csproj `GameFolder`; document if paths differ |

## Risks

| Risk | Mitigation |
|------|------------|
| Double-click PLAY | One-shot flags per dialog type |
| Safe Mode Yes (default focus) | Explicit **No** by name, not Enter |
| Wrong Forge entry | Forge.cmd vs ForgeContinue.cmd documented in dev-disposable-save |
| Option ID drift | Fallback chains + probe log |
| Culture list empty on first tick | Poll retries each tick; failure logged once |

---

## v0.0.11 hotfix root causes (fixed)

| Bug | Symptom | Fix |
|-----|---------|-----|
| Wrong menu IDs | Intent loaded, probe showed `SandBoxNewGame`, no auto-click | Use `SandBoxNewGame` / `ContinueCampaign` fallback chains |
| Culture cast | Stall at culture menu 5s | `GetCultures()` returns `IEnumerable`, not `MBReadOnlyList` |
| Add-Type compile | `[FAIL] open_launcher` — `Invalid expression term 'object'` | C# 5-compatible `out pattern` + `WindowsBase` assembly ref in `launcher-auto-nav.ps1` |

---

## Cert record (fill after live run)

| Path | Result | Date | Notes |
|------|--------|------|-------|
| A — Forge.cmd bootstrap | **PENDING** | | Layer A compile fix verified; full zero-click cert not yet run |
| B — ForgeContinue.cmd | **PENDING** | | |
| Add-Type compile smoke | **PASS** | 2026-06-18 | `launcher-auto-nav.ps1` loads UIAHelper; logs `intent=play` |
