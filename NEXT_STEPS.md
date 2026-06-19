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
| **006E** | Full launch funnel (Forge → map) | **PARTIAL PASS** — launch + culture; narrative blocked Family |
| **006F** | Narrative menu sprint-through | **Shipped** — live cert pending |
| **005E** | Orders, inventory, doctrine tuning | **After 006F PASS** |

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` |
| Version | `v0.0.11` |
| Current sprint plan | [docs/sprint-006f-live-results.md](docs/sprint-006f-live-results.md) |
| Open PRs | None |

---

## Next actions (user — 006F live cert)

**Path A — Bootstrap (zero-click through map):**

```text
Close Bannerlord → Forge.cmd
→ auto PLAY → Safe Mode / CAUTION handled
→ SandBoxNewGame → culture → narrative menus → map → TBG READY
```

Check logs — see [sprint-006f-live-results.md](docs/sprint-006f-live-results.md).

---

## Stern verdict

**ForgeContinue.cmd** = daily dev loop. **Forge.cmd** = bootstrap cert. Layer A (PowerShell UI automation) handles launcher; Layer B (in-game mod) handles main menu. Tutorial skip remains future work.
