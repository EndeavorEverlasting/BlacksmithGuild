# ForgeTest Operator Guide

## Quick Start

Double-click `ForgeTest.cmd` in the repository root. The console will:

1. Show the selected profile (default: `operator-observe`)
2. Discover registered tests from catalog descriptors
3. Run each test with live progress
4. Show PASS/FAIL results
5. Display the final report path

## Command Line

```powershell
# List all registered tests and profiles
ForgeTest.cmd list

# Show current status
ForgeTest.cmd status

# Run with a specific profile
ForgeTest.cmd run --profile default-static
ForgeTest.cmd run --profile operator-observe

# Run a single test by ID
ForgeTest.cmd run --test core.skill-routing

# Run without pause (for CI or scripting)
ForgeTest.cmd run --no-pause
ForgeTest.cmd list --no-pause
```

## Profiles

| Profile | Authority | Use Case |
|---|---|---|
| `default-static` | None | Static and contract checks. Safe for any checkout. |
| `operator-observe` | Read-only observers | Default for double-click. Runs static checks plus read-only observer tests. |

## Adding a New Test

1. Create a `.test.json` descriptor in `.tbg/harness/test-catalog.d/`
2. The test will be automatically discovered by `ForgeTest.cmd list` and `run`

No changes to `ForgeTest.cmd` or the orchestrator are needed.

## Artifacts

Each run creates:

- `.local/tbg-one-click-tests/<runId>/` - full run artifacts
- `artifacts/latest/one-click-test/` - latest result and report

## Troubleshooting

- **"pwsh.exe not found"**: Install PowerShell Core, or the script falls back to Windows PowerShell.
- **"No profile found"**: Ensure `.tbg/harness/test-profiles.d/` contains at least one `.profile.json`.
- **"Unknown test ID"**: Use `ForgeTest.cmd list` to see available tests.
- **Console closes immediately**: Run from Command Prompt/PowerShell manually, or use `--no-pause`.
