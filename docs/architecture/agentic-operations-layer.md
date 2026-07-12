# Agentic Operations Layer

```text
[TBG | Agentic Operations Adoption | coordinator/toolchain | branch: docs/agent-skills-stale-pr-cherry-pick]
```

## Decision

BlacksmithGuild remains the repo-specific contract and proof system. External tools coordinate the work around it.

```text
Firstmate / Treehouse / no-mistakes / gnhf / AXI / Lavish
        -> agent operations and operator environment

AGENTS.md / .tbg skills and workflows / ForgeAgentStatus / artifacts
        -> BlacksmithGuild scope, proof, validation, and evidence
```

Do not turn BlacksmithGuild into Firstmate. Do not vendor external coordinators, worktree managers, PR gates, autonomous loops, terminals, editors, or voice applications into the repo.

## Source and freshness posture

This map combines current repository evidence with operator-supplied snapshots of external tools. Repository paths, PR identities, and workflow relationships were checked against PR #45 and current GitHub state at commit time. External tool descriptions are preserved as `stale_but_useful_principle` until their upstream repositories and installation requirements are reverified in a separate inspection or install sprint.

That distinction is deliberate: the architecture does not depend on an external tool keeping the same CLI. It depends on stable roles and on BlacksmithGuild exposing a narrow contract to any tool that fills those roles.

## Tool classification

| Tool | Category | Install scope | Repo impact | Token-saving mechanism | Principal risk | Priority |
|---|---|---|---|---|---|---:|
| Firstmate | external coordinator / crew manager | outside repo | reads contracts and packets; dispatches bounded lanes | compact crewmate reports | coordinator policy drift or overlapping lanes | 1 |
| Treehouse | worktree pool manager | outside repo | leases cached isolated worktrees | stable lane identity and less repeated setup | evidence-bearing lease released too early | 2 |
| AXI | agent-tool interface standard | design standard | shapes future TBG status/proof command | minimal output, aggregates, errors, next steps | terseness hides freshness or proof level | 3 |
| no-mistakes | PR validation gate | external Git remote/operator layer | gates static work and CI | one bounded gate verdict | generic gate cannot prove live Bannerlord state | 4 |
| `npx skills` | skill distribution | project/global agent environment | distributes explicitly public skills | reusable conditional instructions | internal paths/policy published accidentally | 5 |
| gnhf | long-running autonomous loop | outside repo | iterates on bounded static work | commit/rollback loop and exit summary | unsafe live loop without stop contracts | 6 |
| Lavish / lavish-axi | local visual review surface | outside repo | reviews maps, graphs, guides, ladders | targeted annotations | visual approval mistaken for proof | 7 |
| WezTerm | terminal environment | operator machine | hosts named terminal-agnostic commands | durable visible panes | personal config mistaken for repo state | 8 |
| tmux | persistent session backend | operator/coordinator environment | persistent sessions where supported | resumable named sessions | native Windows availability assumed | 9 |
| Neovim | terminal editor | operator machine | optional keyboard-first editing | focused in-session review | accidental required dependency | 10 |
| voice input | prompt throughput aid | operator machine | feeds structured intent | faster intent capture | private data and transcription errors | 11 |

## Cooperation contract

Firstmate or another coordinator may read:

- `AGENTS.md` and the client adapter;
- `.tbg/skills/manifest.json` and only the narrowest relevant skill;
- the active `.tbg/workflows/*.contract.json` contract;
- `artifacts/latest/tbg-chat-packet.json` when generated locally;
- GitHub PR, review, and check state.

BlacksmithGuild must return:

- owned and forbidden paths;
- proof level and freshness;
- validator commands and stable exit status;
- exact-head and artifact identity requirements;
- compact Markdown/JSON evidence;
- one contextual next command.

The coordinator must never infer runtime PASS from a clean PR, successful static CI, command acknowledgment, a built DLL on disk, a terminal layout, or a visual review.

## Treehouse lease plan

