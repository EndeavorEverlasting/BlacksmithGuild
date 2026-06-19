# Next Steps

005E economics is next but **gated on 006I live cert PASS**. Do not start 005E until Paths A/B/C pass after 006I-3 re-cert.

---

## Sprint status

| Sprint | Status |
|--------|--------|
| 006H | LIVE CERT PASS. Do not regress narrative/bootstrap. |
| 006I hotfix | Partial PASS. Disarm fix and count=1 OnActivate skip confirmed. |
| 006I-2 | SHIPPED. Launcher handoff cert pending. |
| 006I-3 | SHIPPED. Re-cert PENDING. |
| 006I-4 | SHIPPED. Quit re-arm fix + diagnostics — Path C re-cert PENDING. |
| 005E economics | NEXT. Gated on 006I cert PASS. |

**2026-06-19 cert: PARTIAL** — Path A map OK (screenshot); Path B culture Back FAIL; Path C quit FAIL.

---

## Active stabilization gate

006I-3 is shipped, but live re-cert is still pending.

Current blocking glitch:

- Quit-to-main-menu can replay the campaign intro and trap the user, requiring Task Manager.
- This blocks clean Path C certification.
- Do not start 005E until this is certified clean.

Plans:

- [006I-4 Quit-to-Main-Menu Intro Replay Loop](docs/plans/006i-4-quit-to-menu-intro-loop.plan.md)
- [005E Smithing Posse Stamina & Output Automation](docs/plans/005e-smithing-posse-stamina-output.plan.md)

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` |
| HEAD | `3cdbdd3` |
| Version | `v0.0.11` |
| Remote sync | 7 commits ahead of `origin/main` — push when user requests |
| Open sprint | [docs/sprint-006i-live-results.md](docs/sprint-006i-live-results.md) |
| Handoff | [docs/checkpoints/post-006i-3-handoff.md](docs/checkpoints/post-006i-3-handoff.md) |
| Plan | [docs/plans/006i-3-narrow-skip-gate.plan.md](docs/plans/006i-3-narrow-skip-gate.plan.md) |
| Next feature | **005E** — gated on 006I cert |
| Open PRs | None |

---

## Next actions

**006I-3 — Re-cert (user):**

```powershell
Get-Process Bannerlord, TaleWorlds.MountAndBlade.Launcher -ErrorAction SilentlyContinue

cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\Forge.cmd
```

Manual checks after Path A:

```text
Path B: Culture stage → Back or Escape → no full cutscene replay
Path C: Pause → Quit → clean exit (no Task Manager)
```

Collect log tails — see [docs/checkpoints/post-006i-3-handoff.md](docs/checkpoints/post-006i-3-handoff.md).

**006I-4 — Re-cert Path C (user):** After `.\Forge.cmd` reaches map, Pause → Quit. Confirm no intro replay and no Task Manager. See [docs/plans/006i-4-quit-to-menu-intro-loop.plan.md](docs/plans/006i-4-quit-to-menu-intro-loop.plan.md).

**005E — Blocked until 006I cert PASS.**

---

## Stern verdict

**006H** = LIVE CERT PASS. **006I** = PARTIAL (2026-06-19). **006I-3** shipped at `3cdbdd3` — re-run `.\Forge.cmd` before declaring PASS or starting 005E.
