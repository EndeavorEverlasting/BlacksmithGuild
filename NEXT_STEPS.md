# Next Steps

**Daily dev:** `Forge.cmd` — [forge-zero-click-contract.md](docs/forge-zero-click-contract.md)  
**Where we are:** [functionality-status.md](docs/functionality-status.md)  
**Handoff:** [post-007c-track2a-handoff.md](docs/checkpoints/post-007c-track2a-handoff.md)

---

## Sprint status

| Sprint | Status |
|--------|--------|
| 006H | LIVE CERT PASS |
| 006I-2 Path A | **USER PASS** 2026-06-20 — zero-click → Danustica map |
| 006I-4 Path C | **USER PASS** 2026-06-19 — tag `006i-4-path-c-pass` |
| **006I-5 Continue** | **USER PASS** 2026-06-20 — tag `006i-5-continue-pass` @ `52c2114` |
| **005E market intel** | **USER PASS** 2026-06-20 — Ctrl+Alt+M (Continue + Danustica smoke) |
| 005E real forge rank | **Session 2 disposable PASS** + **Track 2A code shipped** — **USER cert on map PENDING** |
| 005E smithing Stage A | **USER PASS** 2026-06-20 — stamina API hints |
| 006J closeout | **PARTIAL** — 1B PASS; 1C format PASS; 1D Path B Back pending |
| **007A hotkey remap** | **DONE** — Ctrl+Alt+M primary |
| **007B report UX** | **USER PASS** 2026-06-20 — Danustica smoke (branding, ACTION PLAN, honest stub JSON) |
| **007C table spacing + Track 2A** | **CODE SHIPPED** — table columns fixed; Real-first on Ctrl+Alt+R — **USER cert PENDING** |

---

## What works right now

| You can… | How |
|----------|-----|
| Bootstrap to map | `Forge.cmd` → Blacksmith Guild — Ready |
| **Continue cared-about save** | `LaunchForgeContinue.cmd` — zero-click Module Mismatch Yes |
| Get buy/sell route plan | **Ctrl+Alt+M** — ACTION PLAN + BUY@NEAREST |
| Rank forge recipes (Real-first on map) | **Ctrl+Alt+M** then **Ctrl+Alt+R** — Real candidates when map ready; stub if Real fails or forced |
| Check mod status | **F7** |
| Fund disposable tests | **F11** (+100k) |

| You cannot yet… | Why |
|-----------------|-----|
| **Track 2A USER PASS on map** | Code shipped; need JSON proof `source=real`, `fallbackUsed=false` |
| Auto buy/sell | Not built — manual town trade |
| Guild loop one-hotkey | Ctrl+Alt+G — Track 3 not built |
| Auto craft / stamina rotation | Stages B–D not built |

---

## Next: Track 2A USER live cert

On **campaign map** (Continue or disposable):

1. **Ctrl+Alt+M** — cache market scan
2. **Ctrl+Alt+R** — Real-first rank
3. **F7** — status snapshot
4. Collect logs (see below)

**PASS when** `BlacksmithGuild_ForgeRecommendations.json`:

```json
"source": "real",
"fallbackUsed": false,
"mappedCount": > 0,
"sourceHonesty": { "verdict": "Pass", ... }
```

Optional: named `materialGaps` (Hardwood, Iron Ore, Charcoal) with buy towns from cached market.

**FAIL / honest degrade:** `fallbackUsed=true` or `source=stub` → do not doc as PASS; check Phase1 for Real probe errors.

Force stub for dev: run `SetForgeCandidateSourceStub` (F8/inbox), then Ctrl+Alt+R stays stub.

---

## Smoke / cert collection (use `-LiteralPath`)

```powershell
$bl = "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord"
Get-Content -LiteralPath "$bl\BlacksmithGuild_MarketIntel.json"
Get-Content -LiteralPath "$bl\BlacksmithGuild_ForgeRecommendations.json"
Get-Content -LiteralPath "$bl\BlacksmithGuild_Status.json"
Get-Content -LiteralPath "$bl\BlacksmithGuild_Phase1.log" -Tail 220
```

Or: `.\CollectCertLogs.cmd`

**Table spacing check:** In Phase1 file report after Ctrl+Alt+M, grep `Top Cross-Town Spreads` — town names like `Husn Fulq` / `Onira` separated from price columns (not `HusnFulq` / `Onirasell`).

---

## Remaining 006J gates

| Step | Action |
|------|--------|
| **1D Path B** | Quit → `Forge.cmd` → culture screen **Back once** (intro must NOT replay) |
| **006J tag** | Approve full closeout tag after 1D |

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` only (no feature branches) |
| Version | `v0.0.11` |
| Remote | ahead of `origin/main` — push when requested |
| Canonical plan | [007a-guild-loop-advisory-automation.plan.md](docs/plans/007a-guild-loop-advisory-automation.plan.md) |

---

## Rollback

```powershell
git checkout 006i-4-path-c-pass
```

Continue cert rollback:

```powershell
git checkout 006i-5-continue-pass
```

Track 2A code rollback:

```powershell
git checkout 162bd78
```
