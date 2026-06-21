# 006J Plan — Full Live Cert Closeout

## Status

**LAUNCHER CERT CLOSED (2026-06-21)** — Path B waived; Continue + Path C user confirmed. Smithing queue next.

**Handoff:** [docs/checkpoints/pre-blacksmith-automation-handoff.md](../checkpoints/pre-blacksmith-automation-handoff.md)

| Gate | Status |
|------|--------|
| Path A bootstrap | **USER PASS** |
| Path B culture Back | **WAIVED** — obsolete (auto-skip) |
| Path C quit (play + continue) | **USER PASS** 2026-06-21 |
| Continue load (006I-5) | **USER PASS** |
| Layer A handoff | Optional — not blocking |
| Market Ctrl+Alt+M | **USER PASS** 2026-06-20 |
| 006I LIVE CERT tag | **CLOSED** — use pre-blacksmith handoff instead |
| 005E smithing posse | **UNBLOCKED** |

## Agent analysis (2026-06-19)

```text
Verdict: RE-CERT PARTIAL — cannot mark LIVE CERT PASS
Layer A (handoff): FAIL — no handoff: line in Launch.log tail
Path A (bootstrap): PASS — intro skip count=1, TBG READY 02:32:04
Path B (culture Back): PENDING — no culture Back evidence in logs
Path C (quit): PASS — decision=block reason=intent already consumed ~02:31:27
Continue load: PENDING — LaunchForgeContinue not evidenced; no Module Mismatch click
Market F12: FAIL — MarketIntel.json not found; no MARKET INTEL in Phase1.log
PASS/FAIL: FAIL (partial)
Smallest next fix: User runs full cert matrix (see Track A); ensure Bannerlord fully closed before each entrypoint
Exact evidence lines:
  Phase1: intro skip: campaign video via OnActivate (count=1)
  Phase1: TBG READY: campaign map ready. Press F8 for commands. (02:32:04)
  Phase1: decision=block reason=intent already consumed (02:31:27)
  Launch.log: launcher-auto: timeout: visible launcher buttons: no launcher buttons visible (02:32:35, 02:33:46)
  MarketIntel.json: file not present
```

## Why this sprint

Code shipped; cert is not. Two features await user evidence:

| Feature | Commit | Blocker |
|---------|--------|---------|
| 006I-5 Continue / Module Mismatch / watchdog | `2418cbd` | Load path matrix rows 1–5 not user-verified |
| 005E-M Market Intel F12 | `94e5958` | F12 not user-verified near a town |
| 006I overall | — | Path B culture Back PENDING; Layer A `handoff:` PENDING |

**006I LIVE CERT PASS** unblocks [005e-smithing-posse-stamina-output.plan.md](005e-smithing-posse-stamina-output.plan.md).

## Repo baseline

| Field | Value |
|-------|-------|
| HEAD | `94e5958` |
| Rollback tag | `006i-4-path-c-pass` @ `57f6062` |
| Branch | `main` only; no open PRs |
| Remote | 12 commits ahead — **do not push** unless user requests |
| Version | `v0.0.11` |

## Track A — User cert protocol

**Precondition:** No `Bannerlord.exe` or Launcher processes.

1. `.\Forge.cmd` → TBG READY; collect Launch.log for `handoff:`
2. Close game; `.\LaunchForgeContinue.cmd` → expect `clicked Module Mismatch Yes` → map
3. Fresh `.\Forge.cmd` → culture stage Back/Escape → no full intro replay
4. On map near town → F12 → MARKET INTEL table + JSON with prices > 0

**Log collection:**

```powershell
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log" -Tail 220
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log" -Tail 80
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_MarketIntel.json"
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json"
```

## Track B — On full PASS (agent)

1. Tag `006i-live-cert-pass` at HEAD
2. Create `docs/checkpoints/post-006j-handoff.md`
3. Update `docs/sprint-006i-live-results.md` → LIVE CERT PASS
4. Create `docs/sprint-005e-m-market-intel-live-results.md` → LIVE CERT PASS
5. Update `NEXT_STEPS.md` — unblock 005E smithing posse
6. Mark 006I-5 plan SHIPPED/PASS
7. Commit; no push unless user requests

## Track B — On FAIL (failure → fix map)

| Failure | Likely fix location |
|---------|---------------------|
| Module Mismatch not clicked | `scripts/launcher-auto-nav.ps1` |
| Continue stall after Yes | `MainMenuAutoLauncher.cs`, intro skip during load |
| No `handoff:` | `scripts/launcher-auto-nav.ps1` timeout/stable polls |
| Path B cutscene replay | `SandboxCampaignIntroSkip.cs` |
| F12 all prices 0 | `MarketIntelligenceService.cs` |
| F12 map not ready | Gate messaging only |

## Output files to analyze

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_MarketIntel.json
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Forge.log
```

## Known gaps and risks

| Gap / risk | Notes |
|------------|-------|
| Layer A `handoff:` | Launch.log shows repeated launcher timeouts when buttons not visible — may indicate game already running |
| Continue path | Never evidenced in current log set; 006I-5 fix unverified |
| Path B | Not re-certified after 006I-4 |
| Market F12 | Not run; JSON absent |
| Module Mismatch UIA false positive | **RISK** — `mismatch` substring on desktop UIA tree; tighten to game/launcher window |
| Version | Stay at `v0.0.11` until full PASS |

## Scope lock

- **In:** cert analysis, doc/checkpoint/tag on PASS, targeted fixes on FAIL
- **Out:** 005E smithing posse implementation, Gauntlet market UI, version bump, push
