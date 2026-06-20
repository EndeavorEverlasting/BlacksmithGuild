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
| Rank real forge recipes | **Ctrl+Alt+R** on map (source=real after Session 2) |
| Probe smithing API | `ProbeSmithingAudit` — Stage A PASS |

| You cannot yet… | Why |
|-----------------|-----|
| Auto buy/sell | Not built — manual town trade |
| Auto craft / stamina rotation | Stages B–D not built |

---

## Next session — Session 3: Play on Continue save

**Session 2 PASS (2026-06-20):** `source=real`, top=Javelin, templates=12, `fallbackUsed=false`, SmithingAudit Ok.

Close Bannerlord completely, then:

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\LaunchForgeContinue.cmd
```

**PASS:** Map loads without hang; Launch.log may show `clicked Module Mismatch Yes`.

**Play loop:**

1. **F12** — trade route
2. Enter town → trade manually
3. **Ctrl+Alt+R** — refresh forge rank
4. Smithy → craft manually
5. Repeat

Optional in-game check on disposable save: **F7** should show `source=real` and top candidate Javelin (RareMetalConservation doctrine).

Disposable `Forge.cmd` remains for cert/bootstrap only.

---

## Session 2 reference (complete)

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
