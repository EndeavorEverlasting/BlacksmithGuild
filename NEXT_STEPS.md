# Next Steps

Economics (005E) is next. Zero-click bootstrap funnel is live-certified.

---

## Sprint sequencing

| Order | Sprint | Status |
|-------|--------|--------|
| 003C | QuickStart + dev save auto-load | **LIVE CERT PASS** (Continue) |
| 005D | Real candidate mapping | **Hotfix shipped** |
| 006A/B | Auto protagonist build + profiles | **Shipped** — live cert pending |
| 006C | SandBox intro skip + visible bootstrap | **Shipped** |
| 006D | v1.4.6 culture/narrative hotfix | **Shipped** |
| **006E** | Full launch funnel (Forge → map) | **LIVE CERT PASS** (Path A bootstrap) |
| **006F** | Narrative menu sprint-through | **FAIL** — superseded by 006G/006H |
| **006G** | Family / narrative API fix | **FAIL** — superseded by 006H |
| **006H** | Family stall recovery | **LIVE CERT PASS** |
| **006I** | Intro skip lifecycle (culture back / quit) | **Shipped** — live cert pending |
| **005E** | Orders, inventory, doctrine tuning | **Next** |

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` |
| Version | `v0.0.11` |
| Last closed sprint | [docs/sprint-006h-live-results.md](docs/sprint-006h-live-results.md) |
| Open sprint | [docs/sprint-006i-live-results.md](docs/sprint-006i-live-results.md) — live cert pending |
| Post-006H handoff | [docs/checkpoints/post-006h-handoff.md](docs/checkpoints/post-006h-handoff.md) |
| Next feature | **005E** — scope from existing forge/economics code before coding |
| Open PRs | None |

---

## Next actions

**006I — Live cert (user):**

```text
Path A: Close Bannerlord → Forge.cmd → TBG READY (006H regression)
Path B: Forge.cmd → culture stage → Back → no cutscene replay
Path C: Pause → Quit (during bootstrap and after TBG READY)
```

See [docs/sprint-006i-live-results.md](docs/sprint-006i-live-results.md).

**005E — Economics sprint (plan TBD):**

- Scope orders, inventory, doctrine tuning from [`src/BlacksmithGuild/`](src/BlacksmithGuild/)
- No 005E plan file exists yet; create `docs/plans/005e-*.plan.md` before implementation

**Optional regression (user):**

```text
Close Bannerlord → ForgeContinue.cmd → TBG DEVSAVE / TBG READY
```

---

## Stern verdict

**ForgeContinue.cmd** = daily dev loop. **Forge.cmd** = bootstrap cert (**PASS** as of 2026-06-19). Tutorial skip remains future work.
