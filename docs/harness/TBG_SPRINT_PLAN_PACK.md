# TBG Sprint Plan Pack

## Purpose

Use this pack to launch bounded, parallel Blacksmith Guild sprint chats without losing PR context, worktree safety, proof standards, or artifact expectations.

Use rule:

```text
Copy one block into one new chat.
Do not paste multiple blocks into the same chat.
Each block has a banner so parallel agents can distinguish themselves.
```

This pack borrows three practical patterns:

```text
final report structure with proof, changed files, gaps, git state, and exact next command
bounded one-chat sprint prompts with read-first files, mission, safety, tests, and final response contract
launch order, dependency control, no duplicate ownership, and floor-before-furniture sequencing
```

## Global TBG Coordination Rules

Apply these to every sprint below.

```text
Repo: EndeavorEverlasting/BlacksmithGuild
Primary local repo: C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild

Never assume repo state from the prompt.
First inspect:
- git fetch origin
- git status --short
- git branch --show-current
- git log --oneline --decorate -8
- gh pr list --state open --limit 20

Do not mutate the primary worktree if it is dirty, conflicted, or mid-merge unless this sprint explicitly owns cleanup.

Prefer sibling worktrees for parallel sprint work:
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-<sprint-name>

Do not claim completion without evidence:
- passing checks
- validator output
- generated artifacts
- git diff/status
- clean tree or clearly stated dirty tree
- pushed branch / PR URL when applicable

Do not claim live runtime success from static/doc/test success.

Use the distinction:
- contract proof
- harness proof
- launcher proof
- map-ready proof
- command ACK proof
- route issued proof
- movement observed proof
- live gameplay proof

If Bannerlord must not be running, run stop first:
.\ForgeStop.cmd soft

Do not rely on terminal focus.
Do not leave the user with hanging prompts or ambiguous instructions.
Do not mutate personal saves.
Do not add free gold/resources/XP/materials.
Do not commit runtime logs, personal saves, generated evidence, or ignored local tool installs.
Do not touch harness/API manifests unless the sprint explicitly owns that surface.
```

## Launch Order

### Wave 0 — unblock the floor

1. Chat 00 — Repo / PR / Worktree Hygiene
2. Chat 01 — 037B MCP/LSP Symbol Smoke Recovery

### Wave A — harness spine

3. Chat 02 — Canonical TBG Run Context + Artifact Registry
4. Chat 03 — English Sprint Report Renderer
5. Chat 04 — End-to-End Harness Validator

### Wave B — runtime reliability

6. Chat 05 — ForgeStop / Launcher / Focus Safety
7. Chat 06 — Route-Owned Clock Live Proof

### Wave C — agent leverage

8. Chat 07 — Read-Only MCP Code Intelligence Catalog
9. Chat 08 — Local Hook and Artifact Hygiene

Important dependency rule:

```text
Do not let report/dashboard/MCP layers invent output shapes before the run context and artifact registry exist.
Do not let runtime proof proceed on a conflicted or unknown worktree.
Do not let MCP symbol navigation claim success while csharp-ls/project-load remains missing.
```

## Chat 00 — Repo / PR / Worktree Hygiene

```text
TBG CHAT 00
Sprint: Repo / PR / worktree hygiene and sprint map
Repo: EndeavorEverlasting/BlacksmithGuild
Branch: do not create a feature branch unless needed for hygiene docs/scripts
Lane: coordinator / cleanup
Scope: verify current repo, PRs, branches, worktrees, merge/conflict state, and safe next sprint base
Forbidden scope: gameplay changes, launcher changes, route logic changes, MCP implementation changes, save mutation, runtime claims
Expected artifacts:
- docs/handoff/038a-repo-hygiene-sprint-map.md if useful
- artifacts/latest/repo-hygiene.result.json if artifacts/latest pattern exists

You are continuing The Blacksmith Guild.

Start by identifying:
- repo path
- current branch
- open PRs
- dirty/conflicted state
- whether the primary worktree is safe for work
- whether sibling worktree is required
- which branch should be the base for the next sprint

Run first:
git fetch origin
git status --short
git branch --show-current
git log --oneline --decorate -8
git worktree list
gh pr list --state open --limit 20

Mission:
Produce a clean sprint map for the next TBG work. Do not implement feature work.

Resolve only if explicitly safe:
- stale local branches
- already-merged local branches
- accidental untracked temp files
- obvious ignored/generated artifact clutter

If the repo is mid-merge or conflicted:
- do not guess
- identify conflicted files
- identify the commit/branch involved
- preserve local work before destructive actions
- recommend the exact next command

Required analysis:
- Is PR #39 still open?
- Is the 037B MCP/LSP work pushed?
- Is the primary worktree dirty/conflicted?
- Is `feat/route-owned-clock-resume` still the runtime route lane?
- Is there a safe base for `sprint/038b-mcp-symbol-smoke-recovery`?
- Is there a safe base for runtime route proof?

Safety:
- Do not run Bannerlord.
- Do not run ForgeReboot.
- Do not change gameplay code.
- Do not merge PRs unless explicitly authorized.
- Do not delete branches unless they are proven merged and safe.
- Do not commit runtime logs or generated evidence.

Validation:
- git status --short
- git worktree list
- gh pr list --state open --limit 20
- git diff --check if any files changed

Final response must include:
- Repo
- Current branch
- PR/sprint context
- Lane
- Scope
- Forbidden scope
- Work completed
- PR map
- Worktree map
- Changed files, if any
- Validation output
- Gaps/risks
- Exact next command
- Copy-paste handoff prompt for Chat 01
```

