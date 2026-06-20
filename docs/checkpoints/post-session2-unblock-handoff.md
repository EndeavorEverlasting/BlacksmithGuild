# Handoff — Session 2 Unblock (2026-06-20)

Copy-paste this entire document to the next AI agent.

---

## Mission state

| Item | Status |
|------|--------|
| Path A bootstrap | **USER PASS** — Forge.cmd → Danustica, TBG READY |
| F12 market action plan | **USER PASS** 2026-06-20 — ACTION PLAN + BUY@NEAREST |
| Session 2 real forge rank | **USER CERT PENDING** — script fixed, user must re-run |
| Forge.cmd launcher timeout | **FIX SHIPPED** — 240s post-PLAY, TBG READY poll, WARN not FAIL |
| forge.ps1 allowlist drift | **FIX SHIPPED** — `scripts/dev-command-names.ps1` |

---

## What was fixed this sprint

1. **`scripts/dev-command-names.ps1`** — single allowlist synced with `DevCommandRegistry.cs`
2. **`scripts/forge-status.ps1`** — `Send-ForgeCommand` uses shared list (fixes `ProbeForgeRecipes` unknown command)
3. **`scripts/launcher-auto-nav.ps1`** — post-PLAY 240s extension; pre-handoff `TBG READY` poll; boundary success
4. **`scripts/install-mod.ps1`** — `open_launcher` = WARN if timeout but Phase1 has TBG READY

---

## User next steps (Session 2)

**Precondition:** Campaign map loaded, `TBG READY` seen.

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\scripts\run-session2-real-forge.ps1
```

Sequence: `ProbeForgeRecipes` → `SetForgeCandidateSourceReal` → `RankForgeCandidates` → doctrine toggle → re-rank → `ProbeSmithingAudit`.

**In-game verify:**

- **F7** — top forge line `source=real` (not stub)
- **Ctrl+Alt+R** — re-rank after doctrine change

**JSON verify:**

```powershell
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_ForgeRecommendations.json"
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_RecipeProbe.json"
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_SmithingAudit.json"
```

**PASS:** RecipeProbe templates > 0; ForgeRecommendations `source=real`; doctrine change alters top candidate.

**FAIL stop:** `fallbackUsed=true` or stub Long Warblade — debug `ForgeRealCandidateMapper.cs`.

---

## After Session 2 — Session 3

```powershell
# Quit Bannerlord fully
.\LaunchForgeContinue.cmd
```

Play loop: F12 (trade routes) → manual trade → Ctrl+Alt+R (forge) → smithy craft.

---

## Known gaps

| Gap | Notes |
|-----|-------|
| Auto buy/sell | Read-only F12 advisory |
| Stamina automation B–D | Blocked on real forge cert + API |
| Forge ↔ market bridge | RankForgeCandidates ignores prices for ore |
| Gauntlet trade UI | BACKLOG |
| Continue load re-cert | LaunchForgeContinue + Module Mismatch log |
| Path B culture Back | Not re-certified |
| Slow spawn edge case | WARN if map ready at timeout; still close Chrome during Forge.cmd for reliability |

---

## Risks

| Risk | Mitigation |
|------|------------|
| Allowlist drift again | Add new C# commands to `dev-command-names.ps1` |
| Bannerlord running blocks DLL install | Close game before Forge.cmd |
| Real forge falls back to stub | Do not start stamina automation |
| 22+ commits unpushed | Push when user requests |

---

## Output paths

| File | Purpose |
|------|---------|
| `BlacksmithGuild_Phase1.log` | TBG READY, reports, hotkey trace |
| `BlacksmithGuild_Launch.log` | PLAY click, handoff, timeout/WARN |
| `BlacksmithGuild_ForgeRecommendations.json` | Real rank evidence |
| `BlacksmithGuild_RecipeProbe.json` | Recipe template probe |
| `BlacksmithGuild_SmithingAudit.json` | Stage A stamina API |
| `BlacksmithGuild_MarketIntel.json` | F12 routes (cert PASS) |
| `BlacksmithGuild_Status.json` | F7 reload state |
| `CollectCertLogs.cmd` | Aggregated cert block |

---

## Key docs

- [docs/functionality-status.md](../functionality-status.md)
- [NEXT_STEPS.md](../../NEXT_STEPS.md)
- [docs/forge-zero-click-contract.md](../forge-zero-click-contract.md)
- [docs/in-game-surfaces.md](../in-game-surfaces.md)

---

## Copy-paste prompt for next agent

```text
BlacksmithGuild Bannerlord mod — Session 2 real forge rank cert.

DONE:
- Path A PASS, F12 market intel USER PASS (Danustica action plan)
- forge.ps1 allowlist fixed (dev-command-names.ps1)
- Forge.cmd false FAIL fixed (240s post-PLAY, TBG READY poll, WARN)

USER TASK:
1. With campaign loaded: .\scripts\run-session2-real-forge.ps1
2. F7 source=real; Ctrl+Alt+R re-rank
3. Verify ForgeRecommendations.json + RecipeProbe.json + SmithingAudit.json
4. LaunchForgeContinue.cmd for play loop

DO NOT start stamina automation until real rank PASS.

Read: docs/checkpoints/post-session2-unblock-handoff.md, docs/functionality-status.md, NEXT_STEPS.md
```

---

## What NOT to do

- Do not promise auto buy/sell or stamina posse
- Do not push unless user asks
- Do not bump version unless user asks
