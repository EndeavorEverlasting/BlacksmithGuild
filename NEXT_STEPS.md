# Next Steps

Build the car, not the fuzzy dice. Profile-driven protagonist shaping before economics polish.

---

## Sprint sequencing

| Order | Sprint | Status |
|-------|--------|--------|
| 003C | QuickStart + dev save auto-load | **LIVE CERT PASS** |
| 005D | Real candidate mapping | **Hotfix shipped** — live cert optional |
| 006A | Auto Protagonist Build | **Shipped** — superseded by 006B targets |
| **006B** | Build profiles + mode selection | **Shipped** — live cert pending |
| **005E** | Orders, inventory, doctrine tuning | **After 006B PASS** |

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` (up to date with `origin/main`; 006B `a4caa0c`) |
| Version | `v0.0.7` |
| Working tree | **Clean** |
| Remote | `origin/main` up to date |
| Open PRs | None |

---

## Next actions (user — 006B live cert)

```text
Close Bannerlord → Forge.cmd → Continue → TBG READY
.\forge.ps1 -Command ShowAutoCharacterBuildProfiles -Wait
.\forge.ps1 -Command ShowAutoCharacterBuildProfile -Wait
→ F7: selected/default/available BEFORE apply
.\forge.ps1 -Command SetAutoCharacterBuildSmithEconomist -Wait
.\forge.ps1 -Command ApplyAutoCharacterBuild -Wait
→ JSON profileId=SmithEconomist
.\forge.ps1 -Command SetAutoCharacterBuildForgeQuartermasterWarlord -Wait
.\forge.ps1 -Command ApplyAutoCharacterBuild -Wait
→ F7 + JSON: Int 8 / End 8 / Social 7 targets
```

Docs: [sprint-006b-live-results.md](docs/sprint-006b-live-results.md)

---

## Stern verdict

Default mode is **ForgeQuartermasterWarlord**. Auto-apply on new-game bootstrap only. Continue requires explicit `ApplyAutoCharacterBuild`.