## Chat 01 — 037B MCP/LSP Symbol Smoke Recovery

```text
TBG CHAT 01
Sprint: 038B MCP/LSP symbol smoke recovery
Repo: EndeavorEverlasting/BlacksmithGuild
Branch: sprint/038b-mcp-symbol-smoke-recovery
Lane: MCP/LSP harness proof
Scope: recover 037B symbol-smoke lane, fix prerequisites, produce honest MCP/LSP readiness artifacts
Forbidden scope: gameplay logic, launcher automation, route-owned clock, runtime proof, save mutation
Expected artifacts:
- artifacts/latest/mcp-readiness.result.json
- artifacts/latest/mcp-symbol-smoke.result.json
- artifacts/latest/done-gate.result.json
- docs/handoff/038b-mcp-symbol-smoke-recovery.md

You are continuing The Blacksmith Guild.

Context:
The prior 037B sprint replaced a stub with a real MCP JSON-RPC harness that starts csharp-lsp-mcp, lists C# MCP tools, calls csharp_set_workspace, only runs symbol queries after LSP/project load succeeds, and writes artifacts/latest/mcp-symbol-smoke.result.json.

Known gap:
Do not claim live symbol navigation yet if `csharp-ls` is missing or the project is not loaded. Prior result was:
- status = missing_prereqs
- verdict = lsp_project_not_loaded

Read first:
- AGENTS.md if present
- .tbg/workflows/mcp-symbol-smoke.contract.json if present
- .tbg/harness/prompts/tbg-symbol-smoke.md if present
- scripts/mcp/Test-TbgMcpReadiness.ps1
- scripts/mcp/Test-TbgMcpSymbolSmoke.ps1
- scripts/harness/Test-TbgHarnessReadiness.ps1
- scripts/harness/Test-TbgDoneGate.ps1
- docs/architecture/local-mcp-code-intelligence.md
- docs/architecture/mcp-lsp-symbol-smoke-setup.md if present
- docs/handoff/037b-mcp-symbol-smoke.md if present

Mission:
Turn the 037B candidate into an honest, repeatable MCP/LSP smoke proof.

Tasks:
1. Verify repo state and branch base.
2. Create isolated worktree if primary is dirty/conflicted.
3. Verify local tool prerequisites.
4. Fix strict-mode or parsing issues in harness tests only if reproducible.
5. Install or document `csharp-ls` prerequisite without committing ignored tool folders.
6. Make readiness artifacts explicit: mcp_bridge_present, csharp_tools_listed, workspace_set_attempted, lsp_project_loaded, symbol_queries_allowed, symbol_queries_blocked_reason.
7. Make symbol-smoke result honest: pass only when project load succeeds and symbol queries return usable results; missing_prereqs when tools exist but project cannot load; fail when harness contract is broken.
8. Update docs/handoff with the exact next command.

Safety:
- Do not mutate gameplay code.
- Do not claim symbol navigation if `csharp-ls` or project load is missing.
- Do not commit `.local/mcp-tools`.
- Do not weaken done gate.
- Do not hide LF/CRLF warnings; report them separately from failures.

Validation:
Run the strongest applicable set:
- powershell -ExecutionPolicy Bypass -File scripts/harness/Test-TbgHarnessReadiness.ps1
- powershell -ExecutionPolicy Bypass -File scripts/mcp/Test-TbgMcpReadiness.ps1
- powershell -ExecutionPolicy Bypass -File scripts/mcp/Test-TbgMcpSymbolSmoke.ps1
- powershell -ExecutionPolicy Bypass -File scripts/harness/Test-TbgDoneGate.ps1
- git diff --check
- git status --short

Final response must follow the x-style structure:
- Completed Work
- Validation Output
- Generated Artifacts
- Known Gaps/Risks
- Changed Files
- Git Status
- Exact Next Command
- PR URL if opened
```

