# F7 Agent Coordination — Start Here

Every Agent A/B/C reads this file before touching F7 launch, Continue, bisect, or certification work.

## Protocol

1. Trust `git log -1 --oneline` over chat, stale screenshots, or copied SHAs.
2. Do not claim F7 PASS without manifest evidence showing map ready and at least 60 seconds of stability.
3. Do not run gameplay-system work while the gate is RED.
4. Use ready-line helpers instead of retyping em-dash text from chat.
5. Do not run `ForgeContinue` and `Run-F7GateContinue` concurrently.
6. Do not invoke `launcher-auto-nav.ps1` bare; use the repo wrappers.
7. Do not use `forge-stop.ps1` while a bisect child PowerShell is active; it can kill matching child processes.
8. Record ownership changes and machine locks in this doc before starting a long run.

## Sprint snapshot

| Field | Current value |
|---|---|
| Branch | `fix/f7-gate-stability` |
| Local HEAD rule | Run `git log -1 --oneline`; do not trust this table if it differs. |
| Known recent HEADs | `ff823a6`, `78abee0`, `4218842`, `dda7c61`, `7516c8c` depending local pull |
| PR #7 | `https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7` — merge only on F7 PASS. |
| PR #8 | `https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/8` — base `fix/f7-gate-stability`; runner stub replaced `bc0d033` (fail-closed gate restored from fix branch). |
| Gate verdict | **RED** |
| Known issue | F7/Continue reaches map-ready on some masks, then the game dies before the 60s stability window. |
| Prior partial progress | `0x01` reached `MapReady` plus `[TBG MAPREADY] StatusFlush ok`, then died during the 60s stability poll. |
| Latest bisect takeaway | `0x07` and `0x0F` completed with MapReady then game death before stability; launcher automation worked under `RespectUserForeground`; this is now Agent B post-MapReady survival. |

## Latest full bisect loop — Agent C / Task 377782

The `0x03` → `0x07` → `0x0F` loop finished after about 19 minutes with overall exit code `2` (**game failure, not launch tooling**).

| Mask | Session | Launcher | Gate result |
|---|---|---|---|
| `0x03` | `20260622-095619` | `continue_clicked` via SendMessage with Cursor foreground | **Incomplete** — exited `-1` about 3 minutes in, likely cut off when `0x07` started. |
| `0x07` | `20260622-095957` | `continue_clicked` plus Safe Mode No | **FAIL exit 2** — `tbg_ready` / MapReady, then `game=gone-after-map-ready` at about 601s. |
| `0x0F` | `20260622-101016` | `continue_clicked` with Chrome foreground | **FAIL exit 2** — nav timed out at 300s, polling still saw `tbg_ready`, then `fail_game_gone_after_map_ready`. |

Evidence manifests reported externally:

- `docs/evidence/live-cert/20260622-095957/checkpoint-01-f7-gate/`
- `docs/evidence/live-cert/20260622-101016/checkpoint-01-f7-gate/`

Summary file: [../evidence/live-cert/f7-bisect-summary.json](../evidence/live-cert/f7-bisect-summary.json).

**Takeaway:** Launcher automation under `RespectUserForeground` is working for Continue and Safe Mode while Chrome/Cursor are foreground. All completed runs share the same gate failure: map-ready is reached, then `Bannerlord.exe` dies before the 60s stability window. Hook mask does not appear to isolate the crash, so Agent B owns post-MapReady survival. No need to re-run `0x03` unless Agent A wants a clean manifest for that mask alone.

## Agent board

| Agent | Primary role | Current lane | Must not touch |
|---|---|---|---|
| Agent A | F7 cert, evidence, PR merge on PASS | Commit available manifests, maintain summary, and hand off to B | Gameplay systems; PR merge while RED |
| Agent B | Post-map-ready crash survival | Interpret sessions `20260622-095957` and `20260622-101016`; investigate death after MapReady | Launcher hwnd automation |
| Agent C | Launcher hwnd / RespectUserForeground validation | Latest loop shows Continue + Safe Mode automation works with Chrome/Cursor foreground | Post-map-ready C# survival work |

## File ownership matrix

