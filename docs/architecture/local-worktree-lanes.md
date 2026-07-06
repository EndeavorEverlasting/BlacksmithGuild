# Local Worktree Lane Discipline

## Purpose

The Blacksmith Guild uses multiple local working directories so concurrent sprints do not trample each other.

Each directory is a lane. A lane must have one owner, one branch or PR purpose, and one current product objective.

Agents must not treat these folders as interchangeable clones.

## Current local lane map

These paths are user-owned local worktrees on the Windows machine:

| Local path | Lane role | Expected branch or PR scope | Agent rule |
|---|---|---|---|
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild` | Active integration lane | Current local sprint branch, currently `feat/route-owned-clock-resume` | Route runtime owner may work here. Before commands that assume Bannerlord is stopped, stop it first. |
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr23` | Isolated PR lane | PR #23 or its recovery branch | Do not borrow files blindly. Inspect branch and status first. |
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr25-launcher-evidence` | Launcher evidence lane | PR #25 launcher/runtime proof work | Do not mix launcher evidence changes into route runtime unless explicitly merged through Git. |
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr27-duration-guard` | Duration guard lane | PR #27 duration guard work | Treat as independent guardrail work. Do not patch route runtime from this lane without an explicit merge/cherry-pick. |

## Lane ownership rule

Before editing, building, validating, or committing from any lane, the agent must identify:

```text
path=<absolute local repo path>
branch=<git branch>
objective=<current PR or sprint objective>
owner=<agent role>
```

If the branch does not match the lane role, stop and report the mismatch.

## Required lane preflight

Run this from the lane root before patching:

```powershell
Set-Location "<lane-root>"
git rev-parse --show-toplevel
git branch --show-current
git status --short --ignored
```

For runtime-affecting work, run the guardrail script before the operation:

```powershell
.\scripts\tbg\Assert-TbgRuntimeGuardrail.ps1 -Intent patch -StopGame
```

For pure documentation or static review, do not stop the game unless the next command builds, installs, launches, or validates live runtime behavior.

## Forbidden behavior

- Do not copy patches between lanes by memory.
- Do not assume `BlacksmithGuild` and `BlacksmithGuild-pr25-launcher-evidence` are on the same branch.
- Do not ask the user for giant collector logs before reading compact result artifacts.
- Do not issue a live-cert validation command without a stop-before-runtime guardrail.
- Do not close stale PRs without user approval.

## Merge discipline

A lane can contribute to another lane only through one of these explicit Git operations:

```powershell
git merge --no-ff <branch>
git cherry-pick <commit>
git diff <source> -- <paths>
```

If an agent cannot name the source branch, target branch, and affected files, it is not ready to merge.

## Route sprint default

For the route-visible-start sprint, the active lane is:

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
```

The active branch is:

```text
feat/route-owned-clock-resume
```

The current objective is:

```text
Visible route start under mod control, proven by artifacts/latest/route-visible-start.result.json and BlacksmithGuild_MapTradeRouteCert.json.
```
