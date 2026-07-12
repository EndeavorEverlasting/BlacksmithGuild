# Compendium Preservation and Rewarding Sprint Map

```text
[TBG | Compendium Preservation + Rewarding Sprint | coordinator/architecture | branch: docs/agent-skills-stale-pr-cherry-pick]
```

## Purpose

This document preserves high-value repo, runtime, harness, and toolchain insights that came from long-form annotations, stale PR maps, and slightly stale snapshots.

The goal is not to freeze every old note as truth. The goal is to keep useful principles from being lost while forcing every future agent to verify freshness before implementation, closure, merge, branch deletion, or evidence cleanup.

## Source posture

Some inputs are current repository evidence. Some are operator annotations. Some are stale-but-useful snapshots. Treat each insight as one of these classes before acting:

| Class | Meaning | Action |
|---|---|---|
| `current_truth` | Verified against current source, PR state, workflow contract, validator, or fresh artifact. | May be used as current repo state. |
| `stale_but_useful_principle` | Old snapshot may be stale, but the design principle remains valuable. | Preserve, then revalidate before code changes. |
| `replay_candidate` | A stale PR, branch, hunk, test, script, or doc contains salvageable value. | Route through `stale-pr-cherry-pick`. |
| `needs_runtime_proof` | Cannot be proven statically. | Build or invoke an agent-verifiable local proof path. |
| `rejected_or_superseded` | Obsolete, unsafe, or already replaced. | Record rationale before cleanup. |

## Most rewarding sprint

The highest-leverage sprint is not another map. It is a closeout harness sprint that converts the accumulated insight into repo-owned, agent-verifiable operations.

```text
Sprint: Agentic Runtime Closeout Harness
Lane: harness/runtime-proof/PR-hygiene bridge
```

Success looks like:

1. `ForgeAgentStatus` or a future `tbg-axi` command produces compact local state and proof packets without the operator manually pasting long terminal dumps.
2. PR #43's route/operator-control lane has an exact-head unattended proof path instead of a human-only gate.
3. Stale PRs are classified and selectively replayed or closed with rationale.
4. Evidence bundles are archived with manifests before old worktrees or ignored artifacts are removed.
5. Worker engines share common cadence, proof, and handoff vocabulary so future route, trade, smithing, horse, companion, and caravan-escort work does not become engine-specific chaos.

## Current PR interpretation

| PR | Role | Current decision |
|---|---|---|
| #43 `agent/route-automation-operator-plan` | Active route/operator-control runtime lane. | Keep draft until exact-head runtime proof is collected by harness; do not leave human-only proof as the permanent gate. |
| #45 `docs/agent-skills-stale-pr-cherry-pick` | Agent rules, skill factoring, harness maturity, stale PR replay, and this compendium layer. | Merge after static checks; this becomes the doctrine bridge for future agents. |
| #46 `sprint/local-agent-status-relay` | Local evidence relay. | Already merged. Treat as the raw material for a future AXI-style TBG command. |
| #5-#38 stale legacy PRs | Mixed stale work, proof fragments, old runtime ideas, and harness concepts. | Do not blindly delete or squash. Classify, replay useful value onto current base, then close with rationale. |

## Why the relay matters

The local relay changes the operating model. The chat box should not be the transport layer for repo state.

Target direction:

```text
local repo state / validators / artifacts
        -> compact Markdown/JSON packet
        -> PR comment, clipboard, or artifact
        -> ChatGPT, Codex, Firstmate, or another agent reads the packet
```

The relay should evolve toward an AXI-style repo command with subcommands such as:

```text
status
prs
worktrees
packet
proof
next
```

Output rules:

- token-efficient by default;
- minimal fields first, full detail behind `--full`;
- definitive empty states;
- structured errors and exit codes;
- next-command suggestions;
- no huge raw JSON unless explicitly requested.

## Agentic operations layer

External tools should not be vendored into BlacksmithGuild. They belong above the repo as an agent operations layer.

| Tool | Layer | Adoption role | Boundary |
|---|---|---|---|
| Firstmate | External coordinator / crew manager | Dispatches agents into isolated lanes and consumes repo contracts, skills, and packets. | Do not turn BlacksmithGuild into Firstmate. |
| Treehouse | Worktree pool manager | Replaces manual sibling-worktree juggling with reusable isolated leases. | Do not delete evidence lanes without archive rationale. |
| No-mistakes | PR validation gate | Eventual gate for docs, skills, harness validators, static contracts, and CI path filters. | Runtime/gameplay proof needs adapted local stop/proof semantics first. |
| gnhf | Long-running autonomous loop | Useful for stale PR classification, docs cleanup, skill linting, and static validation. | Not for live Bannerlord runs unless strict stop conditions exist. |
| AXI | Agent-tool interface standard | Shapes future `ForgeAgentStatus` / `tbg-axi` output. | Keep output compact; do not dump giant artifacts by default. |
| Lavish | Visual review surface | Sprint maps, proof ladders, worker graphs, stale PR maps, and operator control diagrams. | Review surface, not runtime proof. |
| npx skills | Skill distribution | Compatibility target for `.tbg/skills`. | Internal repo skills must be marked if not public-installable. |
| WezTerm / tmux / Neovim / voice input | Operator environment | Improves terminal/editor/session/prompt throughput. | Do not make these repo dependencies without an install sprint. |

## Harness maturity principle

A higher harness ratio is useful only when it reduces risk, operator load, review load, replay cost, or context drift.

Move logic into harness when it is cross-cutting:

