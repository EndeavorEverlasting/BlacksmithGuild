# Functionality Status

**Last updated:** 2026-06-20 (007A market hotkey remap)  
**Mod version:** `v0.0.11`  
**Branch:** `main` — 007A Ctrl+Alt+M market intel remap

Canonical snapshot of what works today, what is certified, and what is not built yet.

---

## Recent fixes (2026-06-20)

| Fix | Detail |
|-----|--------|
| **Module Mismatch verify-dismiss** | `52c2114` — retry until `IsAnyInquiryActive` false; `confirmed (inquiry cleared)` log line |
| **forge.ps1 allowlist drift** | `ProbeForgeRecipes`, `ProbeSmithingAudit`, `MarketSnapshotNow`, auto-build commands now in [`scripts/dev-command-names.ps1`](scripts/dev-command-names.ps1) |
| **Forge.cmd false FAIL** | After PLAY click, launcher waits up to 240s for `Bannerlord.exe`; polls Phase1 for `TBG READY` pre-handoff; WARN (not FAIL) if map ready at timeout |

## Certified (user PASS)

| Feature | How to use | Evidence |
|---------|------------|----------|
| **Zero-click bootstrap (Path A)** | `Forge.cmd` | Map + `TBG READY`; PLAY click `(811,764)` fractions `0.34×0.90` |
| **Dev harness hotkeys** | F7 status, F8 command list, F11 +100k gold | Feed ack lines on campaign map |
| **Market intel action plan** | **Ctrl+Alt+M** (legacy F12 off by default) | **USER PASS 2026-06-20** — Continue save: `MarketSnapshotNow`, ACTION PLAN, BUY@NEAREST, TOP SPREADS, nonzero prices. Hotkey collision with Steam F12 fixed; primary key now **Ctrl+Alt+M**. |
| **Real forge rank (Session 2 disposable cert)** | Session 2 script with `SetForgeCandidateSourceReal` | **USER PASS 2026-06-20** — disposable cert: `source=real`, templates=12, top=Javelin, `fallbackUsed=false` |
| **Smithing audit (Stage A)** | `ProbeSmithingAudit` | **USER PASS 2026-06-20** — `GetHeroCraftingStamina`/`SetHeroCraftingStamina` hints |
| **Path C quit loop** | Quit to main menu | Tag `006i-4-path-c-pass` |
| **Continue load (006I-5)** | `LaunchForgeContinue.cmd` | **USER PASS 2026-06-20** — Tevea map; Phase1 `confirmed (inquiry cleared)`; tag `006i-5-continue-pass` @ `52c2114` |

### Continue cert evidence (2026-06-20, cared-about save @ Tevea)

Phase1 (15:18:49):

- `Module Mismatch inquiry queued (event)`
- `Module Mismatch auto-Yes attempt=1 inquiryActive=false`
- `Module Mismatch auto-Yes confirmed (inquiry cleared) source=deferred`
- `TBG READY: campaign map ready`

Fix history: `687cb1b` deferred invoke logged success but dialog persisted; `52c2114` verify-dismiss resolved.

**Market intel smoke test:** USER PASS with hotkey collision. F12 produced useful market action output, but F12 conflicts with Steam screenshots. Primary hotkey changed to **Ctrl+Alt+M**.

**Forge recommendation status:** visible screenshot still shows `source=stub` / fake forge advisor. Real forge candidate ranking is not certified until `BlacksmithGuild_ForgeRecommendations.json` shows `source=real` and `fallbackUsed=false`. Ctrl+Alt+R alone ranks the **requested** source (default Stub) — Track 2A must wire honest real path on Continue saves.

---

## Shipped but not user-certified

| Feature | How to use | PASS criteria | Blocker |
|---------|------------|---------------|---------|
| **Path B culture Back** | Second `Forge.cmd`; press Back on culture screen | Intro cutscene does **not** replay | Not re-certified |
| **Session 3 play loop** | Ctrl+Alt+M + manual trade + Ctrl+Alt+R on Continue save | Market JSON + honest forge source; manual craft baseline | USER smoke pending (Ctrl+Alt+M remap confirmation) |