## Chat 02 — Canonical TBG Run Context + Artifact Registry

```text
TBG CHAT 02
Sprint: 038C canonical run context and artifact registry
Repo: EndeavorEverlasting/BlacksmithGuild
Branch: sprint/038c-run-context-artifact-registry
Lane: harness spine
Scope: reusable TBG run context, artifact registry, result metadata
Forbidden scope: launcher automation, route logic, gameplay mutation, MCP symbol implementation, live runtime proof
Expected artifacts:
- scripts/harness/TbgRunContext.psm1
- Tests or scripts validating the run context contract
- docs/architecture/tbg-run-context-artifact-registry.md
- artifacts/latest/run-context.result.json if generated by validation

You are continuing The Blacksmith Guild.

Mission:
Add a canonical run context and artifact registry contract so future harness operations stop inventing their own output conventions.

Read first:
- AGENTS.md if present
- scripts/harness/Test-TbgHarnessReadiness.ps1
- scripts/harness/Test-TbgDoneGate.ps1
- scripts/mcp/Test-TbgMcpReadiness.ps1 if present
- scripts/mcp/Test-TbgMcpSymbolSmoke.ps1 if present
- .tbg/workflows/*.contract.json if present
- docs/handoff/*.md relevant to harness/reporting
- .gitignore

Add:
- scripts/harness/TbgRunContext.psm1
- docs/architecture/tbg-run-context-artifact-registry.md
- a focused validator for the module, using existing test style

Run context should include:
- workflow_id
- run_id
- started_at
- repo_root
- branch
- commit
- output_root
- artifact_registry_path
- runtime_activity_planned
- runtime_activity_performed
- game_process_required
- forge_stop_required
- low_noise_policy_version if present
- command_safety_policy_version if present

Artifact record should include:
- role
- path
- tracked
- generated
- contains_runtime_data
- contains_save_data
- contains_live_game_evidence
- description
- sha256 optional
- created_at

Required artifact roles:
- source
- contract
- result_json
- report
- handoff
- log
- validator_output
- next_command

Rules:
- `artifacts/latest` may point to latest generated local proof.
- Timestamped artifacts should be supported.
- Runtime logs and generated evidence must be tracked=false.
- Docs/contracts/tests may be tracked=true.
- Registry must not require Bannerlord to run.
- Registry must not include secrets or personal save paths unless marked generated/runtime/private and untracked.

Tests must prove:
1. Module exists and parses.
2. Required functions exist.
3. Synthetic registry can be written and read.
4. Runtime artifacts are tracked=false.
5. Docs/contracts are tracked=true.
6. Save/runtime evidence is never suggested for commit.
7. Module does not launch Bannerlord.
8. Module does not call ForgeReboot.
9. Module can be consumed by future validators.

Validation:
- Run the new focused test.
- Run existing harness readiness if available.
- Run done gate if available.
- git diff --check
- git status --short

Final response:
- PR branch name
- Files changed
- Function summary
- Artifact roles implemented
- Tests run
- Gaps/risks
- Remaining integration targets
- PR URL if opened
```

## Chat 03 — English Sprint Report Renderer

