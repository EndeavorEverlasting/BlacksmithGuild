# Next Steps

Build the car, not the fuzzy dice. v1.4.6 culture/narrative automation before economics polish.

---

## Sprint sequencing

| Order | Sprint | Status |
|-------|--------|--------|
| 003C | QuickStart + dev save auto-load | **LIVE CERT PASS** (Continue) |
| 005D | Real candidate mapping | **Hotfix shipped** |
| 006A/B | Auto protagonist build + profiles | **Shipped** — live cert pending |
| 006C | SandBox intro skip + visible bootstrap | **FAIL on v1.4.6** — intro OK, creation broken |
| **006D** | v1.4.6 culture/narrative hotfix | **Shipped** — live cert pending |
| **005E** | Orders, inventory, doctrine tuning | **After 006D PASS** |

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` (up to date with `origin/main`; 006D `5b920f5`) |
| Version | `v0.0.9` |
| Working tree | **Clean** |
| Remote | `origin/main` up to date |
| Open PRs | None |

---

## Next actions (user — 006D live cert)

**Path A — New Campaign (primary):**

```text
Close Bannerlord → Forge.cmd → New Campaign → SandBox
→ intro skipped, culture auto-selected, no manual creation clicks, TBG READY
```

**Path B — Continue regression:**

```text
Forge.cmd → Continue → TBG DEVSAVE / TBG READY
```

Check Phase1.log for:

```text
using vanilla character creation launch; Poll will auto-advance stages.
culture=found narrative=OnNarrativeMenuOptionSelected
```

Docs: [sprint-006d-live-results.md](docs/sprint-006d-live-results.md)

---

## Stern verdict

**Continue** = daily dev loop. **New Campaign** = cert/bootstrap only. 006C intro skip stands; 006D fixes v1.4.6 character creation. Tutorial skip and main-menu automation remain future work.
