Repo: EndeavorEverlasting/BlacksmithGuild

Sprint: Execute the bounded BlacksmithGuild night repair queue
Lane: code, tests, fixtures, harness, and safe reports

Prerequisites:
- AgentSwitchboard proved the exact agent route in the same Windows PowerShell execution domain.
- .tbg/plans/gnhf-night-shift/queue.json exists in the starting commit and satisfies schema tbg.gnhf-night-queue.v1.
- Read AGENTS.md, CODEBASE_MAP.md, the selected skill, and .tbg/workflows/gnhf-night-shift.contract.json.

Owned scope:
- at most three ready queue items, one at a time
- only the files each selected item explicitly owns
- .tbg/plans/gnhf-night-shift/queue.json
- docs/handoff/gnhf-night-shift-report.md

Forbidden scope:
- personal saves, accounts, inventories, currencies, purchases, cloud state, multiplayer services, and non-disposable game state
- Bannerlord launch or live proof merely to obtain a stronger proof label
- push, merge, release, deployment, authentication, credentials, branch deletion, worktree removal, destructive Git, or remote-only PR cleanup
- unrelated backlog, broad archaeology, or files outside the active item

Objective:
Repair up to three ready code-level queue items in dependency order without touching personal or live game state. Produce one coherent checkpoint commit per completed item and update the queue and report in that same commit.

Per-item loop:
1. Reconfirm the item evidence, dependencies, owned scope, forbidden scope, and exact acceptance command.
2. Reproduce the defect or prove the missing contract at the narrowest deterministic layer.
3. Make the smallest correct tracked repair.
4. Add or update deterministic enforcement.
5. Run the item validation command.
6. Run the default-static E2E profile after shared harness or contract changes.
7. Update the queue disposition and night report.
8. Checkpoint the coherent slice before broader validation or the next item.

No-progress and failure rules:
- Do not retry an identical failure more than once without a code, configuration, or evidence change.
- Stop an item after two bounded repair attempts.
- Stop the run after two consecutive iterations with no tracked diff.
- Spawn, quota, authentication, network, timeout, malformed output, terminal/backend, and unknown partial-state failures are operational failures; preserve evidence and stop.
- A checkpoint proves preservation only, not completion or runtime behavior.

Allowed proof:
- contract, harness, static tests, build, and explicitly disposable fixture proof when the repository authorizes it
- defer live runtime proof to a separate operator-owned workflow

Required deliverable:
- one commit per completed item, or one committed blocker update preserving exact evidence and the next command

Validation:
- item-specific validationCommand from the queue
- pwsh -NoLogo -NoProfile -File ./scripts/tbg/Test-TbgGnhfNightShift.ps1
- pwsh -NoLogo -NoProfile -File ./scripts/tbg/Invoke-TbgEndToEndValidation.ps1 -Profile default-static when shared harness or contracts change
- powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/test-powershell-utf8-bom-contract.ps1 after PowerShell edits
- git diff --check
- git status --short

Final report:
- queue items attempted and dispositions
- ordered commits and files changed
- tests and exact results
- blockers and preserved state
- remaining ready queue
- runtime proof achieved or explicitly deferred
- proof level and proof ceiling
- final git status --short

Proof ceiling: no higher than the strongest deterministic evidence actually produced; never live runtime by default.