### Market intel cert evidence (2026-06-20, Continue save near Tevea/Zestica)

Feed showed:

- `source: MarketSnapshotNow`
- nearest Poros; towns=3
- **ACTION PLAN**, **BUY@NEAREST**, **TOP SPREADS** with nonzero prices/spreads
- (Prior Danustica cert: expanded scan fallback 60u/8 towns; Felt → Husn Fulq +880)

JSON: `<Bannerlord>\BlacksmithGuild_MarketIntel.json` with `routeRows`, `actionPlan`, `towns`.

---

## Available today (play loop)

Use on **disposable save** (`Forge.cmd`) or **Continue save** after cert:

```text
1. Ctrl+Alt+M on map → action plan: buy @ nearest, ride to sell town
2. Enter town       → trade manually (no auto buy/sell)
3. Ctrl+Alt+R       → refresh forge recommendations (stub until real source set)
4. Enter smithy     → craft manually (game UI)
5. Ctrl+Alt+M at next town → next route
```

**Funding tests:** F11 (+100k gold) on disposable save only.

**Smithing setup:** Ctrl+Alt+S (rich progression) or inbox `RichSmithingProgressionTest`.

---

## Not built (do not promise)

| Area | Plan doc | Notes |
|------|----------|-------|
| Auto buy/sell | — | Read-only market intel; scope-locked |
| Stamina posse automation (Stages B–D) | [005e-smithing-posse-stamina-output.plan.md](plans/005e-smithing-posse-stamina-output.plan.md) | Blocked on real forge rank cert + API mapping |
| Forge ↔ market bridge | — | RankForgeCandidates ignores market prices for ore sourcing |
| Gauntlet trade UI panel | [005e-market-intelligence-shop-hotkey.plan.md](plans/005e-market-intelligence-shop-hotkey.plan.md) | BACKLOG |
| Travel cost / gold / carry weight in routes | — | Pure price spread ranking only |
| Character doctrine (Aserai Trade-Smith) | [007a-guild-loop-advisory-automation.plan.md](plans/007a-guild-loop-advisory-automation.plan.md) | Planned. Default target is Aserai Trade-Smith with Khuzait mounted fallback. Config/logging only after live-cert gate. |

---

## Hotkey reference

| Key | Action |
|-----|--------|
| F7 | Status summary |
| F8 | Command list |
| F9 | Advance one day |
| F10 | Toggle fast-forward |
| F11 | +100k gold (disposable cert) |
| Ctrl+Alt+M | Market intel action plan (primary) |
| Ctrl+Alt+R | Rank forge candidates |
| Ctrl+Alt+S | Rich smithing progression |
| F12 | Market intel (legacy only; `LegacyF12MarketHotkey=true`; conflicts with Steam) |

Full detail: [in-game-surfaces.md](in-game-surfaces.md)

---

## Output files (Bannerlord install folder)

| File | When written |
|------|--------------|
| `BlacksmithGuild_Phase1.log` | Always — full reports + trace |
| `BlacksmithGuild_MarketIntel.json` | Ctrl+Alt+M |
| `BlacksmithGuild_ForgeRecommendations.json` | Rank / daily tick |
| `BlacksmithGuild_RecipeProbe.json` | `ProbeForgeRecipes` |
| `BlacksmithGuild_SmithingAudit.json` | `ProbeSmithingAudit` |
| `BlacksmithGuild_Launch.log` | Forge.cmd / Continue automation |
| `BlacksmithGuild_Status.json` | F7 |

Collect: `CollectCertLogs.cmd`

---

## Next session

See [007a-guild-loop-advisory-automation.plan.md](plans/007a-guild-loop-advisory-automation.plan.md) — **006J partial closeout done** (Continue PASS); finish Session 3 play loop + Path B, then **Track 2A/2B** (forge materials bridge + honest real forge on Continue).
