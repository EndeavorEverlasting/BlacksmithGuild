# TBG Agent B Prompt - Repo Floor and Hygiene Coordinator

## Context banner

```text
Agent: Agent B
Lane: coordinator / cleanup / sprint map
Repo: C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
Secondary validation worktree: C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-037a-validation
Sprint: Repo / PR / worktree hygiene and sprint map
Primary feature owner: Agent A handles route runtime conflict resolution
Codex 037B owner: MCP/LSP symbol smoke harness in validation worktree
```

## Scope

Verify and report:

```text
repo path
current branch
open PRs
dirty/conflicted state
worktrees
whether primary worktree is safe for work
whether sibling worktrees are required
safe base branches for next sprints
stale generated artifacts
local branches that are already merged
PR stack map
next exact commands
```

## Forbidden scope

```text
Do not implement feature work.
Do not resolve the route conflict unless explicitly asked.
Do not run Bannerlord.
Do not make runtime claims.
Do not touch src/BlacksmithGuild/MapTrade/*.
Do not close PRs.
Do not delete branches without proof.
Do not delete evidence artifacts unless they are obvious temp files and the user approves.
Do not mutate the Codex 037B branch.
Do not stage or commit source changes unless the user explicitly asks.
```

## Start in primary repo

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild"
$ErrorActionPreference = "Stop"

Write-Host "== PRIMARY REPO CONTEXT =="
git fetch origin
git rev-parse --show-toplevel
git branch --show-current
git status --short
git log --oneline --decorate -8
git worktree list

Write-Host "== UNMERGED FILES =="
git diff --name-only --diff-filter=U

Write-Host "== OPEN PRS =="
gh pr list --state open --limit 30
```

## Inspect Codex 037B validation worktree

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-037a-validation"
$ErrorActionPreference = "Stop"

Write-Host "== 037B VALIDATION WORKTREE CONTEXT =="
git fetch origin
git rev-parse --show-toplevel
git branch --show-current
git status --short
git log --oneline --decorate -8
git worktree list
```

## Classification rules

### Primary worktree

If primary repo shows:

```text
UU src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs
```

classify primary as:

```text
unsafe for new feature work
route conflict resolution only
```

Do not resolve it.

### Codex 037B worktree

If branch is:

```text
sprint/037b-mcp-symbol-smoke
```

and status shows modified files from the MCP/LSP symbol smoke sprint, classify it as:

```text
safe isolated harness lane
needs commit/push/PR after validation
```

Do not alter it.

### PR map

Classify open PRs into:

```text
active stack
parallel active
stale/superseded candidate
needs approval before close
```

Expected active/parallel PRs:

```text
#36 docs(agent): add route workflow contracts
#37 feat(route): start branch-selected travel from campaign tick
#38 docs(guardrails): codify worktree and runtime stop contracts
#39 feat(harness): add local agent and AI layer foundation
```

Older PRs to classify only, not close:

```text
#6
#8
#9
#20
#24
#28
#29
#30
#31
#32
#33
#34
#35
```

## Safe cleanup rules

You may recommend cleanup for:

```text
already-merged local branches
local temp branches with no unique commits
untracked editor temp files
obvious generated clutter
```

Do not delete anything until proof is shown and the user approves.

Proof required before branch deletion:

```powershell
git branch --merged
git log --oneline <branch> --not main --max-count=20
```

Proof required before deleting untracked clutter:

```powershell
git status --short --ignored
Get-ChildItem <candidate-path> -Force
```

## Final response format

Return exactly:

```text
[TBG | Agent B | Repo Floor Hygiene Coordinator]

Repo:
- primary:
- validation worktree:

Branch:
- primary:
- validation:

PR/sprint context:
- Agent A route lane:
- Codex 037B MCP/LSP lane:
- PR janitor lane:

Scope:
- completed inspection only / cleanup recommendations only

Forbidden scope honored:
- no feature implementation
- no runtime validation
- no branch deletion
- no PR closure

Work completed:
- <commands run and findings>

PR map:
- active:
- parallel:
- stale/superseded candidates:
- needs approval:

Worktree map:
- path:
- branch:
- state:
- safe/unsafe:
- recommended owner:

Changed files:
- primary tracked changes:
- primary conflicts:
- validation tracked changes:
- ignored/generated clutter summary:

Validation output:
- git status:
- worktree list:
- gh pr list:

Gaps/risks:
- <exact risks>

Exact next command:
- <one exact command for Agent A or Codex 037B>

Copy-paste handoff prompt for next sprint:
- <prompt>
```

## Generic next implementation sprint prompt

```text
You are continuing a targeted implementation sprint.

Repo:
xyz_repo_or_path

Sprint:
xyz_sprint_name

Branch:
xyz_branch

Lane:
xyz_lane

Owned scope:
xyz_owned_scope

Forbidden scope:
xyz_forbidden_scope

Expected artifacts:
xyz_expected_artifacts

Context or plan path:
xyz_plan_directory

If the plan path is missing, stale, blank, or a placeholder, do not stall. Inspect repo state, recent commits, handoff docs, plans, validators, tests, logs, and artifacts. Proceed from the clearest current context.

Start by naming:
- repo
- branch
- head
- sprint/lane
- scope
- forbidden scope
- expected artifacts

Before inventing, search existing contracts, helpers, validators, scripts, docs, naming conventions, output paths, and test patterns.

Execute the smallest serious sprint that advances the goal. Do not stop at trivial checks if useful implementation is clear.

Rules:
- reuse repo patterns
- keep changes bounded
- avoid unrelated rewrites
- do not turn real behavior into stubs just to pass tests
- do not ask for permission when the work is scoped and safe
- do not leave useful changes local-only when commit/push is expected
- do not commit secrets, personal data, live runtime evidence, huge logs, crash dumps, or machine-local junk

Validate using repo conventions:
1. targeted tests for changed behavior
2. relevant validators or static checks
3. build checks
4. broader checks when practical

Final handoff must include:
- context
- work done
- files changed
- artifacts produced
- validation commands and results
- skipped checks with reasons
- gaps, risks, and target files
- important paths
- git/PR state
- exact next command
- copy-paste prompt for the next agent

Do the work. Avoid permission theater. Validate. Clean up. Hand off.
```