| Path | Owner | Notes |
|---|---|---|
| `docs/handoff/f7-agent-coordination.md` | Coordinator | First-read source of truth. |
| `docs/handoff/agent-launch-and-load-playbook.md` | Agent B | PLAY/CONTINUE, Layer A/B, failure ownership. |
| `docs/conventions/em-dashes-and-log-grep.md` | Agent C | Ready-line and grep/encoding guidance. |
| `scripts/bannerlord-paths.ps1` | Agent C | Shared paths plus `Get-TbgReadyGoldenPathPattern`. |
| `scripts/verify-log-grep-patterns.ps1` | Agent C | Guard only; do not rewrite prose titles. |
| `scripts/verify-f7-runner-contract.ps1` | Agent C | Fail-closed static guard; run after runner edits; no game launch. |
| `scripts/run-f7-gate-continue.ps1` | Agent A | Canonical gate wrapper; no concurrent ForgeContinue. |
| `scripts/run-agent-a-f7-bisect.ps1` | Agent A | No concurrent launcher runs; no `forge-stop.ps1` during child run. |
| `scripts/write-launch-log.ps1` | Coordinator | Shared append path; keep race-safe. |

## Machine / automation lock table

| Lock | Holder | Status | Rule |
|---|---|---|---|
| ForgeContinue terminal 89 | User | Must stop before F7 cert | User should stop this terminal before Agent A cert. |
| Bannerlord process | None | Open | One live gate run at a time. |
| F7 bisect child PowerShell | None | Open | If held, do not run `forge-stop.ps1`. |
| Launcher nav lock | None | Open | Clear stale lock only after confirming no active launcher/game automation. |
| Evidence export | None | Open | Export only after a run reaches a terminal verdict. |

## Cross-agent message log

- 2026-06-22: Gate remains RED; stabilize coordination/docs/tooling before more cert attempts.
- 2026-06-22: `0x01` had partial progress but was not PASS; it died during the 60s stability poll.
- 2026-06-22: Agent C full loop finished after about 19 minutes with exit code `2`; `0x07` and `0x0F` reached MapReady/`tbg_ready` and then failed as game-gone-after-map-ready.
- 2026-06-22: Evidence manifests reported at `docs/evidence/live-cert/20260622-095957/checkpoint-01-f7-gate/` and `docs/evidence/live-cert/20260622-101016/checkpoint-01-f7-gate/`; local agents must still trust `git log -1 --oneline` after pulling.
- 2026-06-22: Agent C restored fail-closed F7 runner on PR #8 (`bc0d033` on `codex/stabilize-f7-launch-tooling-and-open-pr`); 16-line `exit 0` stub removed; `verify-f7-runner-contract.ps1` PASS; F7 game PASS still **Not proven**.

## Per-agent next actions

### Agent A

1. Commit/push the externally reported `095957` and `101016` manifests when available in the working tree.
2. Keep `docs/evidence/live-cert/f7-bisect-summary.json` current.
3. Hand off to Agent B for post-MapReady survival; do not re-run `0x03` unless a clean mask-specific manifest is required.
4. If re-running later, confirm branch and HEAD with `git pull`, `git branch --show-current`, and `git log -1 --oneline`.
5. Merge PR #7 only after F7 PASS.

### Agent B

1. Treat all masks as failing after map-ready; focus on post-map-ready survival, not single-hook bisect toggles.
2. Interpret sessions `20260622-095957` and `20260622-101016`, plus prior `095326` if needed.
3. Keep `agent-launch-and-load-playbook.md` current with the failure stage and owner.
4. Do not request cert marathon until Agent A records F7 PASS evidence.

### Agent C

1. Keep launcher automation evidence attached to the summary; latest loop shows Continue/Safe Mode works under `RespectUserForeground`.
2. Verify PLAY smoke separately only if launcher scope changes again.
3. Run `scripts/verify-log-grep-patterns.ps1` after script/doc changes.
4. Use `Get-TbgReadyGoldenPathPattern`; never grep the ASCII-hyphen ready-line lookalike.

## Required links

- Recovery sprint handoff: [f7-recovery-sprint-handoff.md](f7-recovery-sprint-handoff.md)
- Parallel sprint chat: [f7-parallel-sprint-agent-chat.md](f7-parallel-sprint-agent-chat.md)
- Launch/load playbook: [agent-launch-and-load-playbook.md](agent-launch-and-load-playbook.md)
- Em-dash grep convention: [../conventions/em-dashes-and-log-grep.md](../conventions/em-dashes-and-log-grep.md)
