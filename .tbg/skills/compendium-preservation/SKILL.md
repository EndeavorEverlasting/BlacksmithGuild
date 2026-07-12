# Skill: compendium-preservation

Use this skill when a sprint contains valuable insights from chat annotations, stale PR maps, runtime comments, toolchain research, or older snapshots that must be preserved without turning stale context into current truth.

## Use when

- The operator provides a long annotated sprint history and asks the repo not to lose it.
- A stale PR, branch, artifact, or comment contains a useful principle that should be replayed later.
- A sprint must choose the most rewarding next move across hygiene, harness, runtime proof, evidence retention, and agent operations.
- A future agent needs a compact doctrine bridge instead of rereading a huge chat transcript.

## Do not use when

- The sprint only needs a direct runtime bug fix.
- The source insight has no repo relevance or no safe verification path.
- The proposed action would close PRs, delete branches, delete worktrees, or delete evidence without replacement, archive manifest, or rejection rationale.
- Static documentation would be used to claim gameplay or visible-trade proof.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `.tbg/workflows/compendium-preservation.contract.json`
4. `docs/architecture/compendium-preservation-and-rewarding-sprint.md`
5. `docs/architecture/harness-skill-maturity.md`
6. `docs/architecture/agent-skill-factoring-and-stale-pr-cherry-pick.md`
7. `docs/handoff/post-pr41-repo-hygiene-map.md`

## Owned scope

- `docs/architecture/**` compendium, adoption, and sprint-priority docs.
- `.tbg/workflows/*compendium*` contracts.
- `.tbg/skills/**` skill routing when a new recurring lane is discovered.
- PR body updates that preserve provenance and next commands.
- Handoff docs that classify stale insight without changing runtime behavior.

## Forbidden scope

- `src/**` runtime edits unless a separate runtime skill owns them.
- Bannerlord launch, ForgeReboot, command inbox writes, or save mutation.
- Runtime proof claims from stale logs, stale PR bodies, or static reports.
- Destructive cleanup before replacement, archive manifest, or rejection rationale.

## Classification rule

Classify every insight before acting.

| Class | Meaning | Allowed next action |
|---|---|---|
| `current_truth` | Verified against current source, contracts, PR state, or fresh artifact. | May be cited as current repo state. |
| `stale_but_useful_principle` | Snapshot may be stale, but the design idea remains valuable. | Preserve as doctrine; revalidate before implementation. |
| `replay_candidate` | A stale PR/branch/hunk/test/doc has salvageable value. | Route through `stale-pr-cherry-pick`. |
| `needs_runtime_proof` | Static evidence cannot prove it. | Build or invoke an agent-verifiable local proof path. |
| `rejected_or_superseded` | Obsolete, unsafe, or already replaced. | Record rationale before cleanup. |

## Rewarding sprint priority

When several lanes compete, prefer the one that unlocks the most future work while reducing operator burden.

1. Preserve relay and AXI packet pathways so future agents can read compact local state.
2. Codify harness/skill boundaries so useful ideas become contracts instead of chat memory.
3. Automate exact-head runtime proof where the repo already has safe launch/proof contracts.
4. Replay and close stale PRs only after their value is classified and replacement paths exist.
5. Archive ignored runtime evidence only with manifest, size, provenance, and restore instructions.
6. Move engine cadence/performance concerns into shared harness contracts before adding more worker behavior.

## Common traps

- Treating a long chat as an implementation plan without freshness classification.
- Treating stale PR cleanup as branch deletion instead of selective replay and closeout.
- Preserving gigabytes of evidence forever because deletion feels risky, or deleting it without an archive manifest.
- Demanding the operator to prove a branch manually when a local harness command can collect machine evidence.
- Letting performance concerns live inside one engine instead of defining common cadence and retention vocabulary.

## Done gate

A compendium sprint is done only when:

- source insights are preserved in a repo-owned file;
- each major insight is classified by freshness and utility;
- the most rewarding next sprint is explicitly named;
- stale PR, evidence, runtime proof, and agent-operations implications are separated;
- validation commands are run or exact skipped commands are named;
- one exact next command is provided.

## Handoff output

End with:

- source insights captured;
- classifications;
- changed files;
- validation run;
- skipped checks;
- remaining risks;
- exact next command.
