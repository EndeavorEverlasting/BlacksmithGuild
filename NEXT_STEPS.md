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
| **005E market intel** | **USER PASS** 2026-06-20 — Ctrl+Alt+M action plan (F12 Steam collision fixed) |
| 005E real forge rank | **Session 2 disposable PASS** — `source=real`, Javelin top; Continue save still shows stub until Track 2A |
| 005E smithing Stage A | **USER PASS** 2026-06-20 — stamina API hints |
| 006J closeout | **PARTIAL** — 1B PASS; 1C play loop + 1D Path B Back pending |
| **007A hotkey remap** | **SHIPPED** — primary market intel **Ctrl+Alt+M**; pending user smoke |

---

## What works right now

| You can… | How |
|----------|-----|
| Bootstrap to map | `Forge.cmd` → `TBG READY` |
| **Continue cared-about save** | `LaunchForgeContinue.cmd` — zero-click Module Mismatch Yes |
| Get buy/sell route plan | **Ctrl+Alt+M** — ACTION PLAN + BUY@NEAREST |
| Rank forge recipes | **Ctrl+Alt+R** on map (default stub; real only after `SetForgeCandidateSourceReal` + JSON proof) |
| Check mod status | **F7** |
| Fund disposable tests | **F11** (+100k) |

| You cannot yet… | Why |
|-----------------|-----|
| Auto buy/sell | Not built — manual town trade |
| Guild loop one-hotkey | Ctrl+Alt+G — 007A Track 3 not built |
| Auto craft / stamina rotation | Stages B–D not built |
| Real forge rank on Continue (default) | Ctrl+Alt+R uses requested source; default Stub until Track 2A wires real path |

---

## Session 3 — Play on Continue save (YOU, on current map)

You are on the cared-about Continue save (Tevea/Zestica area). Module Mismatch cert **PASS**.

1. **Ctrl+Alt+M** — trade route near Tevea/Zestica (must work; F12 not required)
2. **Ctrl+Alt+R** — forge recommendations (expect `source=stub` until real source set)
3. Enter town → buy top plan item manually
4. Smithy → craft top ranked item manually
5. **F7** — status snapshot

Collect JSON proof:

```powershell
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_MarketIntel.json"
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_ForgeRecommendations.json"
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json" -Tail 120
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log" -Tail 220
```

---

## Remaining 006J gates

| Step | Action |
|------|--------|
| **1D Path B** | Quit → `Forge.cmd` → culture screen **Back once** (intro must NOT replay) |
| **006J tag** | Approve full closeout tag after 1C + 1D |

Then: **007A Track 2A/2B** (honest real forge on Continue + forge materials bridge in market intel).

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` |
| Version | `v0.0.11` |
| Fix commit | 007A hotkey remap on `main` (see `git log -1`) |
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
