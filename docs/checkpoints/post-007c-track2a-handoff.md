# Handoff — 007C Track 2A Code Shipped (2026-06-20)

Copy-paste this entire document to the next AI agent.

---

## Mission state

**007C engineering DONE.** Table spacing + Track 2A Real-first rank shipped on `main`. **Track 2A USER live cert PENDING.** **006J 1D Path B PENDING.**

Prior closeout: **007B USER PASS** @ `162bd78` (Danustica smoke — Ctrl+Alt+M, branding, forge ACTION PLAN stub honest, file verdict fix).

---

## What was shipped this session

| Change | File(s) | Behavior |
|--------|---------|----------|
| **Market table spacing** | `src/BlacksmithGuild/Market/MarketTableFormatter.cs` | ITEM 16 / town 18 cols; ellipsis truncation; double-space between text columns; fixes Phase1 `Onirasell` / `HusnFulq` collisions |
| **Track 2A Real-first rank** | `src/BlacksmithGuild/Forge/ForgeRecommendationService.cs` | `GetResolutionKind`: Ctrl+Alt+R on campaign map → Real; `_stubExplicitlyRequested` when `SetForgeCandidateSourceStub`; campaign-smoke unchanged |
| **Honesty copy** | `src/BlacksmithGuild/Forge/ForgeAdvisoryPlanner.cs` | Stub message references `SetForgeCandidateSourceStub` to force stub |
| **Docs** | `docs/functionality-status.md`, `NEXT_STEPS.md`, `docs/plans/007a-guild-loop-advisory-automation.plan.md` | Track 2A code shipped; USER cert pending |

**Build:** Release succeeded; DLL installed to Bannerlord Modules (game may need reload if was running during prior session).

---

## Certified (USER PASS — do not re-litigate)

| Feature | Hotkey / trigger | Evidence |
|---------|------------------|----------|
| Market intel | **Ctrl+Alt+M** | Continue + Danustica 2026-06-20; ACTION PLAN, BUY@NEAREST, TOP SPREADS |
| 007B report UX | **Ctrl+Alt+R**, **F7** | Blacksmith Guild headers, colored sections, SOURCE HONESTY, ACTION PLAN (stub labeled) |
| 007A hotkey | **Ctrl+Alt+M** primary | F12 legacy off by default |
| Continue load | `LaunchForgeContinue.cmd` | tag `006i-5-continue-pass` @ `52c2114` |
| Real forge (scripted) | Session 2 disposable + `SetForgeCandidateSourceReal` | JSON `source=real`, Javelin top |
| Path A bootstrap | `Forge.cmd` | TBG READY |
| Path C quit | quit loop | tag `006i-4-path-c-pass` |
| Smithing Stage A | `ProbeSmithingAudit` | stamina API hints |

---

## NOT certified (next live certs)

| Priority | Gate | Owner | PASS criteria |
|----------|------|-------|---------------|
| **1** | **Track 2A map rank** | USER | After Ctrl+Alt+M → Ctrl+Alt+R on map: JSON `source=real`, `fallbackUsed=false`, `mappedCount>0`, `sourceHonesty.verdict=Pass` |
| **2** | **006J 1D Path B** | USER | Quit → `Forge.cmd` → culture **Back once** → intro does NOT replay |
| **3** | **Table spacing visual** | USER (optional) | Phase1 file `Top Cross-Town Spreads` — readable town names |

---

## USER smoke protocol (Track 2A)

```powershell
# Close Bannerlord if open, then:
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\Forge.cmd
# On campaign map:
#   Ctrl+Alt+M
#   Ctrl+Alt+R
#   F7

$bl = "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord"
Get-Content -LiteralPath "$bl\BlacksmithGuild_MarketIntel.json"
Get-Content -LiteralPath "$bl\BlacksmithGuild_ForgeRecommendations.json"
Get-Content -LiteralPath "$bl\BlacksmithGuild_Status.json"
Get-Content -LiteralPath "$bl\BlacksmithGuild_Phase1.log" -Tail 220
```

Or: `.\CollectCertLogs.cmd`

**PASS JSON tail (forge):**

```json
"source": "real",
"fallbackUsed": false,
"mappedCount": 12,
"sourceHonesty": {
  "requested": "Real",
  "resolved": "real",
  "verdict": "Pass"
}
```

**FAIL / honest degrade:** `source=stub`, `stub-fallback`, or `fallbackUsed=true` → `[WARN]`/`[INFO]` in feed; do not mark PASS in docs.

**Force stub (dev):** inbox/F8 `SetForgeCandidateSourceStub` then Ctrl+Alt+R → stays stub.

---

## Output paths to analyze

All under Bannerlord install folder unless noted:

