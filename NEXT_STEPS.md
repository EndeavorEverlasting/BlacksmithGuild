# Next Steps

Build the car, not the fuzzy dice. SandBox bootstrap must skip the intro before economics polish.

---

## Sprint sequencing

| Order | Sprint | Status |
|-------|--------|--------|
| 003C | QuickStart + dev save auto-load | **LIVE CERT PASS** (Continue) |
| 005D | Real candidate mapping | **Hotfix shipped** |
| 006A | Auto Protagonist Build | **Shipped** — superseded by 006B |
| 006B | Build profiles + mode selection | **Shipped** — live cert pending |
| **006C** | SandBox intro skip + visible bootstrap | **Shipped** — live cert pending |
| **005E** | Orders, inventory, doctrine tuning | **After 006C PASS** |

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` (006C pending push) |
| Version | `v0.0.8` |
| Working tree | Commit after build |
| Remote | Push after commit |
| Open PRs | None |

---

## Next actions (user — 006C live cert)

**Path A — New Campaign (primary):**

```text
Close Bannerlord → Forge.cmd → New Campaign → SandBox
→ intro skipped, TBG QUICKSTART notices, auto character creation, TBG READY
```

**Path B — Continue regression:**

```text
Forge.cmd → Continue → TBG DEVSAVE / TBG READY
```

Then run 006B profile cert if not done:

```text
.\forge.ps1 -Command ShowAutoCharacterBuildProfiles -Wait
.\forge.ps1 -Command ApplyAutoCharacterBuild -Wait
→ F7 + JSON profileId
```

Docs: [sprint-006c-live-results.md](docs/sprint-006c-live-results.md)

---

## Stern verdict

**Continue** = daily dev loop. **New Campaign** = cert/bootstrap only (no dev-save hijack). Default profile **ForgeQuartermasterWarlord** auto-applies on fresh SandBox bootstrap only.
