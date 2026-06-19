# Next Steps

Zero-click forge loop first. Economics (005E) after 006E live cert.

---

## Sprint sequencing

| Order | Sprint | Status |
|-------|--------|--------|
| 003C | QuickStart + dev save auto-load | **LIVE CERT PASS** (Continue) |
| 005D | Real candidate mapping | **Hotfix shipped** |
| 006A/B | Auto protagonist build + profiles | **Shipped** — live cert pending |
| 006C | SandBox intro skip + visible bootstrap | **Shipped** |
| 006D | v1.4.6 culture/narrative hotfix | **Shipped** |
| **006E** | Full launch funnel (Forge → map) | **Shipped** — **live cert pending** |
| **005E** | Orders, inventory, doctrine tuning | **After 006E PASS** |

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` |
| Version | `v0.0.10` |
| Current sprint plan | [docs/plans/006e-main-menu-auto-launch.plan.md](docs/plans/006e-main-menu-auto-launch.plan.md) |
| Open PRs | None |

---

## Next actions (user — 006E live cert)

**Path A — Bootstrap (zero-click):**

```text
Close Bannerlord → Forge.cmd
→ auto PLAY → auto CAUTION Confirm → auto Safe Mode No (if shown)
→ auto New Campaign → SandBox → intro skip → culture → TBG READY
```

**Path B — Daily Continue (zero-click):**

```text
Close Bannerlord → ForgeContinue.cmd
→ auto CONTINUE → auto CAUTION Confirm → auto Safe Mode No (if shown)
→ auto Continue Campaign → TBG DEVSAVE / TBG READY
```

Check logs — see [sprint-006e-live-results.md](docs/sprint-006e-live-results.md).

---

## Stern verdict

**ForgeContinue.cmd** = daily dev loop. **Forge.cmd** = bootstrap cert. Layer A (PowerShell UI automation) handles launcher; Layer B (in-game mod) handles main menu. Tutorial skip remains future work.
