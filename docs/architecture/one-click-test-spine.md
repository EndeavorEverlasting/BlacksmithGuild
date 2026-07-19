# One-Click Test Spine Architecture

## Purpose

The one-click test spine is the permanent universal operator front door for repository testing. After this sprint, an operator can pull the committed code and double-click `ForgeTest.cmd` to run the safe default test profile without AI assistance.

## Core Design Rule

> Every new test, observer, cert, PR, or subsystem contributes a descriptor and events. It does not contribute another universal CMD.

## Architecture

```
ForgeTest.cmd (thin CMD front door)
  └─> Invoke-TbgOneClickTest.ps1 (orchestrator)
        ├─> Read profiles from .tbg/harness/test-profiles.d/*.profile.json
        ├─> Read tests from .tbg/harness/test-catalog.d/**/*.test.json
        ├─> Validate descriptors (duplicates, cycles, mutation authority)
        ├─> Resolve dependency order
        ├─> Execute each test
        ├─> Emit events to events.jsonl
        ├─> Write discovered-tests.json, result.json, operator-report.md
        └─> Copy to artifacts/latest/one-click-test/
```

## File Layout

| File | Purpose |
|---|---|
| `ForgeTest.cmd` | Thin front door; no test logic |
| `scripts/tbg/Invoke-TbgOneClickTest.ps1` | Orchestrator: run, list, status commands |
| `scripts/tbg/Write-TbgLiveTestConsole.ps1` | Live console event viewer |
| `scripts/tbg/Test-TbgOneClickTestSpine.ps1` | Spine contract validator |
| `.tbg/workflows/one-click-test.contract.json` | Workflow contract |
| `.tbg/harness/schemas/one-click-test-*.schema.json` | JSON schemas |
| `.tbg/harness/test-catalog.d/**/*.test.json` | Discoverable test descriptors |
| `.tbg/harness/test-profiles.d/*.profile.json` | Discoverable profiles |
| `.tbg/harness/fixtures/one-click-test/*.fixture.json` | Test fixtures |

## Event Envelope

Events follow `tbg.one-click-test.event.v1` schema with at least:

- `run.started`, `profile.selected`, `test.discovered`, `test.skipped`
- `test.started`, `test.stdout`, `test.stderr`, `test.completed`, `test.failed`
- `artifact.registered`, `trigger.candidate`, `run.completed`, `run.blocked`

Each event includes: eventId, eventType, runId, correlationId, parentEventId, testId, source, timestamp, ingestionSequence, proofLevel, payload.

## Test Catalog Entry

Tests are discovered from `.tbg/harness/test-catalog.d/**/*.test.json`. Each entry includes: unique testId, displayName, ownerLane, sourcePath, command, arguments, supportedHosts, requiredTools, dependencies, timeout, mutationClass, riskClass, proofLevel, proofCeiling, tags, defaultProfileMembership, sourceProvenance.

## Profiles

Profiles select tests by tags and test IDs. They never contain product logic. Available profiles:

- **default-static**: Static and contract checks only. No game/build/launcher access.
- **operator-observe**: Safe default for double-click. Static checks plus read-only observers.

## Artifacts Per Run

```
.local/tbg-one-click-tests/<runId>/
  run-context.json
  artifact-registry.json
  events.jsonl
  discovered-tests.json
  result.json
  operator-report.md
  handoff.md
artifacts/latest/one-click-test/
  one-click-test.result.json
  one-click-test.report.md
```

## Safety

- Default profile is non-destructive.
- No automatic game launch, stop, kill, click, focus, save mutation, deployment, or command write.
- Test descriptors may declare risky operations, but the orchestrator blocks them unless the profile permits them.
- A test PASS cannot promote itself above its registered proof ceiling.
- Raw output remains local and ignored.
