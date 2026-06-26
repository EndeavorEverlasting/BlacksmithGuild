# The Blacksmith Guild Agent Coordination

This is the central multi-agent coordination document for The Blacksmith Guild.
F7 is legacy infrastructure, not the product gate.

Read this file before touching code, docs, evidence, or automation for the active sprint. Claim the appropriate lane, respect file ownership, and update the board before ending a session.

Related:

- Root agent contract: [`AGENTS.md`](../../AGENTS.md)
- State vocabulary authority: [`runtime-state-routing.md`](runtime-state-routing.md)
- Ortysia live cert landmark: [`ortysia-live-cert-landmark.md`](ortysia-live-cert-landmark.md)
- Window delta doctrine: [`../control/logs/open/window-delta-doctrine.md`](../control/logs/open/window-delta-doctrine.md)
- Autonomous assist target: [`../control/logs/open/autonomous-assist-session-target.md`](../control/logs/open/autonomous-assist-session-target.md)
- Legacy F7 redirect: [`f7-agent-coordination.md`](f7-agent-coordination.md)
- Launch / load playbook: [`agent-launch-and-load-playbook.md`](agent-launch-and-load-playbook.md)
- Sprint control pointer: [`../control/README.md`](../control/README.md)
- Em-dash grep guard: [`../conventions/em-dashes-and-log-grep.md`](../conventions/em-dashes-and-log-grep.md)
- PowerShell UTF-8 BOM (PS 5.1 vs pwsh): [`../conventions/powershell-utf8-bom-doctrine.md`](../conventions/powershell-utf8-bom-doctrine.md)
- Recursive campaign loop doctrine: [`recursive-campaign-assist-loop.md`](recursive-campaign-assist-loop.md)
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

## Current branch map

| Branch / PR | Role | Current relationship |
|---|---|---|
| `main` | Product baseline | @ `3127acd` after PR #14 merge (`85f2f33`); Ortysia live cert landmark |
| PR #11–#13 | Travel execute + runtime producer | Merged into `main` |
| PR #14 | Unattended execute cert runner | **MERGED** @ `85f2f33`; Quyaz→Ortysia travel execute PASS |
| PR #15 | Governance hardening | Rebasing docs/tests onto Ortysia `main`; must not replace this board |
| PR #8 | F7 bisect tooling | **HOLD** — do not merge unless user explicitly authorizes |
| PR #9 | F7 bisect evidence docs | **DEFER** — superseded by Ortysia milestone |

## Routing matrix

| Work item | Primary owner | Consult | Notes |
|---|---|---|---|
| Product PASS / FAIL judgment | Agent A | B, C | Evidence must be fresh and runner-captured. |
| Runtime state machine and readiness truth | Agent B | A | B owns gameplay truth, not launcher choreography. |
| Launcher selection, lifecycle, window classification | Agent C | A, B | Must follow Window Delta Doctrine and PID baseline diff. |
| Docs, atlas, branch routing board | Agent D | All | D records decisions; D does not certify gameplay. |
| PR merge recommendation | Agent A | D | PR #8 remains blocked unless user explicitly authorizes. |
| Autonomous assist target drift | Agent D | A, B, C | Keep docs and tests aligned to the user-facing target. |

## Merge order rules

1. Keep `main` aligned with merged PR #11, PR #12, PR #13, and PR #14.
2. Treat PR #13 runtime outputs as the truth producer for runner work.
3. Do not merge PR #8 unless the user explicitly authorizes that PR.
4. Do not merge coordination docs that contradict this board, `AGENTS.md`, runtime-state routing, Window Delta Doctrine, or the autonomous assist target.

## Evidence rules

- Runner owns evidence capture.
- Do not ask the user to harvest logs manually.
- Do not commit scratch evidence folders, large logs, or transient local dumps.
- Do not claim PASS from stale `Status.json` or stale `BlacksmithGuild_Status.json`.
- PASS requires fresh evidence from the current run, with lifecycle and termination artifacts where applicable.
- If evidence is partial, say partial. If state is inferred, label it as inference.
- F7 is not the product gate; old F7 is infrastructure/regression context unless explicitly routed by the user.

