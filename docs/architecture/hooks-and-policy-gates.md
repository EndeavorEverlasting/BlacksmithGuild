# Hooks and Policy Gates

```text
[TBG | Sprint 037A | Hooks and Policy Gates | branch: sprint/037a-local-agent-harness]
```

## Purpose

Hooks give each agent session a deterministic safety wrapper. Policy stays in `.tbg/harness/policies`; hook scripts call the shared harness scripts instead of carrying their own separate rules.

## Hook surfaces

| Surface | Script | Job |
|---|---|---|
| Session start | `.claude/hooks/Write-TbgSessionContext.ps1` | Print context and sprint boundary. |
| Pre Bash | `.claude/hooks/Test-TbgBashCommandSafety.ps1` | Check shell commands against the command policy. |
| Pre Write/Edit | `.claude/hooks/Test-TbgFileWriteSafety.ps1` | Check target paths against the file policy. |
| Stop | `.claude/hooks/Test-TbgDoneGate.ps1` | Check required evidence before a session claims completion. |

## Sprint 037A runtime boundary

Sprint 037A is repo infrastructure only. Runtime surfaces are out of scope:

- game launch
- launcher automation
- `ForgeReboot.cmd`
- command inbox writes
- save changes
- gameplay behavior changes
- real local client config or secrets

## ForgeStop rule

Future workflows that allow build, install, or launch commands must include a ForgeStop step first. That rule belongs in the contract and command policy.

## Result shape

Hook scripts emit `tbg.hook-result.v1` objects with:

- hook
- timestampUtc
- contractId
- decision
- reason
- matchedPattern
- findings

## Done gate

The done gate checks the active workflow contract, required artifacts, JSON validity, and cheap Git hygiene. It does not prove runtime behavior. Runtime proof remains separate.
