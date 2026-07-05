# PR34 Concurrent Sprint Map

## Purpose

This directory exists so concurrent work has a stable home while other PRs are being validated or closed.

The goal is not to hide work in conversation history. The goal is to make active lanes visible inside the repo so agents can see what is in flight, what branch it belongs to, and what must not be crossed.

## Directory identity

```text
PR: 34
Title: docs(concurrent): add PR-numbered sprint map
Directory: docs/concurrent-sprints/pr34-concurrent-sprint-map/
Branch: docs-concurrent-sprint-map
Base: agent-default-guardrail-implementation
```

## Why this exists

The repo currently has multiple concurrent lanes:

```text
agent feedback harness and guardrail stack
launcher / route-owned clock / runtime proof stack
governor / campaign handoff stack
route/profile command contracts
economic-loop and sell-loop historical branches
```

Without a repo-visible lane map, agents can accidentally mix proof claims, validation commands, or branch targets from one lane into another.

## Core rule

Every concurrent sprint should name:

```text
base branch
head branch
PR number
directory
scope
non-goals
validation commands
blocked dependencies
handoff target
```

## What this sprint adds

This sprint adds coordination documents only:

```text
README.md
lane-map.md
active-pr-stack.md
agent-worktree-naming.md
```

It does not implement runtime behavior.

## Boundary

This directory is documentation and coordination.

It must not claim:

```text
runtime proof
live automation success
campaign action completion
movement proof
merge readiness
```

It may claim:

```text
concurrent lanes are mapped
branch dependencies are visible
agents have a stable place to look before starting side work
```
