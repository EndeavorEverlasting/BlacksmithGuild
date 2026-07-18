Repo: EndeavorEverlasting/BlacksmithGuild

Sprint: Compile the bounded BlacksmithGuild night repair queue
Lane: planning and evidence only

Prerequisites:
- AgentSwitchboard proved the exact agent route in the same Windows PowerShell execution domain.
- The source checkout is clean, attached, and not already on a gnhf/* branch.
- Read AGENTS.md, CODEBASE_MAP.md, .tbg/skills/manifest.json, and .tbg/workflows/gnhf-night-shift.contract.json.

Owned scope:
- .tbg/plans/gnhf-night-shift/queue.json
- docs/handoff/gnhf-night-shift-report.md
- only directly required parent directories

Forbidden scope:
- product code, tests, build files, launchers, saves, runtime evidence, and game state
- push, merge, release, deployment, authentication, credentials, branch deletion, worktree removal, destructive Git, or remote-only PR cleanup

Objective:
Inspect current repository evidence and commit a finite queue of no more than five evidence-backed repair items. Do not repair product code in this run.

Each queue item must include:
- id, title, and state ready or blocked
- exact evidence path, failing command, review finding, or reproducible symptom
- root-cause hypothesis labeled as a hypothesis
- owned scope and forbidden scope
- dependencies and collision risks
- exact targeted validation command
- risk and bounded size

Execution loop:
1. Verify current Git and GitHub state without mutating remote state.
2. Prefer current code, tests, validators, CI, and recent history over stale plans.
3. Reject speculative candidates rather than filling the queue.
4. Write queue schema tbg.gnhf-night-queue.v1 at .tbg/plans/gnhf-night-shift/queue.json.
5. Write the baseline report at docs/handoff/gnhf-night-shift-report.md.
6. Run the night-shift contract validator.
7. Commit only the queue, report, and directly required directories.

No-progress rule:
Stop after two bounded evidence passes without a defensible ready item. A queue/report commit is still mandatory and must record the exact blockers.

Required deliverable:
- one commit containing the queue and baseline report

Validation:
- pwsh -NoLogo -NoProfile -File ./scripts/tbg/Test-TbgGnhfNightShift.ps1
- git diff --check
- git status --short

Final report:
- repository floor and evidence inspected
- candidates selected or rejected and why
- ready queue in dependency order
- blocked items
- commit SHA
- proof level and proof ceiling
- final git status --short

Proof ceiling: repository contract and static validation only.

Do not launch Bannerlord, mutate personal state, push, merge, deploy, authenticate, or claim runtime behavior.