```text
TBG CHAT 03
Sprint: 038D English sprint report renderer
Repo: EndeavorEverlasting/BlacksmithGuild
Branch: sprint/038d-english-sprint-report-renderer
Lane: operator-readable reporting
Scope: render English reports from TBG result JSON and artifact registry
Forbidden scope: gameplay logic, launcher automation, runtime proof, MCP implementation, command execution
Expected artifacts:
- scripts/harness/Render-TbgSprintReport.ps1
- docs/architecture/tbg-english-sprint-report-contract.md
- fixtures or synthetic sample inputs
- artifacts/latest/sprint-report.result.json
- artifacts/latest/operator-report.md

Dependency:
Prefer after Chat 02 lands. If TbgRunContext does not exist, use a local fixture and clearly mark integration as pending. Do not invent incompatible registry structure.

Mission:
Create the report renderer that turns harness artifacts into useful x-style sprint output the user can trust.

Report must include:
- Sprint banner
- Repo
- Branch
- PR/sprint
- Lane
- Scope
- Forbidden scope
- Completed work
- Validation output
- Generated artifacts
- Known gaps/risks
- Changed files
- Git status
- Exact next command
- Copy-paste handoff prompt when requested

Required language:
- contract proof must be distinct from runtime proof
- route assignment is not movement proof
- symbol smoke is blocked until LSP project load succeeds when applicable
- ForgeStop is required before workflows that require the game to be off when applicable

Safety:
- Renderer performs no runtime activity.
- Renderer does not launch Bannerlord.
- Renderer does not run ForgeReboot.
- Renderer does not mutate files except its output path.
- Synthetic fixtures only.
- Do not include personal save paths in fixtures.

Validation:
- Run new renderer contract test.
- Run harness readiness if available.
- Run done gate if available.
- git diff --check
- git status --short

Final response:
- PR branch name
- Files changed
- Report sections implemented
- Tests run
- Safety proof
- Gaps/risks
- PR URL if opened
```

## Chat 04 — End-to-End Harness Validator

```text
TBG CHAT 04
Sprint: 038E end-to-end synthetic harness validator
Repo: EndeavorEverlasting/BlacksmithGuild
Branch: sprint/038e-harness-validator
Lane: one-command harness proof
Scope: offline/synthetic validator that aggregates safe TBG harness checks
Forbidden scope: live game execution, launcher execution, route runtime proof, gameplay mutation, save mutation
Expected artifacts:
- scripts/harness/Validate-TbgHarness.ps1
- docs/handoff/038e-harness-validator.md
- artifacts/latest/harness-validation.result.json

Dependency:
Best after Chat 01, Chat 02, and Chat 03. If optional dependencies are missing, report SKIP or actionable FAIL. Do not implement missing dependencies here.

Mission:
Create one command that tells the user whether the TBG harness spine is ready.

Expected output:
TBG HARNESS VALIDATION
[PASS] harness readiness
[PASS] run context
[PASS] artifact registry
[PASS] English sprint report renderer
[PASS] MCP bridge readiness
[SKIP] MCP symbol smoke: lsp_project_not_loaded
[PASS] done gate

Result: 5 passed / 1 skipped / 0 failed

Validator should:
1. Detect repo root.
2. Print branch and commit.
3. Run safe offline harness validators.
4. Detect optional components.
5. Emit JSON result.
6. Emit English matrix.
7. Never claim runtime proof.
8. Fail clearly when a required validator is broken.

Safety:
- No Bannerlord launch.
- No ForgeReboot.
- No runtime mutation.
- No save mutation.
- No personal saves.
- No command inbox mutation.
- No route triggering.

Validation:
- Run new validator contract test.
- Run Validate-TbgHarness.ps1.
- Run done gate if safe.
- git diff --check
- git status --short

Final response:
- PR branch name
- Matrix behavior
- Dependencies detected
- Tests run
- Skipped checks and why
- Generated artifacts
- PR URL if opened
```

## Chat 05 — ForgeStop / Launcher / Focus Safety

```text
TBG CHAT 05
Sprint: 038F ForgeStop, launcher, and focus safety
Repo: EndeavorEverlasting/BlacksmithGuild
Branch: sprint/038f-launcher-focus-safety
Lane: runtime safety / launcher automation reliability
Scope: make stop-before-runtime and launcher/focus behavior explicit, testable, and non-ambiguous
Forbidden scope: route-owned clock implementation, smithing mechanics, MCP implementation, free resource mutation, personal save mutation
Expected artifacts:
- docs/handoff/038f-launcher-focus-safety.md
- updated launcher/assist scripts only if needed
- artifacts/latest/launcher-safety.result.json if validator exists

Context:
The user does not want ambiguous terminal/focus instructions. If the game must be off, use:
.\ForgeStop.cmd soft

Mission:
Harden launcher/focus safety so runtime sprints stop wasting tokens on manual ambiguity.

Required behavior:
- Any workflow requiring game-off state must call ForgeStop first or declare why it does not.
- Human-facing stop may wait briefly.
- Agent-facing stop should not create pointless delays.
- Launcher navigation must not rely on terminal focus.
- Continue/Singleplayer handoff must have proof artifacts.
- Safe Mode/crash reporter handling must remain bounded.
- The script must tell the user exactly what state it expects: game off, launcher open, campaign loaded, map ready, or no runtime needed.

Safety:
- Do not start Bannerlord unless the sprint explicitly says runtime proof is required.
- Do not run ForgeReboot as a default validation step.
- Do not mutate saves.
- Do not hide launcher failures.
- Do not use infinite waits.
- Do not introduce blind clicks without bounded context checks.

Validation:
- Run focused launcher/stop safety tests.
- Run harness validator if available.
- git diff --check
- git status --short

Final response:
- PR branch name
- Safety behavior before/after
- Files changed
- Tests run
- Runtime not-run note or runtime proof artifacts
- Gaps/risks
- Exact next command
- PR URL if opened
```

