# Blacksmith Guild Agent Coordination Contract

`AGENTS.md` is the safe bootloader for every Codex, Claude, Cursor, ChatGPT, and parallel-agent session in `EndeavorEverlasting/BlacksmithGuild`. Keep conditional lane knowledge in `.tbg/skills/**`; keep executable sequence and done gates in `.tbg/workflows/**`.

## Authority chain

When instructions overlap, use this order:

1. current source, scripts, schemas, registries, and executable workflow contracts;
2. current generated evidence and state packets;
3. the narrowest matching `.tbg/skills/<skill-id>/SKILL.md`;
4. this root coordination contract;
5. client adapters such as `CLAUDE.md`;
6. historical docs, stale PR bodies, and chat handoffs.

A lower authority may explain a higher authority but may not override it.

## Entry sequence

Before substantial work:

1. identify repo, branch, PR or sprint, lane, owned scope, forbidden scope, and expected artifacts;
2. inspect `git status --short`, `git branch --show-current`, and `git log --oneline --decorate -5`;
3. use `CODEBASE_MAP.md` to load the smallest relevant product, harness, runtime, or evidence surface;
4. read `.tbg/skills/manifest.json` and select one primary skill plus only required cross-cutting skills;
5. load the skill's `entryContract`, authorities, validators, expected artifacts, and proof ceiling;
6. use `artifacts/latest/tbg-chat-packet.json`, `artifacts/latest/tbg-sprint-capsule.json`, or the artifact-engine handoff for fresh local state when present.

Do not paste full stale handoffs into every prompt. Do not load every skill.

## Universal safety

- Preserve dirty, conflicted, unpublished, ignored-evidence, and sibling-worktree state unless the active cleanup workflow proves a destructive action safe.
- Do not use reset, clean, force push, branch deletion, worktree removal, save mutation, or PR closure merely to make the floor look clean.
- Do not commit secrets, saves, personal configuration, scratch evidence, huge logs, crash dumps, or machine-local junk.
- Do not ask the user to harvest logs manually when the runner can capture them. Runner-owned workflows own evidence capture.
- No game launch, launcher click, command-inbox write, save mutation, or gameplay action is allowed unless the active workflow explicitly grants that authority.
- If a command assumes Bannerlord should not be running, use the repo's ForgeStop path first.
- External tools, AgentSwitchboard, SysAdminSuite, and Continuum may coordinate or accelerate work, but BlacksmithGuild retains proof, policy, runtime, save-safety, and product authority.

## Proof and execution discipline

Proof levels do not collapse:

```text
contract -> harness -> static test -> build -> launcher -> command ACK -> behavior observed -> live runtime
```

Do not claim a higher level from a lower one. A stale `Status.json`, parser success, command ACK, route assignment, checkpoint, or launcher handoff is not product completion. Every claim must name freshness, exact head when relevant, evidence paths, and the highest level actually reached.

Incomplete proof is not automatically an execution prohibition. Prefer the strongest bounded workflow whose authority and safety boundary match the operator's request. Use `.tbg/workflows/end-to-end-validation.contract.json` for composed proof and `.tbg/workflows/tbg-sprint-capsule.contract.json` for machine-readable continuation.

## Lane router

| Request or touched surface | Primary skill |
|---|---|
| branches, PRs, worktrees, conflicts, safe bases | `repo-floor-hygiene` |
| root rules, manifests, prompts, skill design | `agent-skill-factoring` |
| harness placement, E2E profiles, sprint capsules, consumer handoffs | `harness-maturity` |
| local artifact parsing, watcher, toggle, cascade | `local-artifact-engine` |
| proof, freshness, loaded identity, claim discipline | `runtime-evidence-certification` |
| ForgeStop, build/deploy/launch/Continue/window lifecycle | `launcher-lifecycle` |
| campaign readiness, movement, arrival, buy/sell deltas | `route-visible-trade` |
| hotkeys, toggles, command inbox, Manual/Assist/Autonomous | `operator-control-surface` |
| commit, push, PR, concurrent completion, release gates | `implementation-completion` |
| stale or stacked PR value recovery | `stale-pr-cherry-pick` |
| Continuum capability export or extraction | `continuum-interoperability` |
| long annotations, stale snapshots, retained insight | `compendium-preservation` |
| external coordinators and agent-operation tools | `agentic-operations` |
| WezTerm, tmux, Neovim, voice-input ergonomics | `operator-terminal-environment` |

Agent A/B/C/D names are compatibility aliases only. Route by lane and skill, not by a temporary agent letter.

## Current-state pointers

Mutable PR restrictions, active targets, worktree state, runtime state, and latest evidence do not belong in this file. Resolve them from:

- `artifacts/latest/tbg-chat-packet.json`;
- `artifacts/latest/tbg-sprint-capsule.json`;
- `artifacts/latest/artifact-engine/artifact-engine.handoff.md`;
- `docs/control/logs/open/autonomous-assist-session-target.md`;
- current Git, GitHub, workflow, and runtime artifacts.

Historical snapshots remain provenance, not current truth.

## PowerShell encoding

Every tracked `*.ps1`, `*.psm1`, and `*.psd1` file must carry a UTF-8 BOM. After script edits run:

```powershell
powershell -File scripts\tools\Add-Utf8Bom.ps1 -Fix
powershell -File scripts\test-powershell-utf8-bom-contract.ps1
```

PowerShell Core success alone is not Windows PowerShell 5.1 proof.

## Completion report

Serious repo work must name completed work, files changed, artifacts, validation, skipped checks, blockers, risks, important paths, Git/PR state, and one exact next command. Use a schema-backed sprint capsule for cross-agent or cross-repository continuation; do not claim completion without a commit SHA, validated existing proof, or an exact blocker.
