# ExternalStateTimeline.json Schema

**Version:** 1  
**Owner:** Agent C — External State Classifier

---

## Artifact name

`ExternalStateTimeline.json`

---

## Paths

| Context | Path |
|---------|------|
| F7 cert checkpoint | `docs/evidence/live-cert/{sessionId}/checkpoint-01-f7-gate/ExternalStateTimeline.json` |
| Open log mirror (optional dev/assistive) | `docs/control/logs/open/ExternalStateTimeline.json` |

Committed schema reference: this file.

---

## Top-level shape

```json
{
  "schemaVersion": 1,
  "mode": "cert",
  "sessionId": "20260623-200917",
  "startedAtUtc": "2026-06-23T20:09:17.0000000Z",
  "events": []
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `schemaVersion` | int | yes | Currently `1` |
| `mode` | string | yes | `cert` or `assistive` |
| `sessionId` | string | no | F7 session id when known |
| `startedAtUtc` | string | no | ISO-8601 roundtrip |
| `events` | array | yes | Ordered classification events |

---

## Event object

Each event records one classification snapshot at a point in time.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `timestampUtc` | string | yes | ISO-8601 UTC |
| `mode` | string | yes | `cert` or `assistive` |
| `classifiedState` | string | yes | Primary state (process or in-game surface) |
| `confidence` | string | yes | `high`, `medium`, `low`, `unknown` |
| `processName` | string | no | e.g. `Bannerlord`, `TaleWorlds.MountAndBlade.Launcher` |
| `processId` | int | no | Windows PID |
| `hwnd` | int | no | Main window handle when known |
| `windowTitle` | string | no | Main window title |
| `windowBounds` | object | no | `{ left, top, width, height }` |
| `foregroundWindowMatch` | bool | no | Whether foreground hwnd matches classified target |
| `evidenceSources` | string[] | yes | e.g. `process`, `window`, `BlacksmithGuild_Status.json`, `Phase1.tail.txt` |
| `legalActions` | string[] | yes | Actions permitted in this state + mode |
| `forbiddenActions` | string[] | yes | Actions blocked |
| `expectedTransitions` | string[] | no | Likely next states |
| `routeAgent` | string | yes | Who owns the next move |
| `reason` | string | yes | Human-readable classification rationale |
| `manualLaunchObserved` | bool | no | User launched manually |
| `assistiveAttach` | bool | no | Attach mode active |
| `certTarget` | string | no | F7 cert target when in cert mode |
| `launchPath` | string | no | Observed `continue` / `play` / `unknown` |
| `targetMismatch` | bool | no | Cert contamination flag |
| `runtimeEvidenceStates` | string[] | no | Derived evidence labels |
| `launchState` | string | no | F7 `LAUNCH_STATE` when applicable |

---

## Example: assistive attach at settlement menu

```json
{
  "timestampUtc": "2026-06-23T20:09:43.0000000Z",
  "mode": "assistive",
  "classifiedState": "SettlementTownMenu",
  "confidence": "medium",
  "processName": "TaleWorlds.MountAndBlade.Launcher",
  "processId": 139112,
  "windowTitle": "Mount and Blade II Bannerlord - Singleplayer",
  "evidenceSources": [
    "process",
    "window",
    "BlacksmithGuild_Status.json"
  ],
  "runtimeEvidenceStates": [
    "StatusFresh",
    "SessionReady",
    "ReadinessSurfaceSettlementMenu"
  ],
  "legalActions": [
    "observe",
    "poll_status",
    "surface_advisory"
  ],
  "forbiddenActions": [
    "click_launcher_continue",
    "claim_f7_pass",
    "mutate_inventory"
  ],
  "expectedTransitions": [
    "SettlementInterior",
    "CampaignMapSurface",
    "SmithyScreen"
  ],
  "routeAgent": "Agent B - Runtime / Readiness / Gameplay safety",
  "reason": "Game inside campaign session at settlement town menu; runtime status drives assistance.",
  "manualLaunchObserved": true,
  "assistiveAttach": true,
  "targetMismatch": false
}
```

---

## Example: cert mode preflight clean

```json
{
  "timestampUtc": "2026-06-23T20:09:18.0000000Z",
  "mode": "cert",
  "classifiedState": "ProcessClean",
  "confidence": "high",
  "evidenceSources": ["process"],
  "legalActions": ["observe", "start_launcher_automation"],
  "forbiddenActions": ["claim_f7_pass", "mutate_inventory"],
  "expectedTransitions": ["LauncherOpening", "LauncherMenu"],
  "routeAgent": "Agent C - External State Classifier / F7 Runner",
  "reason": "Preflight clean; no Bannerlord processes before cert launch.",
  "certTarget": "continue",
  "launchPath": "unknown",
  "targetMismatch": false,
  "manualLaunchObserved": false,
  "assistiveAttach": false
}
```

---

## Confidence guidance

| Level | When to use |
|-------|-------------|
| `high` | Standalone `Bannerlord.exe` or definite process match + fresh Status agreement |
| `medium` | Launcher-hosted window + fresh Status or Phase1 |
| `low` | Phase1-only or uncertain process detection |
| `unknown` | Missing/stale evidence; use for click guard deny |
