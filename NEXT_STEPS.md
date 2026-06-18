# Next Steps

Math before hammer. Real recipes before UI. One live cert session closes 003C + 005D.

---

## Sprint sequencing

| Order | Sprint | Status |
|-------|--------|--------|
| 003C | QuickStart + dev save auto-load + Forge launcher | **Shipped** (`cf257a9`) — live cert pending |
| 005D | Real candidate mapping + economics | **Shipped** (`36f309b`) — live cert pending |
| **005E** | Orders, inventory, doctrine tuning on real set | **Next** |

Prior sprints 004A–005C: **Shipped** (004B live cert PASS 2026-06-18).

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` @ `cf257a9` |
| Version | `v0.0.7` |
| Working tree | **Clean** |
| Remote | `origin/main` up to date |
| Open PRs | None |

---

## Next actions (user — one session closes both live certs)

```text
Close Bannerlord → Forge.cmd → Continue (or Play → SandBox if no dev save)
→ TBG READY
.\forge.ps1 -Command SetForgeCandidateSourceReal -Wait
.\forge.ps1 -Command RankForgeCandidates -Wait
→ F7: source=real, fallbackUsed=false, real.template.* IDs
.\forge.ps1 -Command SetForgeCandidateSourceStub -Wait
.\forge.ps1 -Command RankForgeCandidates -Wait
→ F7: Long Warblade 11250
```

Docs: [sprint-003c-live-results.md](docs/sprint-003c-live-results.md) · [sprint-005d-live-results.md](docs/sprint-005d-live-results.md)

---

## Next actions (dev — after live cert)

**Sprint 005E:** crafting orders + hero inventory in economics; doctrine tuning on real candidates.

**Backlog:** F10 safety guards, strict 003B F10 multi-day, player forge UI (006).

---

## Stern verdict

Stub oracle (Long Warblade 11250) remains regression baseline. Real source must cert with `fallbackUsed=false` before removing stub fallback.