## No manual tedium rule

No agent should route the user into repetitive manual log harvesting, manual launcher babysitting, or manual hotkey ceremony for the preferred path. If a run needs evidence, the runner must capture it. If a target needs a toggle, the file-based toggle must be documented and runner-observable.

## One command, recursive campaign assist target

The product target is one command that builds/deploys if needed, launches Bannerlord, selects Continue automatically, waits for campaign attach, consumes `stateMachine` + `RuntimeLifecycle`, starts the autonomous assist loop without hotkey, and runs a **recursive campaign loop** (observe → choose next safe branch → act → log checkpoint → recompute) until a terminal stop. Checkpoints are progress, not completion. See [`autonomous-assist-session-target.md`](../control/logs/open/autonomous-assist-session-target.md) and [`recursive-campaign-assist-loop.md`](recursive-campaign-assist-loop.md).

## Synthesizing parallel reports

When multiple agents report in parallel:

1. Preserve each agent's concrete findings and file ownership boundaries.
2. Separate facts, inferences, blockers, and recommended routes.
3. Resolve conflicts using the ownership table and routing matrix.
4. Prefer the newest fresh evidence over stale summaries.
5. Do not overwrite another agent's branch or lane without explicit routing.
6. Produce one synthesis that names remaining uncertainty instead of hiding disagreement.

## Stale doctrine

Doctrine is stale when it contradicts current merged code, current runner evidence, this board, `AGENTS.md`, runtime-state routing, Window Delta Doctrine, the autonomous assist target, or the user's explicit current target. Stale doctrine must be updated or explicitly marked historical. Stale evidence must not be used to claim readiness, certification, or gameplay PASS.

---

## Current Sprint Snapshot

| Field | Value |
|-------|-------|
| Product baseline | `main` @ `3127acd` |
| PR #14 | **MERGED** @ `85f2f33` — Ortysia travel execute PASS |
| Landmark | [`ortysia-live-cert-landmark.md`](ortysia-live-cert-landmark.md) |
| Live evidence | `docs/evidence/live-cert/20260625-235004-pr11-launch-attach-execute/` (cite only; do not commit scratch) |
| Active PR | [#15](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/15) — governance/docs selective rebase onto Ortysia `main` |
| Next product target | One-command autonomous assist session ([`autonomous-assist-session-target.md`](../control/logs/open/autonomous-assist-session-target.md)) |
| Current gate | Autonomous assist loop + visible gameplay; not legacy F7 ceremony |

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
| **A** | Agent A — Cert / Evidence / Git / PR | `IDLE` | PR #15 governance rebase + merge readiness | Owns final PASS/FAIL and push/PR hygiene | `3127acd` |
| **B** | Agent B — Runtime / Readiness / Gameplay safety | `IDLE` | Runtime lifecycle and `stateMachine` authority maintenance | Must classify runtime-owned failures before runner churn | `3127acd` |
| **C** | Agent C — External State Classifier / Assistive Runner | `NEXT` | Autonomous assist session one-command target | Owns automation lock and live runner validation | `3127acd` |
| **D** | Agent D — Docs / Atlas / Integration / Routing board | `DONE` | PR #15 governance folded into living board | Preserved runtime routing tables + Ortysia snapshot | branch HEAD |

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
| [#14](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/14) | **MERGED** @ `85f2f33` | Ortysia travel execute PASS; landmark on `main` |
| [#15](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/15) | OPEN / rebasing | Governance/docs selective integration onto Ortysia `main` |
| [#9](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/9) | OPEN / DIRTY | Bisect evidence docs; defer unless explicitly revived |
| [#8](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/8) | OPEN / DIRTY | F7 bisect tooling; **HOLD**, do not merge without user authorization |

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

### 2026-06-26 — Agent D — PR #15 governance folded onto Ortysia main

- Rebased PR #15 onto `main` @ `3127acd`; preserved living board rows and full `runtime-state-routing.md` tables.
- Added `AGENTS.md`, window-delta doctrine, autonomous assist target, contract redirect, and coordination contract test.
- Refreshed sprint snapshot: PR #14 merged, Ortysia landmark authoritative, next target = one-command autonomous assist.

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
