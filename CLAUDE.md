# The Blacksmith Guild Agent Rules

```text
[TBG | Root Agent Rules | repo: EndeavorEverlasting/BlacksmithGuild]
```

## Authority chain

`AGENTS.md` is the repo-universal coordination contract. This file is a Claude-facing adapter and must not become a second constitution.

When guidance overlaps:
1. executable workflow contracts and source code win;
2. `.tbg/skills/<skill-id>/SKILL.md` explains the active lane;
3. `AGENTS.md` supplies root rules;
4. this file supplies Claude-specific reminders.

## Identity

Always identify the active workstream at the top of substantial responses:

```text
[TBG | Sprint/PR | lane/context | branch: <branch>]
```

Name the repo, branch, PR or sprint, scope, forbidden scope, expected artifacts, and validation status before claiming completion.

## Progressive disclosure

Read in this order:

1. `AGENTS.md`;
2. `CODEBASE_MAP.md`;
3. `.tbg/skills/manifest.json`;
4. only the narrowest matching skill and required contracts;
5. current state/evidence required by that workflow.

Default code-intelligence contract:

```text
.tbg/workflows/local-mcp-code-intelligence.contract.json
```

Composed validation and handoff contracts:

```text
.tbg/workflows/end-to-end-validation.contract.json
.tbg/workflows/tbg-sprint-capsule.contract.json
```

## Skill loading rule

Common skill choices:
- `repo-floor-hygiene` for PR, branch, worktree, dirty/conflict, stale artifact, and safe-base maps.
- `agent-skill-factoring` for edits to root rules, `.tbg/skills/**`, or prompt surfaces.
- `harness-maturity` for E2E profiles, operation APIs, sprint capsules, or consumer handoffs.
- `stale-pr-cherry-pick` for preserving selected value from stale PRs without blind merge, squash, or deletion.

Do not paste large stale handoffs into the prompt when the skill and workflow contract provide the lane rules.

## Runtime boundary

Do not launch Bannerlord, run `ForgeReboot.cmd`, click the launcher, write command inbox files, mutate saves, or modify gameplay behavior unless the active workflow contract explicitly allows it.

If any command assumes Bannerlord should not be running, run the repo's ForgeStop step first.

## Evidence rule

Do not claim completion without evidence. Prefer generated artifacts, validator output, Git state, and exact commit/PR identity.

Proof levels do not collapse. A command ACK is not completion. Route start is not arrival. Native Continue is not named-save proof. AgentSwitchboard or SysAdminSuite acceptance is not BlacksmithGuild runtime certification.

## Search and documentation

Use MCP/LSP or targeted symbol navigation when available. Broad grep is acceptable for bootstrapping, not as the long-term search harness.

Docs are operational inputs. Update docs, contracts, policies, scripts, schemas, and reports together when they define the same behavior. Skills explain executable truth; they do not maintain a competing policy narrative.

## Handoff rule

End serious repo work with completed work, verification, gaps/risks, important paths, Git/PR state, and one exact next command. Generate `tbg.sprint-capsule.v1` for another agent, AgentSwitchboard, or an explicitly authorized SysAdminSuite tandem lane. A prose prompt is secondary and may not exceed the capsule's proof ceiling.
