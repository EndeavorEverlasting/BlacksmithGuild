# Next Steps

005E economics is next but **gated on 006I live cert PASS**. Do not start 005E until Paths A/B/C pass after 006I-3 re-cert.

---

## Sprint status

| Sprint | Status |
|--------|--------|
| 006H | LIVE CERT PASS. Do not regress narrative/bootstrap. |
| 006I hotfix | Partial PASS. Disarm fix and count=1 OnActivate skip confirmed. |
| 006I-2 | SHIPPED. Launcher handoff cert pending. |
| 006I-3 | SHIPPED. Re-cert PENDING (narrow gate + quit guard). |
| 005E economics | NEXT. Gated on 006I cert PASS. |

**2026-06-19 cert: PARTIAL** — Path A map OK (screenshot); Path B culture Back FAIL; Path C quit FAIL.

---

## Sprint sequencing (history)

| Order | Sprint | Status |
|-------|--------|--------|
| 003C | QuickStart + dev save auto-load | **LIVE CERT PASS** (Continue) |
| 005D | Real candidate mapping | **Hotfix shipped** |
| 006A/B | Auto protagonist build + profiles | **Shipped** — live cert pending |
| 006C | SandBox intro skip + visible bootstrap | **Shipped** |
| 006D | v1.4.6 culture/narrative hotfix | **Shipped** |
| **006E** | Full launch funnel (Forge → map) | **LIVE CERT PASS** (006H era) |
| **006F–G** | Narrative fixes | **FAIL** — superseded by 006H |
| **006H** | Family stall recovery | **LIVE CERT PASS** |
| **006I / 006I-2 / 006I-3** | Intro skip lifecycle | **006I-3 SHIPPED** — re-cert pending |
| **005E** | Orders, inventory, doctrine tuning | **Blocked** |

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` |
| Version | `v0.0.11` |
| Open sprint | [docs/sprint-006i-live-results.md](docs/sprint-006i-live-results.md) |
| Plan | [docs/plans/006i-3-narrow-skip-gate.plan.md](docs/plans/006i-3-narrow-skip-gate.plan.md) |
| Handoff | [docs/checkpoints/post-006i-2-handoff.md](docs/checkpoints/post-006i-2-handoff.md) |
| Next feature | **005E** — gated on 006I cert |
| Open PRs | None |

---

## Next actions

**006I-3 — Re-cert (user):**

Close Bannerlord completely (install was blocked while game running).

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\Forge.cmd
```

Paths:

```text
Forge exit: Launch.log handoff: reason, no timeout
Path A:     Full bootstrap → count=1 only → TBG READY (no Options count=2)
Path B:     Culture stage → Back or Escape → no full cutscene replay
Path C:     Pause → Quit → clean exit (no Task Manager)
```

Paste log tails — see [docs/sprint-006i-live-results.md](docs/sprint-006i-live-results.md).

**005E — Blocked until 006I cert PASS.**

---

## Stern verdict

**006H** = LIVE CERT PASS. **006I** = PARTIAL (2026-06-19). **006I-3** fix shipped — athlete must re-run `.\Forge.cmd` before declaring PASS or starting 005E.
