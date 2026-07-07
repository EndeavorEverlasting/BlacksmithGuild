# Route Visible Start Workflow

## Objective

Make one automation engine visibly start campaign-map travel under mod control.

Minimum win:

> MainParty receives a real in-game travel command toward the selected destination, preferably Quyaz, and the workflow emits a compact result JSON.

This workflow is intentionally not a collector run. It is a product behavior proof.

## Command

Preferred local command:

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild"
.\scripts\tbg\Invoke-TbgWorkflow.ps1 -Workflow route-visible-start -TargetSettlement Quyaz
```

The workflow writes:

```text
artifacts/latest/route-visible-start.result.json
```

That JSON is the handoff artifact for AI review.

## Required first step

Because this workflow builds, installs, launches, and reads runtime files, it must stop the game first.

```powershell
$env:FORGE_NO_PAUSE = '1'
$env:FORGE_STOP_CHOICE = 'F'
$env:FORGE_STOP_DEFAULT = 'F'
$env:FORGE_STOP_TIMEOUT_SECONDS = '0'
cmd /c .\ForgeStop.cmd force
```

This rule is not optional. The matching guardrail acknowledgement flag is `-StoppedGameConfirmed`.

## Runtime premise

The route engine should be owned by Bannerlord runtime code, not PowerShell focus.

Valid execution path:

```text
campaign loaded
map state active
safeToExecuteTravel true
recursiveBranchState.nextPlannedBranch travel
targetSettlement resolved
MapTrade or route service issues SetMoveGoToSettlement
route cert written
```

Invalid execution path:

```text
write command inbox
alt-tab to PowerShell
sleep 60 seconds
hope the map moves while unfocused
```

## Result schema

The result contract is intentionally compact.

```json
{
  "workflow": "route-visible-start",
  "commit": null,
  "branch": null,
  "startedAtUtc": null,
  "finishedAtUtc": null,
  "verdict": "PASS|BLOCKED|FAIL",
  "phase": "stop|build|install|launch|map-ready|runtime-action|summarize|done",
  "blockedReason": null,
  "nextPatchHint": null,
  "installedDll": {
    "path": null,
    "lastWrite": null,
    "size": null
  },
  "runtime": {
    "statusFound": false,
    "campaignReady": false,
    "mapStateActive": false,
    "safeToExecuteTravel": false,
    "timePaused": null,
    "targetSettlement": null,
    "nextPlannedBranch": null,
    "nextActionReason": null
  },
  "route": {
    "certFound": false,
    "certPath": null,
    "destinationSettlement": null,
    "targetSettlementId": null,
    "travelCommandIssued": false,
    "routeStarted": false,
    "runtimeProofClaim": null,
    "blockedReason": null
  },
  "files": {
    "status": null,
    "routeCert": null,
    "legacyMapTradeCert": null,
    "commandAck": null,
    "phaseLog": null
  }
}
```

## PASS criteria

A pass requires all of these:

```json
{
  "runtime": {
    "campaignReady": true,
    "mapStateActive": true,
    "safeToExecuteTravel": true,
    "targetSettlement": "Quyaz",
    "nextPlannedBranch": "travel"
  },
  "route": {
    "certFound": true,
    "travelCommandIssued": true,
    "routeStarted": true
  }
}
```

Movement arrival is not required for the first pass.

The pass is route start, not destination completion.

## BLOCKED criteria

A blocked result means the workflow ran and found one exact product blocker.

Examples:

```json
{
  "verdict": "BLOCKED",
  "phase": "runtime-action",
  "blockedReason": "nextPlannedBranch is not travel"
}
```

```json
{
  "verdict": "BLOCKED",
  "phase": "runtime-action",
  "blockedReason": "target settlement missing"
}
```

```json
{
  "verdict": "BLOCKED",
  "phase": "runtime-action",
  "blockedReason": "route cert missing after map-ready"
}
```

Blocked is not failure. It is useful work.

## FAIL criteria

Fail is reserved for tool or script breakage:

- PowerShell exception
- build failed
- ForgeStop failed unexpectedly
- required repo path missing
- result JSON could not be written

A fail should include the first concrete error and should not dump full logs by default.

## Runtime files read by summarizer

The workflow should read only these by default:

| File | Purpose |
|---|---|
| `BlacksmithGuild_Status.json` | Campaign readiness and recursive branch state |
| `BlacksmithGuild_MapTradeRouteCert.json` | Preferred route-start product cert |
| `BlacksmithGuild_MapTradeCert.json` | Legacy fallback cert |
| `BlacksmithGuild_CommandAck.json` | Command dispatcher sanity only |
| `BlacksmithGuild_Phase1.log` | Last few route-related hits only |

The summarizer should not require the user to paste full logs.

## Next patch hints

Use deterministic hints so an AI agent can patch without rediscovery.

| Blocker | Next patch hint |
|---|---|
| `status file missing` | Launch/map-ready workflow did not reach runtime file creation. Fix launch or wait phase. |
| `campaignReady false` | Inspect campaign lifecycle and map-ready gating. |
| `mapStateActive false` | Game reached non-map surface. Fix surface transition or launch target. |
| `safeToExecuteTravel false` | Inspect `GameSessionState` and travel safety classifier. |
| `nextPlannedBranch is not travel` | Inspect recursive branch selector. It is not choosing route traversal. |
| `targetSettlement missing` | Inspect route council or branch state target emission. |
| `route cert missing after map-ready` | In-mod route executor did not start or did not write cert. Inspect `MapTradeAutonomousService.OnCampaignTick`. |
| `travelCommandIssued false` | Movement driver did not accept the command. Inspect `CampaignMapMovementHelper.TryMoveToSettlement`. |
| `routeStarted false` | Cert exists, but route service did not claim start. Inspect route cert model/writer. |

## Agent prompt for future sessions

Use this when handing the result to an AI agent:

```text
We are in The Blacksmith Guild repo. Do not ask for a full collector run.
Read artifacts/latest/route-visible-start.result.json.
Patch only the exact blocker named by blockedReason or nextPatchHint.
If you provide commands that assume Bannerlord should not be running, include ForgeStop first.
Use -StoppedGameConfirmed as the guardrail acknowledgement flag.
The goal is product behavior: issue an in-game route travel command and write BlacksmithGuild_MapTradeRouteCert.json.
```

## Developer note

The command inbox path is not the primary route trigger. If `CommandAck` is stale but the recursive branch state says travel is available, patch the in-game route executor first.

The engine should run from campaign tick or map-ready lifecycle. The terminal is not the clock owner.
