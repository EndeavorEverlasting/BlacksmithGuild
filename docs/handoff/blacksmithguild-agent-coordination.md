# The Blacksmith Guild Agent Coordination

This is the central multi-agent coordination document for The Blacksmith Guild.
F7 is legacy infrastructure, not the product gate.

Read this file before touching code, docs, evidence, or automation for the active sprint. Claim the appropriate lane, respect file ownership, and update the board before ending a session.

Related:

- State vocabulary authority: [`runtime-state-routing.md`](runtime-state-routing.md)
- Legacy F7 redirect: [`f7-agent-coordination.md`](f7-agent-coordination.md)
- Launch / load playbook: [`agent-launch-and-load-playbook.md`](agent-launch-and-load-playbook.md)
- Sprint control pointer: [`../control/README.md`](../control/README.md)
- Em-dash grep guard: [`../conventions/em-dashes-and-log-grep.md`](../conventions/em-dashes-and-log-grep.md)
- Launcher foreground doctrine: [`../conventions/launcher-foreground-doctrine.md`](../conventions/launcher-foreground-doctrine.md)

---

## Protocol

Every agent must:

1. Read this coordination board and [`runtime-state-routing.md`](runtime-state-routing.md) before touching shared sprint files.
2. Claim the relevant row in the agent board (`IN_PROGRESS` plus files and any machine lock).
3. Work only in owned files unless the owner is `DONE` or posts an explicit unblock.
4. Update the board, lock table, and condensed log before ending.
5. Never run launcher/game automation while another agent owns the automation lock.
6. Treat evidence manifests and runtime state files as the authority for PASS/FAIL. No manifest, no medal.

---

## Current Sprint Snapshot

