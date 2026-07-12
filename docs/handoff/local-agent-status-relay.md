# Local Agent Status Relay

## Purpose

`ForgeAgentStatus.cmd` gives the operator one local command that produces a compact, paste-ready repo status packet for ChatGPT, Codex, or another agent.

This is a transport helper. It does not launch Bannerlord, run ForgeReboot, write command inbox files, mutate saves, delete branches, or clean worktrees.

## Commands

From the repo root:

```cmd
ForgeAgentStatus.cmd -PrNumber 43
```

The command writes:

```text
artifacts/latest/tbg-chat-packet.md
artifacts/latest/tbg-chat-packet.json
```

It also copies the Markdown packet to the clipboard unless `-NoClipboard` is passed.

To post the packet to the active PR through the GitHub CLI:

```cmd
ForgeAgentStatus.cmd -PrNumber 43 -PostPrComment
```

## What it captures

The packet includes:

```text
git rev-parse --show-toplevel
git branch --show-current
git log --oneline --decorate -8
git status --short
git status --short --ignored
git diff --name-only --diff-filter=U
git worktree list
git remote -v
gh pr list --state open --limit 20
gh pr view <number> --json number,title,state,isDraft,baseRefName,headRefName,mergeable,url,headRefOid
```

It also includes selected `artifacts/latest/*` files when present, capped to avoid giant paste dumps.

## Verdicts

The script emits a small operator verdict:

| Verdict | Meaning |
|---|---|
| `BLOCKED` | Unmerged files exist. Resolve or quarantine before feature work. |
| `ATTENTION` | The repo has changes but no merge conflict was detected. Inspect before proceeding. |
| `INFO` | No immediate conflict/dirty signal was detected by the packet script. |

This verdict is not a build or runtime proof. It is a repo-floor transport summary.

## Boundaries

This helper is safe to run during manual mode because it is read-only apart from writing ignored `artifacts/latest` packet files and optionally posting a PR comment.

It deliberately does not:

```text
launch Bannerlord
run ForgeReboot
write command inbox files
mutate saves
delete branches
delete artifacts
clean worktrees
claim runtime proof
```

## Typical manual-mode loop

1. Pull the branch containing this helper.
2. Run:

```cmd
ForgeAgentStatus.cmd -PrNumber 43
```

3. Paste the clipboard contents into the agent.

Optional GitHub relay:

```cmd
ForgeAgentStatus.cmd -PrNumber 43 -PostPrComment
```

Then the agent can read the PR comment instead of requiring a terminal dump.
