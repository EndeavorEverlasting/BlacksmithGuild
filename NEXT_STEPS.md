# Next Steps

Math before hammer. Real recipes before UI. One live cert session closes 005D after hotfix.

---

## Sprint sequencing

| Order | Sprint | Status |
|-------|--------|--------|
| 003C | QuickStart + dev save auto-load + Forge launcher | **LIVE CERT PASS** (Continue, 2026-06-18) |
| 005D | Real candidate mapping + economics | **Hotfix shipped** — live cert pending |
| **005E** | Orders, inventory, doctrine tuning on real set | **Next** (after 005D PASS) |

Prior sprints 004A–005C: **Shipped** (004B live cert PASS 2026-06-18).

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` (hotfix commit pending push) |
| Version | `v0.0.7` |
| Working tree | Source changes staged for commit |
| Remote | `origin/main` |
| Open PRs | None |
| Stale branches | None |

---

## Next actions (user — one session closes 005D live cert)

```text
Close Bannerlord → Forge.cmd → Continue → TBG READY
.\forge.ps1 -Command SetForgeCandidateSourceReal -Wait
.\forge.ps1 -Command RankForgeCandidates -Wait
→ F7: source=real, fallbackUsed=false, real.template.* IDs, economicsMode present
.\forge.ps1 -Command SetForgeCandidateSourceStub -Wait
.\forge.ps1 -Command RankForgeCandidates -Wait
→ F7: Long Warblade 11250
```

**No smithy required** — campaign map only, pause time (Space).

Docs: [sprint-003c-live-results.md](docs/sprint-003c-live-results.md) · [sprint-005d-live-results.md](docs/sprint-005d-live-results.md)

---

## Next actions (dev — after 005D live cert PASS)

**Sprint 005E:** crafting orders + hero inventory in economics; doctrine tuning on real candidates.

**Backlog:** F10 safety guards, strict 003B F10 multi-day, player forge UI (006).

---

## Stern verdict

Stub oracle (Long Warblade 11250) remains regression baseline. Real source must cert with `fallbackUsed=false` before removing stub fallback.
