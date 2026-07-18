# Project AI Layer Execution Handoff

```text
[TBG | Sprint 037F | Project AI Layer Execution | branch: sprint/037a-local-agent-harness | PR #39]
```

## Completed

This sprint executed the Project AI Layer plan on top of the Sprint 037A local harness foundation.

Added:

- Root `CLAUDE.md` and layered path-local `CLAUDE.md` files.
- Path-scoped skill catalog.
- Subagent summary schema.
- Agent prompts for session start, symbol smoke, done gate, and exploration subagents.
- Reviewable Claude rules proposal writer.
- Claude stop-hook proposal adapter.
- Sprint 037F workflow contract.
- Policy updates for the new AI-layer scope.

## Important output paths

```text
CLAUDE.md
src/CLAUDE.md
src/BlacksmithGuild/CLAUDE.md
scripts/CLAUDE.md
scripts/harness/CLAUDE.md
scripts/mcp/CLAUDE.md
docs/CLAUDE.md
.tbg/CLAUDE.md
.tbg/workflows/project-ai-layer.contract.json
.tbg/harness/skills/path-scoped-skills.catalog.json
.tbg/harness/schemas/subagent-summary.schema.json
.tbg/harness/prompts/tbg-agent-session-start.md
.tbg/harness/prompts/tbg-symbol-smoke.md
.tbg/harness/prompts/tbg-done-gate.md
.tbg/harness/prompts/tbg-exploration-subagent.md
scripts/harness/Write-TbgClaudeRulesProposal.ps1
.claude/hooks/Write-TbgClaudeRulesProposal.ps1
.claude/settings.example.json
```

## Local validation commands

Run from repo root after fetching the branch:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\harness\Test-TbgHarnessReadiness.ps1 -ContractId "project-ai-layer"
powershell -ExecutionPolicy Bypass -File scripts\harness\Test-TbgCommandSafety.ps1 -CommandText "ForgeReboot.cmd" -ContractId "project-ai-layer"
powershell -ExecutionPolicy Bypass -File scripts\harness\Write-TbgClaudeRulesProposal.ps1 -ContractId "project-ai-layer"
powershell -ExecutionPolicy Bypass -File scripts\harness\Test-TbgDoneGate.ps1 -ContractId "local-mcp-code-intelligence"
git diff --check
git status --short
```

Expected command-safety result:

```text
ForgeReboot.cmd -> decision: deny
ForgeReboot.cmd -> requiresForgeStopFirst: true
```

Expected proposal output:

```text
artifacts/latest/claude-rules-update.proposal.md
```

## Known gaps

- Scripts have not been run on the user's local Windows worktree by this agent.
- MCP/LSP symbol navigation remains a Sprint 037B target, not complete here.
- `Start-TbgDomainMcpServer.ps1` remains an intentional Sprint 037A stub.
- Stop hooks write a proposal artifact only; they do not update `CLAUDE.md` automatically.
- The current policy validator does not fully schema-validate with JSON Schema; it currently parses JSON and checks expected files.

## Risks

- Claude hook payload shape can vary by client/version. The hooks are best-effort adapters around repo-owned scripts.
- The branch was committed through GitHub API, so local executable validation is still required.
- The repo now has multiple small commits from API file creation; squash merge is recommended if you want a clean `main` history.
- If path-local `CLAUDE.md` files get too large, they can recreate the context bloat they are meant to prevent.

## Next target

Sprint 037B: live MCP/LSP symbol smoke.

Primary output:

```text
artifacts/latest/mcp-symbol-smoke.result.json
```

Smoke questions:

```text
Where is MapTradeAutonomousService defined?
Where is StartRouteNow defined?
Who calls StartRouteNow?
Where is CampaignMapReadyOrchestrator defined?
Where is _activeReport assigned, read, and cleared?
Where are hotkeys registered?
Where is command inbox parsing handled?
```

## Parallel-safe work

A separate exploration subagent can inspect MCP/LSP options and propose a concrete local setup while the primary agent keeps PR #39 focused on harness docs/contracts/scripts.

Parallel lane boundaries:

- Exploration subagent: research and summarize only.
- Primary sprint agent: repo edits, policy, contracts, PR hygiene.
- Forbidden for both unless a new contract allows it: game launch, ForgeReboot, command inbox writes, save mutation.
