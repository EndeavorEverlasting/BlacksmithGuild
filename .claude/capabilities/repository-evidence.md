# Capability: Repository Evidence

## Purpose

Recover Git, branch, worktree, PR, plan, and validator truth before selecting or mutating a sprint.

## Rules

- Run compact Git preflight before mutation.
- Preserve dirty or conflicted work; isolate unrelated work in a separate worktree.
- Prefer current code and reachable commits over stale handoff prose.
- Inspect open PRs and recent changed files for collision ownership.
- Record exact commands, SHAs, branches, paths, and unavailable tools.
- Do not use filenames or timestamps alone as proof of freshness.
- Do not clean, reset, rebase, delete, or force-push unknown work.
