# Next Steps

**Daily dev:** `Forge.cmd` — [forge-zero-click-contract.md](docs/forge-zero-click-contract.md)  
**Where we are:** [functionality-status.md](docs/functionality-status.md)

---

## Sprint status

| Sprint | Status |
|--------|--------|
| 006H | LIVE CERT PASS |
| 006I-2 Path A | **USER PASS** 2026-06-20 — zero-click → Danustica map |
| 006I-4 Path C | **USER PASS** 2026-06-19 — tag `006i-4-path-c-pass` |
| 006I-5 Continue | SHIPPED — **re-cert PENDING** |
| **005E market intel** | **USER PASS** 2026-06-20 — F12 action plan @ Danustica |
| 005E real forge rank | **USER PASS** 2026-06-20 — `source=real`, Javelin top, templates=12 |
| 005E smithing Stage A | **USER PASS** 2026-06-20 — stamina API hints in SmithingAudit.json |
| 006J closeout | PARTIAL — Path B Back pending |

---

## What works right now

| You can… | How |
|----------|-----|
| Bootstrap to map | `Forge.cmd` → `TBG READY` |
| Fund trading tests | **F11** (+100k) |
| Get buy/sell route plan | **F12** — ACTION PLAN + BUY@NEAREST |
| Check mod status | **F7** |
| Rank forge (stub default) | Load → daily tick or **Ctrl+Alt+R** after real source set |
| Probe smithing API | Session 2 script or inbox `ProbeSmithingAudit` |

| You cannot yet… | Why |
|-----------------|-----|
| Auto buy/sell | Not built — manual town trade |
| Auto craft / stamina rotation | Stages B–D not built |
| Trust forge rank as real recipes | **Done** — Session 2 PASS; use **Ctrl+Alt+R** to refresh |

---

## Next session — Session 2: Real forge rank

**Precondition:** Campaign map loaded (`TBG READY`). Game can stay open.

**Do not close the game** until you have checked F7 — or re-run on Continue save later.

### Step 1 — Run the inbox sequence

From repo root (PowerShell) with **campaign map loaded** (`TBG READY`):

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\scripts\run-session2-real-forge.ps1
```

Commands are sent via file inbox (alt-tab OK). Allowlist lives in [`scripts/dev-command-names.ps1`](scripts/dev-command-names.ps1) — must stay synced with `DevCommandRegistry.cs`.

### Step 2 — Verify in-game

On campaign map:

1. Press **F7** — top forge line should show **`source=real`** (not `stub`)
2. Press **Ctrl+Alt+R** — re-rank; F7 should update
3. Optional: change doctrine via inbox and rank again — top candidate should change

### Step 3 — Verify JSON

```powershell
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_ForgeRecommendations.json"
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_RecipeProbe.json"
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_SmithingAudit.json"
```

**PASS:**

- `RecipeProbe.json` — template count > 0
- `ForgeRecommendations.json` — top entry `source=real` (or mapping flag, not stub fallback)
- Doctrine change → different top candidate
- `SmithingAudit.json` — heroes listed, audit status not Error

**FAIL:** `fallbackUsed=true` or F7 still shows Long Warblade stub — stop and debug `ForgeRealCandidateMapper.cs`; do not start stamina automation.

### Step 4 — Manual smithy check (5 min)

1. **Ctrl+Alt+S** if Crafting skill too low
2. Enter a town **smithy** (you have ore or buy per F12 plan)
3. Confirm crafting UI opens — baseline game check before any automation work

---

## After Session 2 — Session 3: Play on Continue save

Close Bannerlord completely, then:

```powershell
.\LaunchForgeContinue.cmd
```

**PASS:** Map loads without 5-minute hang; Launch.log may show `clicked Module Mismatch Yes`.

**Play loop on Continue save:**

1. **F12** — trade route for current location
2. Ride → trade manually
3. **Ctrl+Alt+R** — forge intel refresh
4. Smithy → craft manually
5. Repeat

Disposable `Forge.cmd` remains for cert/bootstrap only.

---

## Remaining 006J items (lower priority)

| Step | Action | When |
|------|--------|------|
| Path B culture Back | Close game → `Forge.cmd` → press Back on culture screen | After Session 2–3 |
| Collect cert logs | `.\CollectCertLogs.cmd` | After any cert session |

Path B **PASS:** Back does not replay full intro cutscene.

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` |
| Version | `v0.0.11` |
| Remote | ahead of `origin/main` — push when requested |
| Docs | [functionality-status.md](docs/functionality-status.md), [in-game-surfaces.md](docs/in-game-surfaces.md) |
| Handoff | [post-005e-market-action-plan-handoff.md](docs/checkpoints/post-005e-market-action-plan-handoff.md) |

---

## Rollback

```powershell
git checkout 006i-4-path-c-pass
```
