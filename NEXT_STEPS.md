# Next Steps

**Daily dev:** `Forge.cmd` — [forge-zero-click-contract.md](docs/forge-zero-click-contract.md)  
**Where we are:** [functionality-status.md](docs/functionality-status.md)  
**Handoff:** [post-006i5-continue-cert-handoff.md](docs/checkpoints/post-006i5-continue-cert-handoff.md)

---

## Sprint status

| Sprint | Status |
|--------|--------|
| 006H | LIVE CERT PASS |
| 006I-2 Path A | **USER PASS** 2026-06-20 — zero-click → Danustica map |
| 006I-4 Path C | **USER PASS** 2026-06-19 — tag `006i-4-path-c-pass` |
| **006I-5 Continue** | **USER PASS** 2026-06-20 — tag `006i-5-continue-pass` @ `52c2114` |
| **005E market intel** | **USER PASS** 2026-06-20 — Ctrl+Alt+M (Continue + Danustica smoke) |
| 005E real forge rank | **Session 2 disposable PASS** only — map default stub until **Track 2A** |
| 005E smithing Stage A | **USER PASS** 2026-06-20 — stamina API hints |
| 006J closeout | **PARTIAL** — 1B PASS; 1C format PASS; 1D Path B Back pending |
| **007A hotkey remap** | **DONE** — Ctrl+Alt+M primary |
| **007B report UX** | **USER PASS** 2026-06-20 — Danustica smoke (branding, ACTION PLAN, honest stub JSON) |

---

## What works right now

| You can… | How |
|----------|-----|
| Bootstrap to map | `Forge.cmd` → Blacksmith Guild — Ready |
| **Continue cared-about save** | `LaunchForgeContinue.cmd` — zero-click Module Mismatch Yes |
| Get buy/sell route plan | **Ctrl+Alt+M** — ACTION PLAN + BUY@NEAREST |
| Rank forge recipes (advisory) | **Ctrl+Alt+R** — ACTION PLAN + SOURCE HONESTY (stub until Track 2A) |
| Check mod status | **F7** |
| Fund disposable tests | **F11** (+100k) |

| You cannot yet… | Why |
|-----------------|-----|
| Real forge rank on map (default) | Requested source Stub; Track 2A must wire Real |
| Auto buy/sell | Not built — manual town trade |
| Guild loop one-hotkey | Ctrl+Alt+G — Track 3 not built |
| Auto craft / stamina rotation | Stages B–D not built |

---

## Next engineering: Track 2A (real forge on Ctrl+Alt+R)

1. Set requested source Real before rank (or default Real on Ctrl+Alt+R)
2. PASS only when `BlacksmithGuild_ForgeRecommendations.json` has `source=real`, `fallbackUsed=false`
3. Per-material `materialGaps` + buy steps from cached Ctrl+Alt+M (Hardwood, Iron Ore, Charcoal)
4. Keep advisory only — no inventory mutation

Out of scope: Aserai autobuild, Ctrl+Alt+G, auto-buy/sell.

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

On map: **Ctrl+Alt+M** → **Ctrl+Alt+R** → **F7**

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
| Branch | `main` |
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