| File | Written when | What to check |
|------|--------------|---------------|
| `BlacksmithGuild_Phase1.log` | Always | Hotkey Success lines; MARKET/FORGE file report tables; `[PASS]`/`[INFO]`/`[WARN]` verdicts |
| `BlacksmithGuild_MarketIntel.json` | Ctrl+Alt+M | `routeRows`, `actionPlan`, `nearestTown` |
| `BlacksmithGuild_ForgeRecommendations.json` | Ctrl+Alt+R | `source`, `fallbackUsed`, `mappedCount`, `sourceHonesty`, `materialGaps`, `actionPlan` |
| `BlacksmithGuild_Status.json` | F7 | Compact forge/market summary — use `-LiteralPath` (path has `&`) |
| `BlacksmithGuild_RecipeProbe.json` | Real probe side-effect | Template counts if Real fails |
| `BlacksmithGuild_Launch.log` | Forge.cmd | Bootstrap / Module Mismatch |
| `Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Status.json` | forge.ps1 fallback | Alternate status location |

**Repo docs:** `docs/functionality-status.md`, `NEXT_STEPS.md`, `docs/plans/007a-guild-loop-advisory-automation.plan.md`

---

## Known gaps

| Gap | Notes |
|-----|-------|
| **Track 2A USER cert** | Code shipped; no in-game proof yet on Continue/disposable map |
| **006J 1D Path B** | Culture Back not re-run |
| **006J full tag** | Blocked on 1D |
| **Track 2B** | `--- FORGE MATERIALS ---` section in market report — not built |
| **Ctrl+Alt+G guild loop** | Track 3 — formatting groundwork only |
| **Aserai autobuild** | After live-cert gate |
| **Auto buy/sell** | Scope-locked |
| **Push to origin** | `main` ahead ~36 commits; push only when user requests |
| **Real probe on early campaign load** | `ForgeAdvisorSmokeTest` still uses stub (`campaign-smoke` source) — intentional |

---

## Risks

| Risk | Mitigation |
|------|------------|
| Real mapping fails on Continue save (smithing locked, no templates) | JSON shows `fallbackUsed=true` + `[WARN]`; cert stays FAIL until real resolves |
| Bannerlord running blocks DLL install | Close game before `Forge.cmd` / Release build |
| Status.json `Get-Content` fails | Use `-LiteralPath` or `CollectCertLogs.cmd` — not a mod bug |
| Real-first overrides dev stub expectation | Call `SetForgeCandidateSourceStub` explicitly to force stub on map |
| Large unpushed commit stack | Single `main` branch; no feature branches; push when user ready |

---

## Key code paths (Track 2A)

```
Ctrl+Alt+R (DevHotkeyHandler)
  → DevCommandBus.TryRun(RankForgeCandidates)
  → ForgeRecommendationService.RunRankNow(source=RankForgeCandidatesCommand)
  → GetResolutionKind(source)
       Real if: map ready AND NOT _stubExplicitlyRequested
       else: _requestedSourceKind (Stub for campaign-smoke)
  → ResolveCandidates(Real|Stub)
  → ForgeAdvisoryPlanner.BuildMaterialGaps (per-material when MaterialNeeds[])
  → MarketIntelligenceService.TryFindBuyAtNearest (cached Ctrl+Alt+M)
  → WriteJsonReport + WriteStructuredReport
```

**Files:**

- `src/BlacksmithGuild/Forge/ForgeRecommendationService.cs` — `GetResolutionKind`, `_stubExplicitlyRequested`
- `src/BlacksmithGuild/Forge/ForgeAdvisoryPlanner.cs` — material gaps, action plan
- `src/BlacksmithGuild/Forge/RealForgeCandidateSource.cs` — real candidate probe
- `src/BlacksmithGuild/Market/MarketTableFormatter.cs` — Phase1 table layout
- `src/BlacksmithGuild/Market/MarketIntelligenceService.cs` — full file report tables L760–780

---

## Repo hygiene

| Check | Status |
|-------|--------|
| Branch | `main` only (local + origin) |
| Working tree | Should be clean after 007C commit |
| Open PRs | None expected |
| Stashes | None expected |

**Daily dev:** `Forge.cmd`  
**Continue save:** `LaunchForgeContinue.cmd`

---

## Next agent tasks (in order)

1. Confirm user Track 2A smoke results; update `docs/functionality-status.md` if PASS
2. If FAIL: read `BlacksmithGuild_ForgeRecommendations.json` + Phase1; diagnose Real probe (`ForgeRecipeProbeService`, `ForgeRealCandidateMapper`)
3. User runs 006J Path B when ready; tag `006j-closeout-pass` after PASS
4. Future: Track 2B market FORGE MATERIALS section, then Ctrl+Alt+G guild loop (007A plan)
5. Push to origin only when user explicitly requests

---

## Scope lock

- No Aserai culture / character autobuild
- No Ctrl+Alt+G guild loop implementation
- No auto-buy/sell, inventory mutation, Stage D optimizer
- No push unless requested

---

## Rollback tags

```powershell
git checkout 162bd78   # before 007C (007B closeout only)
git checkout 006i-5-continue-pass
git checkout 006i-4-path-c-pass
```
