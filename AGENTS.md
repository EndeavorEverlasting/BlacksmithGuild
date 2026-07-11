# Blacksmith Guild Agent Coordination Contract

This file is the root coordination contract for Codex, Cursor, ChatGPT handoffs, and parallel sub-agents working in The Blacksmith Guild repository.

## Agent identities and ownership

- Agent A = Cert / Evidence / Git / PR judgment
- Agent B = Runtime / Readiness / Gameplay state truth
- Agent C = External runner / launcher / lifecycle / window classifier
- Agent D = Docs / atlas / routing board

## Hard routing rules

- Agent A does not write product code.
- Agent B does not edit launcher/runner scripts unless explicitly routed.
- Agent C does not edit src/** unless explicitly authorized.
- Agent D does not certify gameplay.
- Do not merge PR #8 unless user explicitly authorizes.
- Do not commit scratch evidence folders.
- Do not claim PASS from stale Status.json.
- Do not ask the user to harvest logs manually.
- Runner owns evidence capture.

## Common denominator vs skills

`AGENTS.md` is the common denominator. It should stay small enough for every agent to read at entry.

Put repo-wide facts here:
- agent ownership and routing rules;
- non-negotiable safety boundaries;
- proof and evidence discipline;
- encoding rules;
- where to find executable contracts and targeted skills.

Put conditional brush-up material in `.tbg/skills/<skill-id>/SKILL.md`, not in this file. A skill may explain a workflow, proof ladder, stale-PR recovery path, operator control surface, launcher lifecycle, or MCP/LSP search pattern, but it must point back to executable contracts, policies, manifests, scripts, or current docs as the authority.

If a skill disagrees with a workflow contract, harness policy, operator catalog, or current source file, the executable source wins and the skill must be corrected.

## Skill selection rule

Before substantial repo work, choose the narrowest matching skill from `.tbg/skills/manifest.json`.

Required default skills:
- `repo-floor-hygiene` for branch, PR, worktree, conflict, stale artifact, and safe-base mapping.
- `agent-skill-factoring` for changing agent rules, skill docs, manifests, or prompt surfaces.
- `harness-maturity` for deciding whether logic belongs in harness plumbing, a workflow contract, a registry, or narrow skill/domain code.
- `stale-pr-cherry-pick` for recovering value from stale or conflicted PRs without blind merge, blind squash, or blind deletion.

Do not load every skill. Load `AGENTS.md`, then only the active workflow contract and the skills that match the lane.

## Harness maturity rule

Harness maturity is not a raw line-count target. A thick harness is useful when it moves cross-cutting plumbing out of domain behavior: config loading, dependency injection, capability routing, permission gates, policy guards, evidence capture, retries, rollback, metrics, English/JSON reporting, UI shims, schemas, fixtures, and adapters.

Keep domain behavior narrow. Route, smithing, economy, trade, save identity, launcher lifecycle, and gameplay decisions should not be moved into harness merely to make the harness percentage look higher.

Use `.tbg/skills/harness-maturity/SKILL.md` and `.tbg/workflows/harness-skill-maturity.contract.json` before any refactor that claims to make the app more harness-driven. The acceptable reason is a real safety, replay, audit, rollback, reporting, or agent-context-load problem. Reject percentage chasing.

## Stale PR policy

A stale PR is not disposable merely because it is behind, conflicted, old, or superseded in part.

Default posture:
1. map it;
2. classify unique value;
3. preserve useful commits, hunks, tests, docs, and evidence references;
4. replay only the selected delta onto a safe current base;
5. validate under current contracts;
6. close or supersede the old PR only after the replacement path is recorded.

Do not use stale PR heads as general bases. Do not delete stale branches or worktrees without proof and explicit operator authorization.

## Current strategic target

One command should:

1. build/deploy if needed
2. launch Bannerlord
3. select Continue automatically
4. wait for campaign attach
5. consume stateMachine + RuntimeLifecycle
6. start autonomous assist loop without hotkey
7. make the avatar visibly move/train/act
8. log every step
9. allow user toggle-off
10. stop cleanly
11. write summary evidence

## PowerShell encoding (non-negotiable)

- **Every** tracked `*.ps1` / `*.psm1` / `*.psd1` must have a **UTF-8 BOM** (`EF BB BF`). PS 5.1 reads no-BOM files as ANSI; pwsh 7 reads them as UTF-8. Em dashes and other non-ASCII in no-BOM scripts are the usual visible break.
- After editing scripts: `powershell -File scripts\tools\Add-Utf8Bom.ps1 -Fix`, then `powershell -File scripts\test-powershell-utf8-bom-contract.ps1`.
- Full doctrine: `docs/conventions/powershell-utf8-bom-doctrine.md`. Do not assume pwsh-only green is repo green.

## Coordination doctrine

- Read `docs/handoff/blacksmithguild-agent-coordination.md` before changing owned files.
- Recursive campaign loop doctrine: `docs/handoff/recursive-campaign-assist-loop.md` (checkpoints are progress, not completion).
- Runtime truth and runner consumption must follow `docs/handoff/runtime-state-routing.md`.
- Window selection must follow `docs/control/logs/open/window-delta-doctrine.md`.
- The current user-facing product target is `docs/control/logs/open/autonomous-assist-session-target.md`.
- Synthesize parallel reports by preserving each agent's factual findings, resolving ownership conflicts through the routing matrix, and escalating only true contradictions to the user.
