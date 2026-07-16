# Agent Instructions for The Blacksmith Guild

`AGENTS.md` is the compact, agent-agnostic entrypoint. It contains universal invariants and routing only. Detailed workflows live under `.claude/skills/`; reusable rules live under `.claude/capabilities/`.

## Required loading sequence

1. Read this file.
2. Use `CODEBASE_MAP.md` to locate the smallest relevant product, launcher, evidence, or harness surface.
3. Use `harness/api/agent-routing-manifest.json` for deterministic task routing. Unknown, ambiguous, or conflicting signals fail closed to the repository-sprint skill.
4. Load only the selected skill and its declared capability dependencies.
5. For a harness operation, collect its declared required inputs before invoking the repo-owned entrypoint.
6. Read deeper product plans, live-cert records, or historical handoffs only when the selected workflow requires them.

Triggers route work only. They never authorize game launch, save mutation, command-inbox writes, process termination, install/copy actions, Git history rewriting, or elevated proof claims.

## Universal invariants

- Treat the repository, current Git state, and current runtime artifacts as the source of truth over remembered chat context.
- Preserve existing work. Inspect dirty files, worktrees, branches, and open PRs before switching, restoring, cleaning, rebasing, or deleting.
- State repository, branch/PR, sprint, lane, owned scope, forbidden scope, dependencies, expected artifacts, and proof ceiling before mutation.
- Reuse Forge, Launch Control, command-bus, status, certification, evidence, and validator contracts before inventing parallel mechanisms.
- End-to-end proof is the default merge target for executable, launcher, command-bus, persistence, or integration changes. Unit and contract tests are diagnostics, not runtime proof.
- Static checks, build proof, install proof, launcher/session attach, command ACK, observed behavior, save-safe mutation, and live runtime certification are distinct proof levels.
- Never use a personal or legacy save for mutation proof. Tier-3 mutation requires an explicitly disposable campaign and the repository's save-safety doctrine.
- Stop Bannerlord before DLL install or runtime-replacement work unless the selected workflow explicitly owns a read-only observation lane.
- Do not rely on terminal or game-window focus when a repo-owned command inbox, ACK, status, or log surface exists.
- Bound every wait, retry, polling loop, child process, and runtime observation window.
- Never commit credentials, personal save data, machine-local paths, raw runtime JSON, unredacted logs, binaries, generated diagnostics, or local game files.
- Runtime evidence stays under approved ignored roots. Only sanitized manifests, tails, fixtures, or explicitly reviewed evidence snapshots may be tracked.
- A process exit code, visible window, log line, or command issue is insufficient when a stronger repo-owned ACK or behavior artifact exists.
- A receiving agent must re-inspect Git and runtime state. Machine-readable handoffs compress evidence; they do not transfer authority.

## Skill router

| Task signal | Load this skill |
|---|---|
| Repository intake, sprint selection, interrupted work, Git/worktree/PR lifecycle | [Repository Sprint](.claude/skills/repository-sprint/SKILL.md) |
| Contracts, schemas, validators, build gates, or bounded checks | [Scoped Validation](.claude/skills/scoped-validation/SKILL.md) |
| Composed journeys, merge/release gates, or harness verification | [End-to-End Validation](.claude/skills/end-to-end-validation/SKILL.md) |
| Bannerlord launch, command inbox, ACK, status, behavior, route cert, or live certification | [Bannerlord Runtime Proof](.claude/skills/bannerlord-runtime-proof/SKILL.md) |

Load multiple skills only when the task genuinely crosses lanes.

## Source-of-truth precedence

1. Explicit user scope and safety constraints.
2. This file's universal invariants.
3. The selected skill.
4. Capability dependencies declared by that skill.
5. Canonical machine-readable manifests, schemas, workflows, and artifact registries.
6. Current product code, launcher code, and validation entrypoints.
7. Current operational docs and certification doctrine.
8. Historical plans, handoffs, PR prose, screenshots, and chat memory.

When same-level authorities conflict, stop expansion, cite both paths, and make the smallest correction that restores one authority.

## Canonical authorities

- `CODEBASE_MAP.md` — minimal-context routing.
- `docs/AI_HARNESS_ENTRYPOINT.md` — fresh-agent inspection and execution sequence.
- `docs/END_TO_END_TESTING_POSTURE.md` — proof ladder and E2E defaults.
- `docs/MACHINE_READABLE_HANDOFF.md` — AgentSwitchboard and SysAdminSuite handoff boundary.
- `harness/api/tbg-harness-api.json` — supported harness operations.
- `harness/api/agent-capability-manifest.json` — skill/capability dependency graph.
- `harness/api/agent-routing-manifest.json` — deterministic trigger routing.
- `harness/api/artifact-types.json` — closed artifact role registry.
- `harness/e2e/e2e-profiles.json` — safe journey catalog.
- `harness/workflows/tbg-sprint-capsule.yaml` — final handoff compression workflow.
- `scripts/Test-TbgAiHarness.ps1` — PowerShell harness validator.
- `scripts/Invoke-TbgHarnessE2E.ps1` — one-command safe E2E entrypoint.
- `scripts/New-TbgSprintCapsule.ps1` — schema-backed handoff generator.

## Delivery floor

Before reporting completion:

1. Review `git diff --check`, `git status --short`, `git diff --stat`, and the final diff when locally available.
2. Run targeted validators, then the applicable E2E profile, then broader checks.
3. Report exact passes, failures, and skips.
4. Report files, commit SHA, push/PR state, remaining gaps, proof level, proof ceiling, and one exact next command.
5. Generate a sprint capsule when another agent, AgentSwitchboard lane, SysAdminSuite tandem lane, or later chat must continue.

A clean commit and green static contract do not automatically prove the game launched, a command was acknowledged, behavior changed, or a save-safe live runtime journey passed.
