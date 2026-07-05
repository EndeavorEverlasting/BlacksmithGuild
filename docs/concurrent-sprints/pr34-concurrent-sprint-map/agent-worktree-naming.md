# Agent Worktree Naming Guide

## Purpose

Concurrent sprints need predictable local directory names so the operator and agents can tell which branch and PR they are touching.

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

## PR34 local worktree

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr34-concurrent-sprint-map
```

## Worktree creation command

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord"
git -C ".\BlacksmithGuild" fetch origin
git worktree add ".\BlacksmithGuild-pr34-concurrent-sprint-map" origin/docs-concurrent-sprint-map
Set-Location ".\BlacksmithGuild-pr34-concurrent-sprint-map"
git switch docs-concurrent-sprint-map
```

If the checkout is detached, use:

```powershell
git switch -c docs-concurrent-sprint-map --track origin/docs-concurrent-sprint-map
```

## Before making changes

Always run:

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
