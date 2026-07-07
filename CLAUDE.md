# The Blacksmith Guild Agent Rules

```text
[TBG | Root Agent Rules | repo: EndeavorEverlasting/BlacksmithGuild]
```

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

Default branch for the current harness PR:

```text
sprint/037a-local-agent-harness
```

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

## Search rule

Use MCP/LSP or targeted symbol navigation when available. Broad grep is acceptable for bootstrapping, but it is not the long-term search harness.

## Documentation rule

Docs are operational inputs. Update docs, contracts, prompts, policies, scripts, and reports together when they define the same behavior.

## Handoff rule

End serious repo work with:

- completed work
- verification
- gaps and risks
- important paths
- git/PR state
- next command
- copy-paste prompt for the next agent
