# Sprint 006E — Live cert results

**Status:** Shipped — **live cert pending** (user-run)

**Module version:** v0.0.10

**Plan:** [docs/plans/006e-main-menu-auto-launch.plan.md](plans/006e-main-menu-auto-launch.plan.md)

---

## Zero-click contract

| Entry | Launcher auto | In-game auto | Target |
|-------|---------------|--------------|--------|
| `Forge.cmd` | PLAY | New Campaign → SandBox | Fresh bootstrap → `TBG READY` |
| `ForgeContinue.cmd` | CONTINUE | Continue Campaign | Dev save → `TBG DEVSAVE` / `TBG READY` |

Opt-out: `.\forge.ps1 -Launch -LaunchManual` (opens launcher only).

---

## Path A — Bootstrap (Forge.cmd)

```text
Close Bannerlord → Forge.cmd
→ auto PLAY → auto CAUTION Confirm → auto Safe Mode No (if shown)
→ auto New Campaign → SandBox → 006C intro skip → 006D Poll → TBG READY
```

### PASS signals

**`BlacksmithGuild_Launch.log`** (Bannerlord install root):

```text
launcher-auto: clicked PLAY
launcher-auto: Bannerlord.exe detected — handoff to in-game mod
```

**`BlacksmithGuild_Phase1.log`** (Documents):

```text
[TBG QUICKSTART] launch intent: play
[TBG QUICKSTART] main menu probe: NewGame=... SandBox=...
[TBG QUICKSTART] auto-selecting New Campaign.
using vanilla character creation launch; Poll will auto-advance stages.
```

**Must NOT require:** manual launcher clicks, CAUTION Confirm, Safe Mode choice, main-menu clicks.

---

## Path B — Daily Continue (ForgeContinue.cmd)

```text
Close Bannerlord → ForgeContinue.cmd
→ auto CONTINUE → auto CAUTION Confirm → auto Safe Mode No (if shown)
→ auto Continue Campaign → TBG DEVSAVE / TBG READY
```

### PASS signals

**Launch.log:** `clicked CONTINUE`, `Bannerlord.exe detected`

**Phase1.log:** `launch intent: continue`, `auto-selecting Continue Campaign`

---

## Output files to analyze

```text
<Bannerlord install root>\
  BlacksmithGuild_Launch.log
  BlacksmithGuild_LaunchIntent.json   ← consumed by mod; should disappear after load

Documents\Mount and Blade II Bannerlord\
  BlacksmithGuild_Phase1.log
  BlacksmithGuild_Status.json
```

---

## Known gaps (explicit)

| Gap | Notes |
|-----|--------|
| Tutorial skip | Out of scope |
| Launch without Forge | No Layer A; no intent file → in-game auto skipped |
| DPI / multi-monitor | UI Automation may miss buttons; use `-LaunchManual` fallback |
| CAUTION as GPU overlay | Enter-key fallback if UIA cannot find Confirm |
| Launcher UI redesign | Game update may change button names |
| Steam vs MS Store path | Script uses csproj `GameFolder`; document if paths differ |

## Risks

| Risk | Mitigation |
|------|------------|
| Double-click PLAY | One-shot flags per dialog type |
| Safe Mode Yes (default focus) | Explicit **No** by name, not Enter |
| Wrong Forge entry | Forge.cmd vs ForgeContinue.cmd documented in dev-disposable-save |
| Automation races splash | Poll loop; wait for control enabled |

---

## Cert record (fill after live run)

| Path | Result | Date | Notes |
|------|--------|------|-------|
| A — Forge.cmd bootstrap | | | |
| B — ForgeContinue.cmd | | | |