| Future lease | Replaces | Release rule |
|---|---|---|
| `route-operator-live-proof` | route operator / PR #37 comparison worktrees | exact-head proof archived and PR disposition recorded |
| `docs-skills` | PR #45 docs worktree | merged head and clean status verified |
| `relay-support` | PR #46 relay worktree | wrapper/script checks pass and PR is merged |
| `stale-pr-replay` | ad hoc legacy stack worktrees | provenance and old-PR disposition recorded |
| `launcher-evidence` | detached launcher-evidence worktree | ZIP/manifest/restore path verified before release |

The lease manager improves isolation; it does not weaken preservation. Evidence-bearing lanes retain an explicit archive obligation.

## TBG AXI design

Keep `ForgeAgentStatus.cmd` as the compatibility wrapper and `scripts/tbg/New-TbgChatPacket.ps1` as the current packet writer. The next implementation seam is `scripts/tbg/Invoke-TbgAxi.ps1` with:

| Command | Default result |
|---|---|
| `status` | repo, branch, head, clean/dirty/conflicted, bounded blocker |
| `prs` | actionable PR groups and definitive empty state |
| `worktrees` | lease/branch/head/dirty/evidence-retention state |
| `packet` | sanitized bounded Markdown/JSON packet paths |
| `proof` | proof level, freshness, exact-head identity, verdict |
| `next` | one safe contextual command |

Output is minimal by default. `--full` may expose bounded detail. Huge raw JSON is never the default. Errors are structured and use stable exit codes. A proof verdict without proof level and freshness is invalid.

## Generic automation boundaries

### Safe now

No-mistakes and gnhf may operate on:

- documentation and handoffs;
- internal skills and registries;
- static workflow contracts and JSON schemas;
- harness validators and fixtures;
- CI path filters;
- stale PR classification reports.

### Requires a TBG runtime adapter

They may not certify or mutate:

- Bannerlord process or foreground state;
- loaded mod assembly identity;
- named-save or campaign identity;
- command inbox state;
- gameplay movement, arrival, trade delta, or visible UI;
- save data.

A runtime adapter must carry a bounded stop contract, exact-head and loaded-DLL hashes, fresh correlated artifacts, numeric behavior evidence where required, and Manual/hold cleanup.

## Visual review surfaces

Lavish is a good review surface for:

- repo-floor sprint maps;
- PR stack topology;
- route proof ladders;
- worker/engine handoff graphs;
- operator-control guides;
- stale PR replay candidates.

The HTML or diagram preserves relationships and annotations. It is not a build, validator, loaded-runtime, or gameplay artifact.

## Skill distribution boundary

The current `.tbg/skills` registry is repo-internal. `AGENTS.md` is the common denominator and `CLAUDE.md` is an adapter.

A skill is eligible for public `npx skills` distribution only when it has:

- standard `SKILL.md` frontmatter;
- no secrets, user-identifying paths, or machine-local assumptions;
- an explicit authority chain and forbidden scope;
- public and versioned referenced contracts;
- a declared support and compatibility boundary.

The new `agentic-operations` skill is structurally package-ready but remains internal until that review is performed. Existing internal skills are not public merely because they use the `SKILL.md` filename.

## Adoption order

1. Merge PR #45 after its static contracts and skill registry pass.
2. Close PR #43's exact-head unattended proof gap with the repo harness.
3. Implement the TBG AXI command surface on the merged PR #46 relay foundation.
4. Inspect Firstmate and Treehouse outside the repo, then run one read-only or docs-only lease.
5. Adapt no-mistakes for static TBG gates.
6. Selectively replay and close one stale PR stack with provenance.
7. Add live-runtime adapters only after bounded stop, loaded-head, artifact, and cleanup contracts exist.

This order is rewarding because it reduces operator burden before expanding autonomy, preserves proof integrity, and turns stale cleanup into a repeatable closeout operation instead of a one-time purge.

## Non-goals

- Installing any external tool in this documentation sprint.
- Editing runtime or gameplay code.
- Launching Bannerlord or mutating saves.
- Closing PRs or deleting branches, worktrees, comments, or evidence.
- Claiming that external tool snapshots are fresh upstream truth.
