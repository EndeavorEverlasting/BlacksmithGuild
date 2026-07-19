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

A lower authority may explain a higher authority but may not override it. Canonical execution doctrine: [`docs/harness-doctrine.md`](docs/harness-doctrine.md), enforced by `.tbg/harness/policies/harness-doctrine.policy.json` and `scripts/tbg/Test-TbgHarnessDoctrine.ps1`.

## Entry sequence

Before substantial work:

1. identify repo, branch or worktree, PR or sprint, lane, owned scope, forbidden scope, expected artifacts, and any user-specified validation order;
2. inspect `git status --short`, `git branch --show-current`, and `git log --oneline --decorate -5`;
3. use `CODEBASE_MAP.md` to load the smallest relevant product, harness, runtime, or evidence surface;
4. read `.tbg/skills/manifest.json` and select one primary skill plus only required cross-cutting skills;
5. load the skill's `entryContract`, authorities, validators, expected artifacts, and proof ceiling;
6. use `artifacts/latest/tbg-chat-packet.json`, `artifacts/latest/tbg-sprint-capsule.json`, or the artifact-engine handoff for fresh local state when present;
7. when a request claims install, set up, build, execute, repair, configure, upgrade, deploy, merge, or release, require the corresponding mutation and proof; a plan-only closeout is invalid unless an exact blocker prevents safe work.
Do not paste full stale handoffs into every prompt. Do not load every skill.

## Universal safety

- Preserve dirty, conflicted, unpublished, ignored-evidence, and sibling-worktree state unless the active cleanup workflow proves a destructive action safe.
- Do not use reset, clean, force push, branch deletion, worktree removal, save mutation, or PR closure merely to make the floor look clean.
- Do not commit secrets, saves, personal configuration, scratch evidence, huge logs, crash dumps, or machine-local junk.
- Do not ask the user to harvest logs manually when the runner can capture them. Runner-owned workflows own evidence capture.
- No game launch, launcher click, command-inbox write, save mutation, or gameplay action is allowed unless the active workflow explicitly grants that authority.
- A trigger, available tool, external coordinator, or prompt may route work, but it does not grant destructive, runtime, deployment, merge, secret, or live-target authority.
- Checkpoint coherent tracked progress before broad validation, long diagnostics, runtime proof, refactoring expansion, or switching agents, models, worktrees, or environments. Include owned untracked files; a checkpoint proves preservation only.
- Before launch, stop, build, install, or cleanup, classify existing Bannerlord processes through `.tbg/workflows/runtime-context-continuity.contract.json`; process presence is context, not zombie proof, and an active human, foreign, or ambiguous session must not be terminated.
- ForgeContinue, Auto Launch Nav, new-game, Steam-mediated, and future launch paths must use the same observer-first run context for Play/Continue, calibration, Safe Mode, Caution, Steam broker, other launcher windows, and game handoff; exact PID/HWND preferred; unique process name or S1/S2 delta allowed; every correlated surface is recorded, each action target is identity-frozen, Steam and unknown windows remain observation-only, multitasking stays background-safe and mouse-independent by default, and fresh transition evidence is required before success.
- Raw runtime evidence stays ignored; cross-agent or remote diagnosis uses a sanitized bounded runtime-context capsule registered by that contract.
- For crash diagnosis, treat the last marker as a boundary rather than a cause; require correlated pre-state, post-state or process-loss, expected, observed, and valid absent signals, plus external evidence before confirming a native crash.
- External tools, AgentSwitchboard, SysAdminSuite, and Continuum may coordinate or accelerate work, but BlacksmithGuild retains proof, policy, runtime, save-safety, and product authority.

## Proof and execution discipline

Proof levels do not collapse:

```text
contract -> harness -> static test -> build -> launcher -> command ACK -> behavior observed -> live runtime
```

Do not claim a higher level from a lower one. A stale `Status.json`, parser success, command ACK, route assignment, checkpoint, or launcher handoff is not product completion. Every claim must name freshness, exact head when relevant, evidence paths, and the highest level actually reached.

Incomplete proof is not automatically an execution prohibition. Prefer the strongest bounded workflow whose authority and safety boundary match the operator's request. Use `.tbg/workflows/end-to-end-validation.contract.json` for composed proof, `.tbg/workflows/checkpoint-discipline.contract.json` for recoverable expansion, and `.tbg/workflows/tbg-sprint-capsule.contract.json` for machine-readable continuation.

## Lane router

| Request or touched surface | Primary skill |
|---|---|
| harness doctrine, placement, E2E profiles, sprint capsules, consumer handoffs | `harness-maturity` |
| branches, PRs, worktrees, conflicts, safe bases | `repo-floor-hygiene` |
| root rules, manifests, prompts, skill design, refactoring plans | `agent-skill-factoring` |
| local artifact parsing, watcher, toggle, cascade | `local-artifact-engine` |
| proof, freshness, loaded identity, claim discipline | `runtime-evidence-certification` |
| crash, process loss, hang, external terminal evidence, incident reconstruction | `runtime-incident-triage` |
| ForgeStop, build/deploy/launch/Continue | `launcher-lifecycle` |
| window lifecycle reduce/replay/quarantine | `window-lifecycle-runtime` |
| campaign readiness, movement, arrival, buy/sell deltas | `route-visible-trade` |
| hotkeys, toggles, command inbox, Manual/Assist/Autonomous | `operator-control-surface` |
| commit, push, PR, concurrent completion, release gates | `implementation-completion` |
| stale or stacked PR value recovery | `stale-pr-cherry-pick` |
| Continuum capability export or extraction | `continuum-interoperability` |
| long annotations, stale snapshots, retained insight | `compendium-preservation` |
| external coordinators and agent-operation tools | `agentic-operations` |
| WezTerm, tmux, Neovim, voice-input ergonomics | `operator-terminal-environment` |

Agent A/B/C/D names are compatibility aliases only. Route by lane and skill. Map: A=Cert/Evidence/Git/PR; B=Runtime/Readiness; C=Launcher/lifecycle/window; D=Docs/atlas. Living boards: [`docs/handoff/blacksmithguild-agent-coordination.md`](docs/handoff/blacksmithguild-agent-coordination.md), [`docs/handoff/runtime-state-routing.md`](docs/handoff/runtime-state-routing.md). Runner owns evidence capture.

## Current-state pointers

Mutable PR restrictions, active targets, worktree state, runtime state, and latest evidence do not belong in this file. Resolve them from:

- `artifacts/latest/tbg-chat-packet.json`;
- `artifacts/latest/tbg-sprint-capsule.json`;
- `artifacts/latest/artifact-engine/artifact-engine.handoff.md`;
- `docs/control/logs/open/autonomous-assist-session-target.md`;
- `docs/handoff/blacksmithguild-agent-coordination.md`;
- `docs/handoff/runtime-state-routing.md`;
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

Serious repo work must name completed work, files changed, artifacts, validation, skipped checks, blockers, risks, important paths, Git/PR state, and one exact next command. Interrupted or resumed work must also name the checkpoint SHA or artifact, preserved and excluded files, last completed validation, first pending validation, and exact resume command. Use a schema-backed sprint capsule for cross-agent or cross-repository continuation; do not claim completion without a commit SHA, validated existing proof, or an exact blocker.
