# Local Worktree Sprint Contract

## Purpose

Concurrent Blacksmith Guild sprints must not share one checkout.

The local folder layout is part of the harness. It prevents agents from switching branches inside the protected main checkout, mixing PR evidence, or contaminating a runtime sprint while another branch is being reviewed.

## Known local layout

Current Bannerlord mod parent:

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord
```

Known sibling checkouts:

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr23
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr25-launcher-evidence
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr27-duration-guard
```

## Roles

| Path | Role |
|---|---|
| `BlacksmithGuild` | Protected local runtime sprint checkout. Do not casually branch-switch this folder. |
| `BlacksmithGuild-pr23` | PR-specific or branch-specific worktree/checkpoint lane. |
| `BlacksmithGuild-pr25-launcher-evidence` | PR-specific launcher/evidence lane. |
| `BlacksmithGuild-pr27-duration-guard` | PR-specific duration guard lane. |
| `BlacksmithGuild-prNN-short-name` | Required shape for future PR-specific sibling worktrees. |

## Required agent declaration

Before giving commands that touch git state, source files, build/install/runtime artifacts, or live validation, the agent must declare:

```text
Target PR:
Target branch:
Base branch:
Intended local path:
Local path role:
Protected BlacksmithGuild checkout untouched: yes/no
Concurrent route branch untouched: yes/no
Runtime/game stop needed: yes/no
Stop command if needed:
```

The agent must not give the command block until it can fill these fields.

## Protected checkout rule

The plain folder:

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
```

is not a generic scratchpad.

Do not run these there unless the sprint explicitly owns that branch:

```text
git switch <other-branch>
git checkout <other-branch>
git reset --hard
git clean -fdx
PR-specific generated patch scripts
PR-specific validation that writes source or runtime artifacts
```

## PR sibling worktree rule

For a PR-specific sprint, use a sibling directory:

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-prNN-short-name
```

Example:

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord"
git -C ".\BlacksmithGuild" fetch origin
git -C ".\BlacksmithGuild" worktree add ".\BlacksmithGuild-pr36-agent-workflow-contracts" origin/docs/agent-workflow-contracts
Set-Location ".\BlacksmithGuild-pr36-agent-workflow-contracts"
git status --short --ignored
git branch --show-current
git rev-parse --short HEAD
```

Using `git -C .\BlacksmithGuild` as an anchor is allowed. Switching branches inside `BlacksmithGuild` is not allowed unless that checkout is the intended sprint lane.

## Local runtime sprint exception

The local runtime sprint branch is currently:

```text
feat/route-owned-clock-resume
```

When the task is explicitly the route runtime sprint, the protected checkout may be the intended path, but the agent must say so and must not merge unrelated stale PRs without instruction.

## Evidence and artifact separation

Each sibling worktree owns its own generated evidence under that checkout. Do not copy evidence across sibling directories and call it fresh.

Fresh proof must be generated from the path, branch, and head SHA being claimed.

## Stop-before-runtime relation

Worktree separation prevents source conflicts. It does not stop the game.

Any command block that builds, installs, launches, runs a live cert, mutates Bannerlord runtime files, or assumes the game is not running must also follow the runtime stop guardrail documented in:

```text
docs/handoff/runtime-stop-guardrails.md
```
