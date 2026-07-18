Repo: EndeavorEverlasting/BlacksmithGuild

Sprint: Execute one bounded BlacksmithGuild Good Night, Have Fun night shift
Lane: evidence-led queue compilation, state-safe repair, and closeout

Prerequisites:
- AgentSwitchboard has already proved the exact DeepSeek/OpenCode route in native Windows PowerShell 7.
- The source checkout is clean, attached, and not on a gnhf/* branch.
- Read AGENTS.md, CODEBASE_MAP.md, .tbg/skills/manifest.json, .tbg/workflows/checkpoint-discipline.contract.json, and .tbg/workflows/gnhf-night-shift.contract.json.

Owned scope:
- .tbg/plans/gnhf-night-shift/queue.json
- docs/handoff/gnhf-night-shift-report.md
- docs/handoff/gnhf-night-shift-closeout.md
- files explicitly owned by at most three selected queue items
- deterministic tests, fixtures, validators, contracts, and safe reports required by those items

Forbidden scope:
- personal saves, accounts, inventories, currencies, purchases, cloud state, multiplayer services, and non-disposable game state
- Bannerlord launch or live proof merely to obtain a stronger proof label
- push, merge, PR closure, release, deployment, authentication, credentials, branch deletion, worktree removal, reset, clean, force push, or destructive reconciliation
- unrelated backlog, speculative features, broad archaeology, visible-trade PR changes, or files outside the active queue item

Objective:
Complete the V38 night chain in this one isolated GNHF worktree:
P38 commit a finite evidence-backed queue, then P41 repair up to three ready code-level items with recoverable commits, then P44 commit the closeout. P37 spawn proof is owned by AgentSwitchboard before this objective begins.

Phase 1 — P38 queue checkpoint:
1. Inspect current Git/GitHub state, current source, tests, validators, CI, open PRs, and recent history.
2. Build a finite queue of no more than five defensible items. Reject speculation rather than filling the queue.
3. For each item record id, title, state, evidence, hypothesis labeled as hypothesis, owned scope, forbidden scope, dependencies, collision risks, exact validationCommand, and risk.
4. Write schema tbg.gnhf-night-queue.v1 to .tbg/plans/gnhf-night-shift/queue.json.
5. Write the baseline report to docs/handoff/gnhf-night-shift-report.md.
6. Run the night-shift validator and commit this queue/report checkpoint before repairing code.

Phase 2 — P41 state-safe repair:
1. Select at most three ready code-level items in dependency order.
2. Reconfirm evidence and reproduce each defect at the narrowest deterministic layer.
3. Make the smallest correct tracked repair and add deterministic enforcement.
4. Run the item validation command, then applicable shared harness validation.
5. Update the queue and report and create one coherent commit per completed or evidence-blocked item.
6. Do not continue an item after two bounded repair attempts. Do not retry an identical failure without changed code, configuration, or evidence.

Phase 3 — P44 closeout:
1. Do not start another queue item after the repair limit is reached.
2. Reconcile every queue item to completed, blocked, superseded, rejected, or not attempted.
3. Run final targeted validation and the default-static E2E profile when shared harness or contracts changed.
4. Confirm generated artifacts, credentials, personal paths, saves, and runtime logs are not staged.
5. Write docs/handoff/gnhf-night-shift-closeout.md with starting/final HEAD, ordered commits, files, validation, artifacts, blockers, proof ceiling, recommended human review action, and one exact next command.
6. Commit the closeout and end with a clean generated GNHF worktree, or commit an exact blocker report that preserves current state.

No-progress and operational-failure rules:
- Stop after two consecutive iterations produce no tracked progress.
- Spawn, quota, authentication, network, timeout, malformed output, terminal/backend, and unknown partial-state failures are operational failures. Preserve worktree, branch, logs, notes, and exact review commands.
- Process exit zero, configured stop text, a checkpoint, parser success, or launcher handoff is not delivery proof.
- A checkpoint proves preservation only.

Required deliverables:
- queue/report checkpoint commit before code repair
- one commit per completed or evidence-blocked repair item, up to three
- final closeout commit
- or an exact committed blocker report preserving all useful work

Validation:
- item-specific validationCommand values from the queue
- pwsh -NoLogo -NoProfile -File ./scripts/tbg/Test-TbgGnhfNightShift.ps1
- pwsh -NoLogo -NoProfile -File ./scripts/tbg/Invoke-TbgEndToEndValidation.ps1 -Profile default-static when shared harness or contracts change
- powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/test-powershell-utf8-bom-contract.ps1 after PowerShell edits
- git diff --check
- git status --short

Final report:
- queue items and final dispositions
- ordered commits and files changed
- validation actually run and exact results
- skipped checks and why
- blockers and preserved state
- proof level and proof ceiling
- recommended human push or PR action
- one exact next command
- final git status --short

Proof ceiling: no higher than the strongest deterministic evidence actually produced; live runtime is deferred to a separate explicitly authorized operator workflow.
