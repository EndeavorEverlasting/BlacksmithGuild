# Next Steps

**Daily dev:** `Forge.cmd` — [forge-zero-click-contract.md](docs/forge-zero-click-contract.md)  
**Where we are:** [functionality-status.md](docs/functionality-status.md)  
**Cert doctrine:** [certification-doctrine.md](docs/certification-doctrine.md)  
**Handoff:** [post-stage-b-smithing-advisory-handoff.md](docs/checkpoints/post-stage-b-smithing-advisory-handoff.md)

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
**Stage C:** Tier 3 — **next USER cert**.

---

## Sprint status

| Sprint | Status |
|--------|--------|
| **Track 2A map rank** | **USER PASS** 2026-06-20 @ 16:34 |
| **Stage B smithing advisory** | Code shipped — Tier 1, cert optional |
| **Stage C auto-refine** | API mapped; **one refine per command** — **Tier 3 USER cert next** |
| **Track 2B FORGE MATERIALS** | Code shipped — Tier 1 |
| **006J Path B** | USER pending (launcher path only) |

---

## Immediate: Stage C disposable cert

**Save:** any disposable / blacksmithing save — no precious-save flow.

**Preconditions:** charcoal low, hardwood ≥1, on campaign map. **No smithy UI needed.**

```powershell
.\RunStageCCharcoalCert.cmd
```

If blocked with `hardwood shortage`: enter town → Trade → buy 1–5 Hardwood → return to map → rerun.

**PASS:** `executed: true`, `charcoalAfter > charcoalBefore`, `refineCount: 1`.

---

## In-game mechanics (rusty-player reminder)

1. **Town → Trade** — buy hardwood if party has none
2. **Smithy → Refining tab** — hardwood → charcoal (manual path; Stage C automates headless)
3. **Smithy bottom-left** — switch active crafter (companions have separate stamina)
4. **Wait in town** — recovers smithing stamina between refines

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` only |
| Remote | ahead of `origin/main` — push when requested |
| GitHub | stale until push — local is truth |
