---
name: agentic-operations
description: Route external coordinators, worktree pools, PR gates, autonomous loops, AXI commands, visual review, skill distribution, and operator tools around BlacksmithGuild without vendoring them or weakening proof boundaries.
---

# Skill: agentic-operations

Use this skill when a sprint evaluates or adopts Firstmate, Treehouse, no-mistakes, gnhf, AXI, Lavish, `npx skills`, terminal/session tools, or voice input around BlacksmithGuild.

## Distribution posture

This skill is repo-internal today. Its standard `SKILL.md` frontmatter makes it structurally package-ready, but it must not be published through `npx skills` until a packaging review removes machine-local assumptions, confirms referenced contracts are public, and assigns a versioned support boundary.

`AGENTS.md` remains the common denominator. `CLAUDE.md` remains a client adapter. This skill is conditional lane guidance, not a replacement constitution.

## Use when

- An external coordinator needs to dispatch work into BlacksmithGuild.
- Manual sibling worktrees should become isolated leases.
- A generic PR gate or autonomous loop needs a TBG safety boundary.
- `ForgeAgentStatus` is evolving into a compact AXI-style command.
- Skills may be distributed across Codex, Claude, Cursor, OpenCode, or another supported agent.
- Sprint maps, PR topology, proof ladders, or worker graphs need a visual review surface.

## Do not use when

- The task is a direct runtime feature or gameplay fix.
- The task merely installs tools without an adoption contract.
- A generic gate would be used to claim loaded-DLL, save, movement, trade, or visible-UI proof.
- External tool state would be committed as repo truth.
- The proposed change vendors Firstmate, Treehouse, no-mistakes, gnhf, Lavish, an editor, terminal, or voice application into BlacksmithGuild.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `.tbg/workflows/agentic-operations-adoption.contract.json`
4. `docs/architecture/agentic-operations-layer.md`
5. `docs/architecture/compendium-preservation-and-rewarding-sprint.md`
6. `docs/handoff/agentic-toolchain-sprint-map.md`
7. `docs/handoff/local-agent-status-relay.md`

## Authority model

```text
external agent operations layer
  -> reads repo contracts, skills, packets, PR/check state
  -> allocates isolated work and applies generic gates

BlacksmithGuild repo harness
  -> owns scope, proof levels, validators, artifacts, runtime boundaries
  -> returns compact status, evidence, errors, and next commands
```

The external layer may coordinate BlacksmithGuild. It may not redefine what counts as BlacksmithGuild proof.

## Owned scope

- `.tbg/workflows/agentic-operations-adoption.contract.json`
- `.tbg/skills/agentic-operations/SKILL.md`
- `.tbg/skills/manifest.json` registration for this skill
- `docs/architecture/agentic-operations-layer.md`
- `docs/handoff/agentic-toolchain-sprint-map.md`
- Documentation for future `ForgeAgentStatus` / `Invoke-TbgAxi.ps1` behavior

## Forbidden scope

- `src/**` runtime edits in an adoption-map sprint.
- Bannerlord launch, ForgeReboot, command-inbox writes, or save mutation.
- Worktree, branch, PR, comment, or artifact deletion without the owning hygiene/retention workflow.
- Tool installation or personal terminal/editor configuration unless an explicit install sprint owns it.
- Runtime PASS claims from documentation, CI, a clean GitHub merge state, or visual review.

## Tool routing

| Need | Tool layer | Required TBG input | Required output |
|---|---|---|---|
| Dispatch bounded work | Firstmate | root rules, narrow skill, workflow contract, packet | PR, local merge, or investigation report |
| Lease isolated workspace | Treehouse | lane name, base, retention class | worktree identity and release disposition |
| Gate static changes | no-mistakes | commands, path boundary, exit codes | bounded gate verdict and CI state |
| Run long static loop | gnhf | stop conditions, rollback boundary, static task | committed iterations and exit summary |
| Reduce tool output | AXI | proof vocabulary and packet schema | compact output, errors, next command |
| Review visual artifacts | Lavish | generated HTML/diagram plus provenance | localized annotations, not proof |
| Distribute a skill | `npx skills` | reviewed public package | installed version and target agents |

## AXI rule

Keep `ForgeAgentStatus.cmd` as the compatibility wrapper. A future `scripts/tbg/Invoke-TbgAxi.ps1` should expose:

```text
status
prs
worktrees
packet
proof
next
```

Default output must be bounded and content-first. Full detail requires an explicit switch. Every proof result includes proof level and freshness. Every failure has a stable exit code and one contextual next command.

## Runtime adapter rule

No-mistakes and gnhf may own docs, skills, schemas, fixtures, static validators, and path-filtered CI immediately. They may not own live Bannerlord proof until an adapter verifies:

- clean exact head;
- built and installed DLL hashes;
- loaded runtime assembly identity;
- save/campaign identity at the level claimed;
- command correlation and fresh artifacts;
- numeric behavior evidence where required;
- post-run Manual/hold cleanup;
- bounded timeout and stop behavior.

## Common traps

- Recreating Firstmate inside `.tbg` instead of exposing clean interfaces to it.
- Treating reusable worktrees as disposable when they contain unarchived runtime evidence.
- Publishing internal skills because they have a `SKILL.md` filename without reviewing their references and support boundary.
- Letting compact AXI output omit freshness or proof level.
- Letting a visual review annotation stand in for a validator or runtime artifact.
- Using a long-running loop on live gameplay because it worked for static docs.

## Done gate

- The two-layer cooperation model is explicit.
- Each external tool has a category, boundary, risk, and adoption priority.
- Worktree leases have release and evidence-retention rules.
- AXI commands, output limits, errors, proof levels, and next-command behavior are defined.
- Static and runtime-safe adoption boundaries are separated.
- Internal versus public-installable skill status is explicit.
- JSON contracts parse and `git diff --check` passes, or the exact environment blocker is recorded.

## Handoff output

Return the branch and PR, tool classifications, files changed, validations, skipped checks, risks, and one exact next command. Do not include a next-agent prompt when the operator forbids one.
