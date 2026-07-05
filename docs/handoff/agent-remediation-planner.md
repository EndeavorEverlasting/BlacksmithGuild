# Agent Remediation Planner Doctrine

## Purpose

The Agent Feedback Harness should not stop at classification.

When the repo has enough evidence to identify a known blocker pattern, the harness should generate a remediation work order that includes:

```text
blocker classification
patch target
byte-safe patch recipe
verification recipe
claim boundary
non-goals
```

This reduces the repeated manual loop:

```text
read blocker
write patch commands
write verifier commands
warn about patch hygiene
ask operator to run the same shape again
```

That loop should become repo memory.

## Core rule

The harness may generate patch recipes.

It must not silently apply them unless the operator explicitly runs the generated script.

The first safe automation target is remediation planning, not autonomous mutation.

## Planned output

```text
BlacksmithGuild_AgentRemediationPlan.json
```

Optional generated scripts should live under:

```text
artifacts/agent-remediation/<timestamp>/
```

Initial generated script names:

```text
apply-remediation.ps1
verify-remediation.ps1
```

## Minimum remediation plan shape

```json
{
  "schema": "TbgAgentRemediationPlan.v1",
  "generatedUtc": "2026-07-05T21:00:00Z",
  "sourceFeedback": "BlacksmithGuild_AgentFeedback.json",
  "classification": "runtime_blocked",
  "blocker": {
    "kind": "interactive_parameter_prompt",
    "summary": "LaunchIntent was not propagated to a nested launcher opener call."
  },
  "patchCandidates": [
    {
      "id": "launch-intent-propagation",
      "targetFile": "scripts/run-autonomous-assist-session.ps1",
      "oldText": "& (Join-Path $PSScriptRoot 'open-bannerlord-launcher.ps1') -BannerlordRoot $bannerlordRoot",
      "newText": "& (Join-Path $PSScriptRoot 'open-bannerlord-launcher.ps1') -BannerlordRoot $bannerlordRoot -LaunchIntent $LaunchIntent",
      "matchCountRequired": 1,
      "patchHygiene": "byte-aware UTF-8/BOM preserving replacement",
      "nonGoals": [
        "routeClockEvidence changes",
        "MapTradeAutonomousService changes",
        "movement detection changes"
      ]
    }
  ],
  "generatedScripts": [
    "artifacts/agent-remediation/20260705-210000/apply-remediation.ps1",
    "artifacts/agent-remediation/20260705-210000/verify-remediation.ps1"
  ]
}
```

## Known remediation patterns

### LaunchIntent interactive prompt

Evidence pattern:

```text
Supply values for the following parameters:
LaunchIntent:
```

or feedback blocker mentioning:

```text
LaunchIntent
interactive mandatory-parameter prompt
open-bannerlord-launcher.ps1
run-autonomous-assist-session.ps1
```

Classification:

```text
runtime_blocked
```

Patch target:

```text
scripts/run-autonomous-assist-session.ps1
```

Expected fix:

```text
pass -LaunchIntent $LaunchIntent into the nested open-bannerlord-launcher.ps1 call
```

Forbidden scope:

```text
routeClockEvidence
MapTradeAutonomousService
AgentAutoMapTradeRoute
runtimeProofClaim
movement detection
```

### Invisible churn / patch hygiene

Evidence pattern:

```text
header-only diff
EOF-only diff
LF/CRLF churn
UTF-8 BOM churn
```

Classification:

```text
contract_fail
```

Expected fix:

```text
revert dirty file
reapply patch byte-aware
preserve BOM
preserve newline shape
show clean diff before commit
```

## Verification rule

Every generated patch script must have a paired verifier script.

A remediation plan without verification is only a suggestion.

Minimum verifier behavior:

```text
PowerShell parse check for changed scripts
git diff --check
git status --short
contract-specific grep/regex check
```

## Safety boundary

The remediation planner can generate scripts. It must not:

```text
run live certs
mutate saves
merge PRs
claim route proof
claim movement proof
change gameplay route logic from a launcher blocker
```

Patch generation is not proof. It is a bounded repair proposal.
