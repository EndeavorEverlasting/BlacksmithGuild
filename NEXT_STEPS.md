# Next Steps

005E economics is next but **gated on 006I live cert**. Do not start 005E until Paths A/B/C pass.

---

## Sprint status

| Sprint | Status |
|--------|--------|
| 006H | LIVE CERT PASS. Do not regress narrative/bootstrap. |
| 006I hotfix | Partial PASS. Disarm fix and count=1 OnActivate skip confirmed. |
| 006I-2 | SHIPPED. Live cert PENDING. |
| 005E economics | NEXT. No plan file yet. Gated on 006I cert. |

---

## Sprint sequencing (history)

| Order | Sprint | Status |
|-------|--------|--------|
| 003C | QuickStart + dev save auto-load | **LIVE CERT PASS** (Continue) |
| 005D | Real candidate mapping | **Hotfix shipped** |
| 006A/B | Auto protagonist build + profiles | **Shipped** — live cert pending |
| 006C | SandBox intro skip + visible bootstrap | **Shipped** |
| 006D | v1.4.6 culture/narrative hotfix | **Shipped** |
| **006E** | Full launch funnel (Forge → map) | **LIVE CERT PASS** (Path A bootstrap, 006H era) |
| **006F** | Narrative menu sprint-through | **FAIL** — superseded by 006G/006H |
| **006G** | Family / narrative API fix | **FAIL** — superseded by 006H |
| **006H** | Family stall recovery | **LIVE CERT PASS** |
| **006I / 006I-2** | Intro skip lifecycle + creation gate | **006I-2 SHIPPED** — live cert pending |
| **005E** | Orders, inventory, doctrine tuning | **Blocked** until 006I cert |

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` |
| HEAD | `3c2c1d8` (implementation `6fb5825`) |
| Version | `v0.0.11` |
| Remote sync | 5 commits ahead of `origin/main` — push when user requests |
| Last closed sprint | [docs/sprint-006h-live-results.md](docs/sprint-006h-live-results.md) |
| Open sprint | [docs/sprint-006i-live-results.md](docs/sprint-006i-live-results.md) |
| Handoff checkpoint | [docs/checkpoints/post-006i-2-handoff.md](docs/checkpoints/post-006i-2-handoff.md) |
| Prior checkpoint | [docs/checkpoints/post-006h-handoff.md](docs/checkpoints/post-006h-handoff.md) |
| Next feature | **005E** — gated on 006I cert |
| Open PRs | None |

---

## Next actions

**006I-2 — Live cert (user):**

Precondition: Close Bannerlord completely. No `Bannerlord.exe` or Launcher processes.

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
Forge.cmd
```

Paths:

```text
Forge exit: Launch.log handoff: reason, no timeout
Path A:     Full bootstrap → count=1 only → TBG READY
Path B:     Culture stage → Back → no campaign_intro replay
Path C:     Pause → Quit (bootstrap and after TBG READY)
```

Analyze logs — see [docs/sprint-006i-live-results.md](docs/sprint-006i-live-results.md) and [docs/checkpoints/post-006i-2-handoff.md](docs/checkpoints/post-006i-2-handoff.md).

**005E — Economics sprint (blocked):**

- Do not start until 006I live cert PASS
- Scope orders, inventory, doctrine tuning from [`src/BlacksmithGuild/`](src/BlacksmithGuild/)
- Create `docs/plans/005e-*.plan.md` before implementation

**Optional regression (user):**

```text
Close Bannerlord → ForgeContinue.cmd → TBG DEVSAVE / TBG READY
```

---

## Stern verdict

**006H** bootstrap funnel = LIVE CERT PASS (2026-06-19). **006I-2** re-cert required before declaring current Forge.cmd bootstrap PASS again. **ForgeContinue.cmd** = daily dev loop (optional regression). Tutorial skip remains future work.
