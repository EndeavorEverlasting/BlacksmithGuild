# Local Agent Harness Handoff

```text
[TBG | Sprint 037A | Local Agent Harness Foundation | branch: sprint/037a-local-agent-harness]
```

## What changed

Sprint 037A adds the first repo-native harness layer for future AI coding sessions.

New surfaces:

- `.tbg/harness/manifest.json`
- `.tbg/harness/policies/*.json`
- `.tbg/harness/schemas/*.json`
- `.tbg/workflows/local-mcp-code-intelligence.contract.json`
- `scripts/harness/*.ps1`
- `scripts/mcp/*.ps1`
- `scripts/api/*.ps1`
- `.claude/settings.example.json`
- `.claude/hooks/*.ps1`
- `.mcp.example.json`
- `.cursor/mcp.example.json`

## Local validation

From repo root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\harness\Test-TbgHarnessReadiness.ps1
powershell -ExecutionPolicy Bypass -File scripts\harness\Test-TbgCommandSafety.ps1 -CommandText "ForgeReboot.cmd"
powershell -ExecutionPolicy Bypass -File scripts\harness\Test-TbgDoneGate.ps1 -ContractId "local-mcp-code-intelligence"
powershell -ExecutionPolicy Bypass -File scripts\mcp\Test-TbgMcpReadiness.ps1
git diff --check
git status --short
```

Expected command-safety result for `ForgeReboot.cmd`:

```json
{
  "decision": "deny",
  "requiresForgeStopFirst": true
}
```

## Important boundary

This sprint does not launch the game and does not prove runtime behavior.

## Next sprint

Sprint 037B: wire live MCP/LSP symbol smoke.

Target questions:

- `MapTradeAutonomousService`
- `StartRouteNow`
- `CampaignMapReadyOrchestrator`
- `_activeReport`
- hotkey registration
- command inbox parsing

## Judge note

The harness is useful only if it reduces repeated human babysitting. If future agents still ask which PR, branch, or forbidden scope they are in, the harness has failed its oath.
