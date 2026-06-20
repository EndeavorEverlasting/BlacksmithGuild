# Handoff — Stage C cert next (2026-06-20)

Copy-paste to next AI agent. **Local repo is truth** until pushed; GitHub remote is stale.

---

## Repo state

```text
Path:   C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
Branch: main
HEAD:   d914f37+ (one-refine cap commit pending push)
Clean:  yes after commit
Remote: 38+ commits ahead of origin/main — NOT pushed
PRs:    none
```

---

## Mission state

| Item | Status |
|------|--------|
| **Track 2A map rank** | **USER PASS** 2026-06-20 @ 16:34 |
| **Stage B smithing advisory** | Code shipped — **Tier 1, cert optional** |
| **Stage C auto-refine** | API mapped; **one refine per command** — **Tier 3 USER cert next** |
| **Track 2B FORGE MATERIALS** | Code shipped — Tier 1 |
| **006J Path B** | USER pending (launcher only) |

---

## Certification doctrine

See [certification-doctrine.md](../certification-doctrine.md).

| Tier | Live cert? |
|------|------------|
| 0 | No — build/static only (docs, formatting) |
| 1 | One smoke when convenient (read-only reports) |
| 2 | Required (mutation, launcher, reflection) |
| 3 | Disposable-first (headless refine) |

**Do not** require full cert ceremony for Stage B, market formatting, or JSON shape changes.

**Do** cert Stage C on disposable save — inventory mutation boundary.

---

## Stage C cert protocol

**Save:** any disposable / blacksmithing save. User does not preserve old saves.

**Preconditions:** charcoal low, hardwood ≥1, campaign map ready.

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\forge.ps1 -Command ProbeSmithingRefineApi -Wait
.\forge.ps1 -Command RunSmithingSafeActionNow -Wait
.\CollectCertLogs.cmd
```

**PASS:**

- `SmithingRefineProbe.json` → `doRefinementMapped: true`
- `SmithingSafeAction.json` → `executed: true`, `charcoalAfter > charcoalBefore`, `refineCount: 1`
- Phase1 → `[TBG FORGE] action=RefineCharcoal ... refineCount=1 reserveBefore ... reserveAfter ...`

**Agent response shape when user pastes logs:**

```text
Verdict: / Stage C: / Probe: / SafeAction: / Inventory mutation: / PASS/FAIL: / Smallest next fix: / Exact evidence lines:
```

---

## Key files

| Path | Role |
|------|------|
| `Forge/SmithingRefineApi.cs` | DoRefinement + GetRefiningFormulas |
| `Forge/SmithingSafeActionService.cs` | One refine per invocation (`MaxRefinePerInvocation = 1`) |
| `Forge/SmithingAuditService.cs` | ProbeSmithingRefineApi |
| `Market/MarketIntelligenceService.cs` | Track 2B FORGE MATERIALS |
| `docs/certification-doctrine.md` | Tier model |
| `scripts/collect-cert-logs.ps1` | Cert bundle |

---

## Scope lock

No Track 8, no auto-buy/sell, no Gauntlet clicks, no push unless user asks.

---

## Rollback

```powershell
git checkout d914f37   # Stage C API + Track 2B
git checkout 5b15981   # Stage B only
```
