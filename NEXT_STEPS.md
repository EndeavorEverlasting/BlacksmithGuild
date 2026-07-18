# Next Steps

**Daily dev:** `Forge.cmd` — [forge-zero-click-contract.md](docs/forge-zero-click-contract.md)  
**Where we are:** [functionality-status.md](docs/functionality-status.md)  
**Cert doctrine:** [certification-doctrine.md](docs/certification-doctrine.md)  
**Handoff:** [post-stage-b-smithing-advisory-handoff.md](docs/checkpoints/post-stage-b-smithing-advisory-handoff.md)  
**Commands:** [player-command-guide.md](docs/player-command-guide.md)  
**Narrative schema:** [identity-disposition-schema.md](docs/identity-disposition-schema.md)  
**Play now (skip certs):** [play-now-cert-triage.md](docs/checkpoints/play-now-cert-triage.md)

---

## Play now (recommended)

```powershell
.\ForgeStop.cmd
.\ForgeContinue.cmd
```

Map ready → **Ctrl+Alt+M** / **Ctrl+Alt+R** / **Ctrl+Alt+G**. Skip cert CMD files unless you want a new certified baseline save.

---

## Certification doctrine (summary)

Live certs are **not** required for docs, formatting, or read-only reports. See [certification-doctrine.md](docs/certification-doctrine.md).

| Tier | When |
|------|------|
| 0 | Docs/static — build only |
| 1 | Read-only advisory — one smoke when convenient |
| 2 | Mutation / launcher / reflection |
| 3 | New mutation commands — **disposable save first** |

**Stage B:** Tier 1 — skip ceremony unless needed.  
**Stage C:** Tier 3 — **USER PASS recorded 2026-06-20** (Continue save); no re-cert unless mutation code regresses.

---

## Sprint status

| Sprint | Status |
|--------|--------|
| **Track 2A map rank** | **USER PASS** 2026-06-20 @ 16:34 |
| **Stage B smithing advisory** | Code shipped — Tier 1, cert optional |
| **Stage C auto-refine** | **USER PASS** 2026-06-20 @ 17:52:13 — charcoal 0→1, one refine, Continue save |
| **Track 2B FORGE MATERIALS** | Code shipped — Tier 1 |
| **Stage D rest plan** | Read-only — inbox `RunSmithingRestPlanNow` |
| **Evidence export** | `ExportTbgEvidence.cmd` → `docs/evidence/latest/` |
| **Track 8 caravan/army** | Blocked until user directs |
| **Posse stamina automation** | Stage D — see 005e plan |
| **005E-1 Horse market intel** | Code shipped — Tier 1 read-only (`AnalyzeHorseMarket`) |

---

## Stage C cert — complete

**USER PASS** recorded 2026-06-20 @ 17:52:13 on Continue save (Danustica area).

| Field | Value |
|-------|-------|
| charcoalBefore / After | 0 → 1 |
| hardwoodBefore / After | 5 → 3 |
| refineCount | 1 |
| commit | `951f480` |

Phase1 canonical line:

```text
[TBG FORGE] action=RefineCharcoal actor= refineCount=1 reserveBefore charcoal=0 hardwood=5 reserveAfter charcoal=1 hardwood=3
```

**Note:** `SmithingSafeAction.json` on disk may lag Phase1 if a later blocked run overwrites it. Cert helper now falls back to Phase1.

Optional: rerun `RunStageCCharcoalCert.cmd` after actor fix for clean JSON with non-empty `actor`.

---

## Next engineering (optional)

## In-game mechanics (rusty-player reminder)

1. **Town → Trade** — buy hardwood if party has none
2. **Smithy → Refining tab** — hardwood → charcoal (manual path; Stage C automates headless)
3. **Smithy bottom-left** — switch active crafter (companions have separate stamina)
4. **Wait in town** — recovers smithing stamina between refines

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` (HEAD `f90207f`) |
| Remote | in sync with `origin/main` |
| Open PRs | #20 (governor activity handoff contract — MERGEABLE, needs compile test) |
| Recent merges | #99 launcher lifecycle, #97 P21 disposition, #96 visible trade proof, #95 window lifecycle skills |
