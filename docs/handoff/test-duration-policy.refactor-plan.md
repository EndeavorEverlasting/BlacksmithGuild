# Test duration refactor plan

## Objective

Move the repo from scattered long waits to one shared duration policy.

The documentation is now codified in:

- `docs/operator/test-duration-doctrine.md`
- `docs/handoff/test-duration-policy.manifest.json`
- `docs/handoff/test-duration-policy-agent-note.md`

## Phase 1: inventory

Find all long defaults and direct waits:

```powershell
rg -n "Start-Sleep -Seconds (6[0-9]|[1-9][0-9]{2,})|AttachWaitSec\s*=\s*([3-9][1-9][0-9]|[1-9][0-9]{3,})|MaxRuntimeMinutes\s*=|TimeoutSec\s*=\s*([3-9][1-9]|[1-9][0-9]{2,})" scripts *.cmd docs src
```

Classify each result as:

- valid live cert
- should use 30-second default
- should expose explicit long-run opt-in
- stale/dead code

## Phase 2: shared helper

Create a shared duration helper for PowerShell runners.

Expected behavior:

- default budget: 30 seconds
- explicit long-run profile can exceed 30 seconds
- helper returns budget, source, reason, and whether long run is allowed
- helper logs the selected budget before the run starts

## Phase 3: CMD wrapper policy

CMD files should not own long waits.

They should forward arguments into bounded PowerShell scripts and preserve operator options like `FORGE_NO_PAUSE`.

## Phase 4: verifier

Add a verifier that fails when new default long waits are introduced without an exception marker.

The verifier should inspect scripts and CMD wrappers for:

- long `Start-Sleep`
- long default timeout parameters
- long attach waits
- unbounded loops
- default `MaxRuntimeMinutes`

## Phase 5: migration

Migrate the highest-pain entry points first:

1. launcher/Continue/F7 wrappers
2. autonomous assist session runner
3. reboot iteration runner
4. live cert wrappers
5. economic loop probes

Do not change gameplay behavior while doing the first migration. Make duration policy explicit first, then refactor execution.
