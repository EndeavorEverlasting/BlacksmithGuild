# TBG Done Gate Prompt

```text
[TBG | Done Gate | Local Agent Harness]
```

Before claiming completion, report:

- completed work
- changed files
- validation commands run
- skipped checks and why
- generated artifacts
- gaps and risks
- git status
- PR or commit SHA
- next command

## Minimum local checks

```powershell
powershell -ExecutionPolicy Bypass -File scripts\harness\Test-TbgHarnessReadiness.ps1
powershell -ExecutionPolicy Bypass -File scripts\harness\Test-TbgDoneGate.ps1 -ContractId "local-mcp-code-intelligence"
git diff --check
git status --short
```

## Rule

Documentation is not runtime proof. Build output is not game proof. Say exactly what was and was not verified.