| Field | Value |
|-------|-------|
| Active PR | [#14](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/14) — open draft; do not mark ready or merge |
| Branch | `fix/pr11-unattended-execute-cert-runner` |
| Runner baseline | `0277aa4` — `fix(runner): preserve post-handoff exit classification` |
| Docs posture | Runtime-state coordination docs landed after runner baseline; use branch HEAD for current docs |
| Product baseline | `main` after PR #11 travel execute merge |
| Current blocker | `game_exited_unexpectedly_before_attach` |
| Controlling evidence | `docs/evidence/live-cert/20260625-074633-autonomous-assist-session/` (ignored scratch; cite only, do not commit) |
| Current gate | Runtime/process/assist evidence, not legacy F7 ceremony |
| Out of scope | Product code changes, PR #14 merge/ready state, PR body refresh, live evidence commits, remote branch deletion |

---

## Current Route Table

| Route | Owner | Current next action |
|-------|-------|---------------------|
| Launcher menu misclassified as game | Agent C with Agent B runtime confirmation | Distinguish `launcher_menu_misclassified_as_game` (Continue never clicked, launcher menu foreground, no real `Bannerlord.exe`/mod attach) from true `game_exited_unexpectedly_before_attach`; rotate stale runtime artifacts before re-cert. |
| Runtime/game exit diagnosis | Agent B | Decide whether exit was runtime shutdown, crash, stale heartbeat, launcher-menu misclassification, or expected process disappearance. |
| Post-fix live runner validation | Agent C | Rerun approved unattended assist runner only after Agent B/C code path is fixed and automation lock is clear. |
| PR readiness / evidence judgment | Agent A | Judge manifest/evidence and PR posture after validation completes. |
| Doc/routing freshness | Agent D | Keep this board, routing vocabulary, and active links synchronized. |

---

## Agent Board

| Agent | Letter-first identity | Status | Current task | Blockers for others | Last known commit |
|-------|----------------------|--------|--------------|---------------------|-------------------|
| **A** | Agent A — Cert / Evidence / Git / PR | `IDLE` | PR #14 readiness and evidence judgment after runtime/runner fix | Owns final PASS/FAIL and push/PR hygiene | `0277aa4` |
| **B** | Agent B — Runtime / Readiness / Gameplay safety | `NEXT` | Runtime lifecycle and `stateMachine` authority for game exit diagnosis | Must classify runtime-owned failures before more runner churn | `0277aa4` |
| **C** | Agent C — External State Classifier / Assistive Runner | `NEXT` | Launcher, process, and unattended runner classification after runtime diagnosis | Owns automation lock and post-fix live runner validation | `0277aa4` |
| **D** | Agent D — Docs / Atlas / Integration / Routing board | `DONE` | Added `launcher_menu_misclassified_as_game` routing; preserved F7 redirect stub | Active docs distinguish launcher-menu misclassification from true attach-time exit | branch HEAD |

Status values: `IDLE` | `IN_PROGRESS` | `BLOCKED` | `DONE`.

---

## State Truth Table

| Signal | Source | Owner | Meaning |
|--------|--------|-------|---------|
| launcher visible | UIA/window classifier | Agent C | Launcher, Play/Continue, Safe Mode, or crash reporter state. |
| game process alive | process classifier | Agent C | Bannerlord process existence and post-handoff survival. |
| `Status.json.stateMachine` | mod runtime | Agent B | Gameplay surface and command safety. |
| `RuntimeLifecycle.json` | mod runtime | Agent B | Heartbeat, command lifecycle, shutdown, and stale-runtime evidence. |
| evidence manifest/summary | runner evidence | Agent A | Final PR/cert judgment and PASS/FAIL wording. |
| coordination board | `docs/handoff` | Agent D | Routing, ownership, locks, and handoff state. |

---

## Classification Routing

| Classification | Layer | Primary owner | Secondary owner | Next action |
|----------------|-------|---------------|-----------------|-------------|
| `play_continue_visible` | launcher | Agent C | Agent D | Continue launcher routing or update docs if expected state differs. |
| `continue_selected` | launcher | Agent C | Agent A | Track handoff and prepare evidence ownership. |
| `handoff_requested` | launcher/process | Agent C | Agent B | Watch process and runtime heartbeat. |
| `process_disappeared_during_post_handoff` | process | Agent C | Agent B | Determine whether runtime shutdown evidence exists. |
| `continue_not_found` | launcher | Agent C | Agent D | Inspect launcher timing, Continue/PLAY click path, and nav-error mapping before rerun. |
| `attach_not_ready` | runtime/process | Agent C | Agent B | Wait for fresh runtime files or classify readiness blockers before attach. |
| `launcher_menu_misclassified_as_game` | launcher/process | Agent C | Agent B | Continue never clicked; foreground/window is launcher menu; no real `Bannerlord.exe` or mod attach evidence. Fix classifier/runner path and rotate stale artifacts; do not treat as true runtime crash. |
| `game_exited_unexpectedly_before_attach` | process/runtime | Agent B | Agent C | True unexpected exit only after ruling out `launcher_menu_misclassified_as_game`. Classify exit using process, lifecycle, and state files before rerun; stale runtime artifacts can poison termination classification. |
| `crash_or_unexpected_exit` | runtime/process | Agent B | Agent C | Map lifecycle authority output to shutdown/crash evidence before runner changes. |
| `safe_mode_after_crash` | launcher | Agent C | Agent A | Capture honest failure and avoid cert PASS claims. |
| `crash_reporter` | launcher/process | Agent C | Agent A | Capture failure class and stop automation. |
| `missing_stateMachine` | runtime | Agent B | Agent A | Treat runtime authority as absent; inspect mod logs before runner changes. |
| `stale_RuntimeLifecycle` | runtime | Agent B | Agent C | Check heartbeat age and process state. Script alias: `runtime_heartbeat_stale`. |
| `attach_ready` | runtime/process | Agent C | Agent A | Runner may attach if automation lock is clear. |
| `assist_loop_started` | assist | Agent C | Agent A | Evidence collection begins; runtime remains Agent B-owned. |
| `live_PASS` | evidence | Agent A | Agent D | Update PR/handoff docs and hygiene after validation. |

For full vocabulary and owner mapping, use [`runtime-state-routing.md`](runtime-state-routing.md).

---

## File Ownership Matrix

| Path | Owner | Others may touch if |
|------|-------|---------------------|
| `scripts/autonomous-assist-session.ps1` | Agent C | Runner validation requires it and Agent C is `DONE` or explicitly unblocks. |
| `scripts/process-lifecycle-authority.ps1` | Agent B | Runtime classification contract needs review with Agent B. |
| `scripts/launcher-auto-nav.ps1`, `scripts/focus-bannerlord-window.ps1`, root launcher `.cmd` files | Agent C | Launcher failure is routed and automation lock is clear. |
| `src/**/ForgeStatus.cs`, runtime lifecycle/status producers, state machine consumers | Agent B | Runtime owner posts a handoff. |
| `docs/evidence/live-cert/**` | Agent A | Evidence is sanitized and intended for commit; ignored scratch remains uncommitted. |
| `docs/handoff/blacksmithguild-agent-coordination.md`, `docs/handoff/runtime-state-routing.md` | Agent D | Another agent updates only their board row or posts a handoff entry. |
| `docs/handoff/f7-agent-coordination.md` | Agent D | Redirect stub only; do not restore a live F7 board. |

---

## Machine / Automation Lock

| Lock | Holder | Until | Command |
|------|--------|-------|---------|
| `automation` | — | — | — |

Clear the lock when the run finishes, fails, or the owning agent sets its row back to `IDLE`.

---

## Open PR Triage

| PR | State | Posture |
|----|-------|---------|
| [#14](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/14) | OPEN / DRAFT | Active unattended execute cert runner branch; blocked on `game_exited_unexpectedly_before_attach`; do not mark ready or merge without user authorization. |
| [#9](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/9) | OPEN / DIRTY | Bisect evidence docs; hold unless explicitly revived. |
| [#8](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/8) | OPEN / DIRTY | F7 bisect tooling; HOLD, do not merge without user authorization. |
| [#6](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/6) | OPEN / DRAFT / CLEAN | Second-leg travel feature; not part of PR #14. |
| [#5](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/5) | OPEN / DRAFT / CLEAN | Sell-loop feature; not part of PR #14. |
| [#2](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/2) | OPEN / CLEAN | Identity schema docs; not part of PR #14. |

---

## Cross-Agent Timing Policy

| Limit | Value | Route on breach |
|-------|-------|-----------------|
| Single cert / preflight wall | 10 min max without new user authorization | Abort; Agent A. |
| Launcher Continue / Safe Mode selection | 45 s total | Fail fast; Agent C. |
| Per-attempt launcher verify | 3-5 s | Agent C. |
| Post-handoff process disappearance | Immediate classification; do not rerun blindly | Agent B with Agent C process evidence. |
| Runtime heartbeat staleness | Treat as runtime authority failure until proven otherwise | Agent B. |

Do not rerun legacy F7 Continue as a treadmill seeking PASS.

---

## Condensed Message Log

### 2026-06-25 — Agent D — launcher-menu misclassification routing

- Added `launcher_menu_misclassified_as_game` to [`runtime-state-routing.md`](runtime-state-routing.md) and this board, distinct from true `game_exited_unexpectedly_before_attach`.
- Route owner: Agent C with Agent B runtime confirmation. Signals: Continue never clicked, launcher menu foreground, no real `Bannerlord.exe`/mod attach; stale runtime artifacts can poison termination classification.
- F7 remains legacy redirect only ([`f7-agent-coordination.md`](f7-agent-coordination.md)); not the product gate.

### 2026-06-25 — Agent D — coordination reframe

- Selected `fix/pr11-unattended-execute-cert-runner` @ `0277aa4` and PR #14 as the live sprint context.
- Reframed the coordination board from F7 ceremony to launcher/process/runtime/stateMachine/assist/evidence authority.
- Added [`runtime-state-routing.md`](runtime-state-routing.md) as the dedicated owner-routing vocabulary.

### 2026-06-25 — Agent C — PR #14 classification fix @ `0277aa4`

- Preserved post-handoff exit classification for `game_exited_unexpectedly_before_attach`.
- Current blocker remains runtime/process classification before further live validation.

### 2026-06-25 — Autonomous assist live evidence

- Live session `20260625-074633-autonomous-assist-session` is controlling evidence for the blocker.
- Evidence folder is ignored scratch; cite paths only and do not commit live operational artifacts.
