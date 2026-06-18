# Next Steps

Math before hammer. Real recipes before UI. Cert before polish.

---

## Sprint sequencing

| Order | Sprint | Status |
|-------|--------|--------|
| 004A | Report formatting | **Shipped** |
| 004B | Stub recommendations | **LIVE CERT PASS** (2026-06-18) |
| 005A | Source boundary + real scaffold | **Shipped** |
| 005B | Doctrine dev commands | **Shipped** |
| 005C | Recipe API recon (read-only) | **Shipped** |
| **005D** | **Real candidate mapping + economics** | **Shipped** — live cert after rebuild |
| 005E+ | Orders, inventory, doctrine tuning on real set | **Next** |

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` |
| Version | `v0.0.7` |
| Published | push to `origin/main` after 005D live cert |

---

## Next actions (user — in game)

1. **Live cert 005D** — close game, `Forge.cmd`, load dev save → [docs/sprint-005d-live-results.md](docs/sprint-005d-live-results.md)
2. **Optional 005A/005B inbox** — [docs/sprint-005-live-results.md](docs/sprint-005-live-results.md)
3. **Optional strict 003B** — F10 3–5 days + `TreasurySnapshotNow` — [docs/sprint-003-live-results.md](docs/sprint-003-live-results.md)

Minimal dev entry (once per build):

```text
Close game → Forge.cmd → Load dev save → TBG READY
.\forge.ps1 -Command SetForgeCandidateSourceReal -Wait
.\forge.ps1 -Command RankForgeCandidates -Wait
# F7 — real weapon names, source=real, fallbackUsed=false
```

---

## Next actions (dev — after 005D live cert)

**Sprint 005E:** crafting orders + hero inventory in economics; doctrine affects real candidates; tune rank quality.

**Backlog:** QuickStart automation fix, strict F10/003B, player-facing forge UI (006).

---

## Stern verdict

Stub oracle (Long Warblade 11250) remains the regression baseline. Real source must produce ranked output with `fallbackUsed=false` before removing stub fallback.
