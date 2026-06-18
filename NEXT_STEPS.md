# Next Steps

Math before hammer. Reports before recommendations. Cert before real recipes.

---

## Sprint sequencing

| Order | Sprint | Status |
|-------|--------|--------|
| 004A | Report formatting | **Shipped** |
| 004B | Stub recommendations | **Shipped** — live cert pending |
| 005A | Source boundary + real scaffold | **Shipped** — live cert pending |
| 005B | Doctrine dev commands | **Shipped** — live cert pending |
| 003B | Treasury F10 retest | **Pending** |
| 005C+ | Real recipe enumeration | **Gated** |

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` |
| Version | `v0.0.7` |
| Published | sync with `origin/main` after push |

---

## Next actions (user — in game)

1. **Live cert 004B** — [docs/sprint-004-live-results.md](docs/sprint-004-live-results.md)
2. **Live cert 005A/005B** — [docs/sprint-005-live-results.md](docs/sprint-005-live-results.md)
3. **Live cert 003B** — F10 3–5 days + `TreasurySnapshotNow` — [docs/sprint-003-live-results.md](docs/sprint-003-live-results.md)

---

## Next actions (dev — after certs)

**Sprint 005C:** implement real recipe enumeration in `RealForgeCandidateSource` (Bannerlord crafting API probe).

---

## Stern verdict

**Do not start 005C until 004B + 003B live cert PASS.** Stub oracle remains regression baseline.