## Chat 06 — Route-Owned Clock Live Proof

```text
TBG CHAT 06
Sprint: 038G route-owned clock live proof
Repo: EndeavorEverlasting/BlacksmithGuild
Branch: sprint/038g-route-owned-clock-live-proof
Lane: runtime route proof
Scope: prove visible route start under mod control with route-owned clock behavior
Forbidden scope: smithing, tavern recruitment, generic guild loop, market inventory trading, MCP implementation, free resource mutation, personal save mutation
Expected artifacts:
- BlacksmithGuild_Phase1.log evidence collected locally
- MapTradeRouteCert or equivalent route cert artifact if implemented
- artifacts/latest/route-owned-clock-live-proof.result.json
- docs/handoff/038g-route-owned-clock-live-proof.md

Dependency:
Do not start until Chat 00 has verified clean repo state and Chat 05 has confirmed launcher/focus safety, or explicitly document why the dependency is skipped.

Known doctrine:
- Checkpoint is not completion.
- Route assignment is not movement proof.
- AutoTravelToRecommended can ACK success while campaign time remains stopped.
- The desired proof is visible route start under mod control.

First engine must be:
CampaignMapReadyOrchestrator
-> AgentAutoMapTradeRoute trigger
-> MapTradeAutonomousService.StartRouteNow("AgentAutoMapTradeRoute")

Mission:
Produce honest live proof that the mod starts route travel and campaign time/movement behaves as expected.

Before live runtime:
.\ForgeStop.cmd soft

Required proof chain:
- ForgeStop completed if game-off was required
- launcher selected Continue or equivalent documented path
- attach succeeded
- campaignReady true
- mapStateActive true
- safeToExecuteTravel true
- command inbox acknowledged if used
- AgentAutoMapTradeRoute trigger observed
- MapTradeAutonomousService.StartRouteNow observed
- route issued/started
- movement observed or explicitly failed with reason
- route cert artifact collected
- logs collected with CollectCertLogs.cmd if applicable

Safety:
- Use disposable save only.
- Do not mutate personal saves.
- Do not add free resources.
- Do not alter unrelated gameplay systems.
- Do not claim movement proof from ACK alone.
- Do not loop endlessly.
- Bound all waits.
- If the game is already loaded and evidence says no reboot is needed, do not rerun ForgeReboot.

Validation:
- targeted build/test before runtime
- runtime proof collection
- log grep / artifact check proving the required chain
- git diff --check
- git status --short

Final response:
- PR branch name
- Runtime state used
- Completed work
- Live proof chain
- Validation output
- Generated artifacts/logs
- Changed files
- Known gaps/risks
- Git status
- Exact next command
- PR URL if opened
```

## Chat 07 — Read-Only MCP Code Intelligence Catalog

```text
TBG CHAT 07
Sprint: 038H read-only MCP code intelligence catalog
Repo: EndeavorEverlasting/BlacksmithGuild
Branch: sprint/038h-readonly-code-intelligence-catalog
Lane: local agent/code-intelligence
Scope: deterministic read-only catalog tools for repo navigation
Forbidden scope: gameplay mutation, runtime execution, launcher automation, command inbox writes, save access, ignored runtime evidence
Expected artifacts:
- docs/architecture/tbg-code-intelligence-catalog.md
- tooling/mcp or .tbg/mcp catalog files, following existing repo pattern
- tests validating read-only behavior

Dependency:
Works best after Chat 01. If MCP/LSP symbol navigation is unavailable, return planned/missing for symbol tools instead of failing or pretending.

Mission:
Create a read-only code intelligence layer that helps future agents find policy, contracts, services, hotkeys, and runtime seams without grep chaos.

Initial tools:
- find_runtime_seam
- find_hotkey_handler
- find_command_inbox_handler
- find_harness_contract
- find_policy_source
- find_route_owned_clock_code
- find_launcher_automation_code
- outline_csharp_service
- outline_powershell_harness_script

Rules:
- Read tracked docs/code/contracts only.
- Do not read ignored logs/saves/runtime evidence by default.
- Do not expose secrets.
- Do not execute Bannerlord.
- Do not write command inbox.
- Do not mutate targets.
- Do not call network tools.
- Results must be JSON-serializable.
- Symbol-backed tools must report missing_prereqs when LSP is not loaded.

Validation:
- Run focused code-intelligence tests.
- Run MCP readiness if available.
- Run harness validator if available.
- git diff --check
- git status --short

Final response:
- PR branch name
- Tool list
- Query examples
- Tests run
- Missing dependency behavior
- Gaps/risks
- PR URL if opened
```