- config loading;
- dependency injection;
- capability routing;
- permission gates;
- evidence capture;
- retries and rollback;
- metrics and cadence accounting;
- English/JSON reporting;
- UI shims;
- schemas, adapters, and validators.

Keep logic in narrow skills or domain modules when it is:

- route scoring;
- market math;
- smithing advice;
- hostile vector calculation;
- save identity interpretation;
- economy rules;
- bounded validators tied to one behavior.

Do not move game behavior into generic plumbing just to make the repo look more harness-heavy.

## Engine cadence and performance doctrine

The repo should not depend on guessing TaleWorlds' hidden market refresh schedule to avoid waste.

Enforce these rules instead:

1. No expensive market or worker scan should run on every campaign tick.
2. Every recurring worker should use a shared cadence vocabulary: attempted, executed, throttled, skipped, stale, refreshed, and invalidated.
3. Market intelligence must record cache age, scan breadth, scan cost, and invalidation reason.
4. Safety polling can be more responsive than market scanning, but it still needs bounded cadence and cheap snapshots.
5. Growing ledgers and runtime logs should be archived or rotated so stale data remains available for analysis without dragging runtime performance.
6. Runtime packets should expose freshness and cost so agents can reason about performance without reading giant logs.

## Hostile-vector and future caravan escort doctrine

Hostile-party safety should be shared geometry, not MapTrade-specific folklore.

A future-safe design should:

- gather nearby hostile parties into one immutable snapshot;
- compute an O(n) proximity/strength-weighted danger vector;
- derive an escape heading or clearance margin without expensive repeated scans;
- keep movement authority separate from threat analysis;
- reuse the same geometry later for caravan escort, companion-party protection, and trade-route safety.

This belongs partly in domain logic and partly in harness evidence. The math is domain behavior. The cadence, proof envelope, cost accounting, and replay fixture belong in harness.

## Evidence retention and archive doctrine

Preservation does not mean leaving gigabytes in live worktrees forever.

Retired evidence may be archived only when the repo records:

- source worktree or branch;
- detached/head commit or PR identity;
- artifact count and byte size;
- archive path;
- manifest path;
- restore instructions;
- reason the evidence is no longer needed in the active worktree.

Active worktree evidence should remain protected unless a workflow contract explicitly permits archival or cleanup.

## Human gate replacement principle

The human operator is valuable, but should not be the default proof mechanism when the harness can collect exact evidence.

For runtime proof lanes, prefer:

```text
agent-run local command
  -> clean preflight
  -> exact head and built/loaded DLL identity
  -> configured mode / authority state
  -> runtime artifacts with timestamps and hashes
  -> post-run cleanup to Manual/hold state
  -> compact packet / PR comment
```

Do not collapse command acknowledgment, route start, movement, arrival, trade delta, or visible UI into one proof level.

## Stale PR closeout doctrine

Stale PRs became stale because the repo lacked a strong enough closeout harness. The new approach is:

1. Inventory open PRs by stack, base, head, changed paths, and semantic value.
2. Classify each unit of value as keep, replay, superseded, reject, or needs-owner-review.
3. Replay onto current `main` or an explicit current foundation branch.
4. Validate under current contracts.
5. Open a replacement PR if needed.
6. Close the old PR only after replacement, rejection, or retention rationale is recorded.

This prevents useful reference-assembly fixes, launcher seams, proof contracts, or worker handoff ideas from disappearing during cleanup.

## Immediate adoption sequence

1. Merge the skills/doctrine/compendium PR after static checks pass.
2. Use the merged relay from PR #46 as the source for a future `tbg-axi` command.
3. Finish PR #43 by replacing the human-only live gate with an agent-verifiable exact-head proof command.
4. Use the compendium and stale-PR skills to select the first legacy PR stack to replay and close.
5. Add evidence archive/retention commands before deleting retired worktrees or large ignored artifact lanes.
6. Start external tool adoption by inspecting Firstmate and Treehouse outside the repo; BlacksmithGuild should expose contracts and packets to them, not vendor them.

## First stale PR area to pursue after current closeout

The most rewarding stale PR area is the worker/handoff and agent-feedback stack, not an isolated feature branch.

Priority candidates:

1. PR #20 worker/governor activity handoff: directly aligns with engine-to-engine worker bees.
2. PR #28-#33 agent feedback/guardrail stack: directly aligns with replacing human interpretation with deterministic harness feedback.
3. PR #24 shared route/profile command contracts: useful after PR #43 because it touches operator mode and route command seams.
4. PR #8/#9 F7 tooling and evidence: replay only current Unicode/log-pattern/test value; do not preserve stale evidence as proof.
5. PR #5/#6 sell/travel stack: pursue after current route proof and visible-trade command layers are stable.

## Done gate

This compendium is useful only if future agents can act from it without rereading the original conversation.

Done means:

- the source insights are preserved;
- stale versus current status is explicit;
- next sprint sequence is ranked by unlock value;
- stale PR cleanup is tied to selective replay;
- runtime proof is framed as agent-verifiable;
- performance/cadence concerns are generalized across engines;
- evidence retention has an archive path rather than indefinite clutter;
- external agentic tools are placed above the repo, not inside it.

## Exact next command

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild"; git fetch origin; gh pr checkout 45; git diff --check origin/main...HEAD; Get-ChildItem .tbg -Recurse -File -Filter *.json | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json | Out-Null }; gh pr checks 45 --repo EndeavorEverlasting/BlacksmithGuild
```
