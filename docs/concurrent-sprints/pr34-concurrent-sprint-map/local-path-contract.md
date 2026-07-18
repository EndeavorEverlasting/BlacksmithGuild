# Local Path Contract

## Purpose

This repo has concurrent sprint lanes. Local paths must make that visible before any agent tells the operator where to run commands.

The plain repo folder is not a scratch checkout. It is the operator's local main checkout.

## Abstract local layout

Use these abstract roles instead of treating a folder name as disposable:

```text
<bannerlord-mods-parent>
  BlacksmithGuild\                         protected local main checkout
  BlacksmithGuild-prNN-short-description\  PR-specific worktree checkout
```

Current operator parent:

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord
```

Protected local main checkout:

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
```

PR worktrees must be siblings of the protected local main checkout, not branch swaps inside it.

## Protected local main rule

Agents must not tell the operator to run `git checkout`, `git switch`, patch commands, verifier runs, or generated apply scripts inside:

```text
<bannerlord-mods-parent>\BlacksmithGuild
```

unless the work is explicitly on `main` and the operator has asked to use the primary checkout.

For PR or branch work, agents must use a PR-specific worktree path:

```text
<bannerlord-mods-parent>\BlacksmithGuild-prNN-short-description
```

## Worktree creation pattern

From the parent directory:

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord"
git -C ".\BlacksmithGuild" fetch origin
git -C ".\BlacksmithGuild" worktree add ".\BlacksmithGuild-pr31-agent-stop-hook" origin/agent-feedback-stop-hook
Set-Location ".\BlacksmithGuild-pr31-agent-stop-hook"
git switch agent-feedback-stop-hook
```

If the checkout is detached, use:

```powershell
git switch -c agent-feedback-stop-hook --track origin/agent-feedback-stop-hook
```

## Validation location rule

Validation commands belong in the PR-specific worktree for the PR being validated.

Example for PR #31:

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr31-agent-stop-hook
```

not:

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
```

## Agent report requirement

Whenever an agent provides copy-paste commands for branch or PR work, it must report:

```text
local path role
intended worktree path
branch
base branch
PR number
whether the protected local main checkout is being left untouched
```

## Forbidden shortcut

Do not collapse these two paths:

```text
BlacksmithGuild = protected local main checkout
BlacksmithGuild-prNN-short-description = sprint worktree
```

They are not interchangeable. Confusing them risks contaminating concurrent work.
