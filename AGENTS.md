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

## Local worktree rule

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

The protected local runtime checkout is:

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
```

Known sibling worktrees include:

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr23
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr25-launcher-evidence
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr27-duration-guard
```

Do not branch-switch the protected checkout for unrelated PR work. Use a sibling `BlacksmithGuild-prNN-short-name` worktree instead.

Full doctrine:

```text
docs/architecture/local-worktree-sprint-contract.md
.tbg/worktrees/local-sprint-worktrees.contract.json
```

## Runtime stop rule

If commands assume Bannerlord should not be running, stop the game first.

Default stop step from repo root:

```powershell
$env:FORGE_NO_PAUSE = '1'
.\ForgeStop.cmd soft
```

This is required before build/install/launch/live-cert/full runtime validation unless the workflow itself owns and documents the stop phase.

When uncertain, run:

```powershell
.\scripts\tbg\Assert-TbgRuntimeStopPolicy.ps1 -Operation live-cert
```

Full doctrine:

```text
docs/handoff/runtime-stop-guardrails.md
.tbg/workflows/runtime-stop-policy.contract.json
scripts/tbg/Assert-TbgRuntimeStopPolicy.ps1
```

## Campaign activity ledger rule

Agents must not leave behavioral planning concepts in chat only.

The repo-owned doctrine is:

```text
docs/architecture/campaign-activity-ledger.md
.tbg/workflows/campaign-activity-ledger.contract.json
.tbg/plans/campaign-activity-ledger-sprint/README.md
```

The intended system records meaningful player and automation events, compares proposed plans against what the user does next, writes compact bounded runtime state, and produces English reports plus feature signals when repeated divergence shows the planner is annoying or wrong.

Do not ask the user to translate raw activity logs if an English report can be produced.

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
- Local worktree isolation must follow `docs/architecture/local-worktree-sprint-contract.md`.
- Runtime stop decisions must follow `docs/handoff/runtime-stop-guardrails.md`.
- Campaign activity and plan feedback doctrine must follow `docs/architecture/campaign-activity-ledger.md`.
- Synthesize parallel reports by preserving each agent's factual findings, resolving ownership conflicts through the routing matrix, and escalating only true contradictions to the user.
