# Handoff — Stage C USER PASS (2026-06-20)

Copy-paste to next AI agent. **Local repo is truth** until pushed; GitHub remote is stale.

---

## Repo state

```text
Path:   C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
Branch: main
HEAD:   ec40b28 (Stage C closeout complete — not pushed)
Clean:  yes after closeout commits
Remote: 40+ commits ahead of origin/main — NOT pushed
PRs:    none
```

---

## Mission state

| Item | Status |
|------|--------|
| **Track 2A map rank** | **USER PASS** 2026-06-20 @ 16:34 |
| **Stage B smithing advisory** | Code shipped — **Tier 1, cert optional** |
| **Stage C auto-refine** | **USER PASS** 2026-06-20 @ 17:52:13 — charcoal 0→1, Continue save |
| **Track 2B FORGE MATERIALS** | Code shipped — Tier 1 |
| **006J Path B** | USER pending (launcher only) |
| **Track 8 caravan/army** | Unblocked at doctrine level — user must direct |

---

## Stage C cert evidence

| Field | Value |
|-------|-------|
| Save | Continue (Danustica area) |
| Command | `RunSmithingSafeActionNow` via `forge.ps1` / cert helper |
| charcoalBefore / After | 0 → 1 |
| hardwoodBefore / After | 5 → 3 |
| refineCount | 1 |
| commit | `951f480` |
| Phase1 timestamp | 2026-06-20 17:52:13 |

Phase1 canonical line:

```text
[TBG FORGE] action=RefineCharcoal actor= refineCount=1 reserveBefore charcoal=0 hardwood=5 reserveAfter charcoal=1 hardwood=3
RunSmithingSafeActionNow succeeded
```

**Known gap:** blank `actor=` on success run — fixed in closeout sprint (`ResolveActorLabel` hardening).

**Stale JSON:** later blocked run (hardwood=0) overwrote `SmithingSafeAction.json`; cert helper now detects PASS from Phase1.

---

## Certification doctrine

See [certification-doctrine.md](../certification-doctrine.md).

| Tier | Live cert? |
|------|------------|
| 0 | No — build/static only (docs, formatting) |
| 1 | One smoke when convenient (read-only reports) |
| 2 | Required (mutation, launcher, reflection) |
| 3 | Disposable-first (headless refine) — **Stage C PASS recorded** |

**Do not** require full cert ceremony for Stage B, market formatting, or JSON shape changes.

**Re-cert Stage C only** if mutation code regresses.

---

## Key files

| Path | Role |
|------|------|
| `Forge/SmithingRefineApi.cs` | DoRefinement + GetRefiningFormulas |
| `Forge/SmithingSafeActionService.cs` | One refine per invocation; actor label hardening |
| `Forge/SmithingAuditService.cs` | ProbeSmithingRefineApi |
| `Market/MarketIntelligenceService.cs` | Track 2B FORGE MATERIALS |
| `docs/certification-doctrine.md` | Tier model |
| `scripts/run-stage-c-charcoal-cert.ps1` | Stage C cert + Phase1 fallback |
| `scripts/collect-cert-logs.ps1` | Cert bundle |

---

## Scope lock

No Track 8 implementation unless user asks. No auto-buy/sell, no Gauntlet clicks, no push unless user asks.

---

## Rollback

```powershell
git checkout 951f480   # Stage C cert flow hardened (pre closeout docs)
git checkout d914f37   # Stage C API + Track 2B
git checkout 5b15981   # Stage B only
```
