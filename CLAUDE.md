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

## Current harness default

Default harness contract:

```text
.tbg/workflows/local-mcp-code-intelligence.contract.json
```

Default skill registry:

```text
.tbg/skills/manifest.json
```

## Skill loading rule

Read `AGENTS.md` first, then load only the narrowest matching skill.

Common skill choices:
- `repo-floor-hygiene` for PR, branch, worktree, dirty/conflict, stale artifact, and safe-base maps.
- `agent-skill-factoring` for edits to `AGENTS.md`, `CLAUDE.md`, `.tbg/skills/**`, or agent prompt surfaces.
- `stale-pr-cherry-pick` for preserving selected value from stale PRs without blind merge, blind squash, or blind deletion.

Do not paste large stale handoffs into the prompt when the skill and workflow contract can provide the lane rules.

## Runtime boundary

Do not launch Bannerlord, run `ForgeReboot.cmd`, click the launcher, write command inbox files, mutate saves, or modify gameplay behavior unless the active workflow contract explicitly allows it.

If any command assumes Bannerlord should not be running, run the repo's ForgeStop step first.

## Evidence rule

Do not claim completion without evidence. Prefer:

- generated artifact files under `artifacts/latest`
- validator output
- `git diff --check`
- `git status --short`
- PR/commit SHA
- clear list of skipped checks and why

Proof levels do not collapse. A command ACK is not completion. Route start is not arrival. Native Continue is not named-save proof.

## Search rule

Use MCP/LSP or targeted symbol navigation when available. Broad grep is acceptable for bootstrapping, but it is not the long-term search harness.

## Documentation rule

Docs are operational inputs. Update docs, contracts, prompts, policies, scripts, and reports together when they define the same behavior.

Skills must explain executable truth. They must not maintain a competing policy narrative.

## Handoff rule

End serious repo work with:

- completed work
- verification
- gaps and risks
- important paths
- git/PR state
- next command
- copy-paste prompt for the next agent

Exception: if the user explicitly asks for no next-agent prompt, omit it.
