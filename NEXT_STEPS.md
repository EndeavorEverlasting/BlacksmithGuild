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
| **005E market intel** | **USER PASS** 2026-06-20 — F12 action plan |
| 005E real forge rank | **USER PASS** 2026-06-20 — `source=real`, Javelin top, templates=12 |
| 005E smithing Stage A | **USER PASS** 2026-06-20 — stamina API hints |
| 006J closeout | **PARTIAL** — 1B PASS; 1C play loop + 1D Path B Back pending |

---

## What works right now

| You can… | How |
|----------|-----|
| Bootstrap to map | `Forge.cmd` → `TBG READY` |
| **Continue cared-about save** | `LaunchForgeContinue.cmd` — zero-click Module Mismatch Yes |
| Get buy/sell route plan | **F12** — ACTION PLAN + BUY@NEAREST |
| Rank real forge recipes | **Ctrl+Alt+R** on map |
| Check mod status | **F7** |
| Fund disposable tests | **F11** (+100k) |

| You cannot yet… | Why |
|-----------------|-----|
| Auto buy/sell | Not built — manual town trade |
| Guild loop one-hotkey | Ctrl+Alt+G — 007A Track 3 not built |
| Auto craft / stamina rotation | Stages B–D not built |

---

## Session 3 — Play on Continue save (YOU, on current map)

You are on the cared-about Continue save (Tevea/Zestica area). Module Mismatch cert **PASS**.

1. **Ctrl+Alt+R** — switch from stub to `source=real`
2. **F12** — trade route near Tevea/Zestica
3. Enter town → buy top plan item manually
4. Smithy → craft top ranked item manually
5. **F7** — status snapshot

---

## Remaining 006J gates

| Step | Action |
|------|--------|
| **1D Path B** | Quit → `Forge.cmd` → culture screen **Back once** (intro must NOT replay) |
| **006J tag** | Approve full closeout tag after 1C + 1D |

Then: **007A Track 2** (F12 forge materials + market-forge bridge).

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` |
| Version | `v0.0.11` |
| Fix commit | `52c2114` (Module Mismatch verify-dismiss) |
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
