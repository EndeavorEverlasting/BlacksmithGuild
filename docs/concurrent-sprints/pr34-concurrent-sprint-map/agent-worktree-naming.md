# Agent Worktree Naming Guide

## Purpose

Concurrent sprints need predictable local directory names so the operator and agents can tell which branch and PR they are touching.

The plain `BlacksmithGuild` folder is the protected local main checkout. It is not a generic place to switch branches for PR work.

## Default naming pattern

Use:

```text
BlacksmithGuild-prNN-short-description
```

Examples:

```text
BlacksmithGuild-pr34-concurrent-sprint-map
BlacksmithGuild-pr33-default-guardrail-implementation
BlacksmithGuild-pr31-agent-stop-hook
BlacksmithGuild-pr25-launcher-evidence
```

## Recommended local parent

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord
```

## Protected checkout

This path is treated as local main unless the operator explicitly says otherwise:

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
```

Agents must not use that folder as the execution target for stacked PR work, side-lane validation, generated apply scripts, or branch switching.

## PR34 local worktree

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr34-concurrent-sprint-map
```

## Worktree creation command

Use `git worktree add` from the parent directory:

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord"
git -C ".\BlacksmithGuild" fetch origin
git -C ".\BlacksmithGuild" worktree add ".\BlacksmithGuild-pr34-concurrent-sprint-map" origin/docs-concurrent-sprint-map
Set-Location ".\BlacksmithGuild-pr34-concurrent-sprint-map"
git switch docs-concurrent-sprint-map
```

If the checkout is detached, use:

```powershell
git switch -c docs-concurrent-sprint-map --track origin/docs-concurrent-sprint-map
```

## Before making changes

Always run inside the PR worktree, not inside the protected local main checkout:

```powershell
git status --short
git branch --show-current
git rev-parse --short HEAD
```

## Lane rule

The worktree name should tell you:

```text
which PR
which lane
what kind of work
```

If the name cannot answer those questions, the worktree is too vague.

## Agent command rule

When giving copy-paste commands for PR work, agents must name the intended worktree path before validation commands.

Required report fields:

```text
local path role
intended worktree path
branch
base branch
PR number
protected local main checkout untouched: yes/no
```

If an agent cannot identify the intended worktree path, it should not provide destructive or branch-mutating commands.
