# Runtime Evidence Contract

## Purpose

The BlacksmithGuild harness must distinguish script success from game behavior success.

A script finishing means only that the script ran. It does not prove travel, trade, smithing, recruitment, or automation happened inside Bannerlord.

## Evidence standard

A runtime claim needs at least one repo-recognized artifact.

Important runtime proof files include:

```text
BlacksmithGuild_Status.json
BlacksmithGuild_MapTradeRouteCert.json
BlacksmithGuild_MapTradeCert.json
BlacksmithGuild_CommandAck.json
BlacksmithGuild_Phase1.log
```

Workflow-level summaries may be written under:

```text
artifacts/latest/
```

## PASS language

Allowed claims:

```text
static verifier passed
runtime files were found
route cert was found
travel command was accepted by the movement seam
workflow produced a blocked reason
```

Forbidden claims without live evidence:

```text
the game moved
the route completed
the trade completed
the activity ledger is listening in-game
the automation is product-ready
```

## Runtime proof validator

Use:

```powershell
.\scripts\tbg\Validate-TbgRuntimeProof.ps1
```

Default output:

```text
artifacts/latest/runtime-proof.validation.json
```

This validator summarizes the available proof artifacts. It does not launch Bannerlord, mutate saves, or create runtime proof by itself.

## Route-visible-start minimum result

A route-start workflow can only claim PASS when compact evidence supports:

```json
{
  "runtime": {
    "campaignReady": true,
    "mapStateActive": true,
    "safeToExecuteTravel": true,
    "nextPlannedBranch": "travel"
  },
  "route": {
    "certFound": true,
    "travelCommandIssued": true,
    "routeStarted": true
  }
}
```

## Activity-ledger future standard

The activity ledger must emit meaningful events and compact summaries without becoming a performance tax.

Runtime should read bounded state, not full history.

Planned outputs:

```text
BlacksmithGuild_ActivityJournal.jsonl
BlacksmithGuild_ActivityState.json
BlacksmithGuild_RecentActivity.json
BlacksmithGuild_PlanLedger.jsonl
BlacksmithGuild_PlanComparisons.jsonl
BlacksmithGuild_FeatureSignals.jsonl
BlacksmithGuild_ActivityReport.md
```

## Stop rule

Before build, install, launch, live-cert, or full runtime validation:

```powershell
$env:FORGE_NO_PAUSE = '1'
.\ForgeStop.cmd soft
```

Static docs, contract checks, and summarize-only validation do not require a game stop.