## Chat 08 — Local Hook and Artifact Hygiene

```text
TBG CHAT 08
Sprint: 038I local hook and artifact hygiene
Repo: EndeavorEverlasting/BlacksmithGuild
Branch: sprint/038i-hook-artifact-hygiene
Lane: repo hygiene / safety rails
Scope: prevent generated runtime evidence, logs, saves, and local tool installs from leaking into commits
Forbidden scope: gameplay changes, runtime execution, launcher automation, MCP implementation, broad hard blockers that slow normal code/docs work
Expected artifacts:
- docs/handoff/038i-hook-artifact-hygiene.md
- docs/LOCAL_HOOKS_OPERATOR_GUIDE.md or TBG equivalent
- updated hook scripts only if repo already has local hook pattern
- tests validating hook behavior

Mission:
Make TBG safer for parallel agent work by tightening local artifact hygiene without blocking normal development velocity.

Warn/block obvious generated/runtime paths:
- BlacksmithGuild_Phase1.log
- BlacksmithGuild_Launch.log
- BlacksmithGuild_Status.json
- BlacksmithGuild_MarketIntel.json
- BlacksmithGuild_ForgeRecommendations.json
- BlacksmithGuild_SmithingAudit.json
- BlacksmithGuild_SmithingAdvisory.json
- BlacksmithGuild_SmithingRefineProbe.json
- saved games
- Bannerlord runtime folders
- .local/mcp-tools
- artifacts timestamped runtime evidence unless explicitly intended and sanitized

Required behavior:
- Hooks remain local opt-in.
- Generated runtime evidence is blocked or warned clearly.
- Sanitized fixtures/docs remain commit-friendly.
- Hook output tells the operator what to do next.
- No sensitive excerpts printed.
- No broad blocking of normal docs/code changes.

Good error wording:
[tbg-harness] refusing staged runtime/generated artifact: <path>
Move live/generated evidence back to ignored local output, or commit a sanitized fixture under an approved fixture/docs path.

Safety:
- Do not delete files.
- Do not print sensitive log excerpts.
- Do not inspect huge files deeply by default.
- Do not call network commands.
- Do not run Bannerlord.
- Do not make hooks mandatory globally.

Validation:
- Run focused hook/artifact hygiene tests.
- Run harness validator if available.
- git diff --check
- git status --short

Final response:
- PR branch name
- Hook behavior before/after
- Files changed
- Tests run
- Safety proof
- False-positive notes
- PR URL if opened
```

## Standard Final Response Template for Every TBG Sprint

````text
[TBG | Sprint <ID> | <Name> | branch: <branch>]

Repo:
Branch:
PR/Sprint:
Lane:
Scope:
Forbidden scope:

Completed Work
- ...

Validation Output
- ...

Generated Artifacts
- ...

Known Gaps/Risks
- ...

Changed Files
- ...

Git Status
```text
<paste git status --short / branch summary>
```

Skipped Checks
- ...

Exact Next Command
```powershell
<one command>
```

Next-Agent Handoff Prompt
```text
<copy-paste prompt for the next chat, only if useful>
```

PR URL:
````

## Immediate move

Launch Chat 00 first.

Then launch these in parallel only after Chat 00 confirms safe bases:

```text
Chat 01 — MCP/LSP Symbol Smoke Recovery
Chat 02 — Run Context + Artifact Registry
Chat 08 — Hook and Artifact Hygiene
```

Hold these until the floor settles:

```text
Chat 03 waits for Chat 02.
Chat 04 waits for Chat 01/02/03.
Chat 05 waits for Chat 00, but can run before Chat 04 if urgent.
Chat 06 waits for Chat 00 and ideally Chat 05.
Chat 07 waits for Chat 01, or runs with missing-prereq behavior.
```
