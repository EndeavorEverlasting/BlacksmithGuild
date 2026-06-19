# Next Steps

005E economics is next but **gated on 006I live cert PASS**. Do not start 005E until Paths A/B/C + load paths pass.

---

## Sprint status

| Sprint | Status |
|--------|--------|
| 006H | LIVE CERT PASS. Do not regress narrative/bootstrap. |
| 006I hotfix | Partial PASS. Disarm fix and count=1 OnActivate skip confirmed. |
| 006I-2 | SHIPPED. Launcher handoff cert pending. |
| 006I-3 | SHIPPED. Path B culture Back pending re-cert. |
| 006I-4 | **Path C USER PASS** (2026-06-19). Tag `006i-4-path-c-pass` @ `57f6062`. |
| 006I-5 | SHIPPED — Module Mismatch UIA, Continue entrypoint, load stall watchdog. Re-cert PENDING. |
| 005E economics | NEXT. Gated on 006I cert PASS. |

**2026-06-19 cert: PARTIAL** — Path A PASS; Path C USER PASS; Path B + Continue load pending.

---

## Active stabilization gate

006I-5 shipped fixes for Continue load hang. User re-cert required before full PASS.

Current blockers:

- Continue load: Module Mismatch + GameLoadingState hang (fix shipped, re-test via `LaunchForgeContinue.cmd`)
- Path B culture Back: not re-certified after 006I-4
- Layer A launcher handoff: need `handoff:` in Launch.log

Plans:

- [006I-5 Continue / Module Mismatch / Load Watchdog](docs/plans/006i-5-continue-module-mismatch-load.plan.md)
- [006I-4 Quit-to-Main-Menu Intro Replay Loop](docs/plans/006i-4-quit-to-menu-intro-loop.plan.md) — Path C PASS
- [005E Smithing Posse Stamina & Output Automation](docs/plans/005e-smithing-posse-stamina-output.plan.md) — BLOCKED

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` |
| Rollback | `git checkout 006i-4-path-c-pass` |
| Version | `v0.0.11` |
| Remote sync | ahead of `origin/main` — push when user requests |
| Open sprint | [docs/sprint-006i-live-results.md](docs/sprint-006i-live-results.md) |
| Handoff | [docs/checkpoints/post-006i-4-handoff.md](docs/checkpoints/post-006i-4-handoff.md) |
| Next feature | **005E** — gated on 006I cert |
| Open PRs | None |

---

## Next actions (user)

**006I-5 — Re-cert load paths:**

```powershell
Get-Process Bannerlord, TaleWorlds.MountAndBlade.Launcher -ErrorAction SilentlyContinue

cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\LaunchForgeContinue.cmd
```

Expected: Module Mismatch Yes auto-clicked, map reached, no 5min hang.

**Path B — culture Back:** After map load, enter character creation culture stage → Back → no full cutscene replay.

**Path C — quit:** Pause → Quit → clean exit (already USER PASS; spot-check optional).

Collect log tails — see [docs/checkpoints/post-006i-4-handoff.md](docs/checkpoints/post-006i-4-handoff.md).

**005E — Blocked until 006I cert PASS.**

---

## Rollback

```powershell
git checkout 006i-4-path-c-pass
```

Do not revert 006I-4 quit fix unless explicitly rolling back.
