# Treasury Delta Watch — In-Game Surface Notes

## Purpose

This addendum ties `docs/treasury-delta-watch-plan.md` to the in-game surfaces being planned for Sprint 002.

The treasury watch should not depend only on JSON/log files. The player needs a fast in-game way to answer:

```text
Did any rival treasury move suspiciously since the last check?
```

## Preferred in-game surfaces

### F7 — ShowForgeStatus

When `ShowForgeStatus` exists, it should include a compact Treasury Watch section.

Example:

```text
TBG STATUS
Certification: PASS
Last command: TreasuryDeltaReport
Session phase: CampaignReady
Treasury Watch: ON
Suspicious deltas: 3
Critical anomalies: 1
Last critical: Western Empire +162,000 gold
Report: BlacksmithGuild_TreasuryWatch.json
```

Rules:

```text
- F7 should summarize, not dump every delta.
- F7 should show counts and most severe current alert.
- F7 should mention the report file when details exist.
- F7 should work without alt-tabbing to JSON.
```

### Enter — campaign notice log

Bannerlord's campaign notice log should remain the main player-visible historical surface for short messages.

Treasury Watch should post only high-signal messages there:

```text
TBG TREASURY: Western Empire +162,000 gold — Suspicious
TBG TREASURY: Northern Empire +310,000 gold — Critical anomaly
```

Do not spam ordinary daily deltas.

### Dev console

The dev console is useful for vanilla sanity checks on disposable saves, but it is not certification evidence.

Treasury Watch certification should use:

```text
- BlacksmithGuild_Status.json
- BlacksmithGuild_TreasuryWatch.json
- BlacksmithGuild_Phase1.log
- F7 status summary
- Notice log messages for severe events
```

## Status JSON integration

`BlacksmithGuild_Status.json` should expose enough treasury summary data for F7 to read without rescanning history.

Suggested shape:

```json
{
  "treasuryWatch": {
    "enabled": true,
    "lastRunDay": 152,
    "actorsTracked": 18,
    "observedDeltas": 42,
    "unexplainedDeltas": 6,
    "suspiciousDeltas": 3,
    "criticalAnomalies": 1,
    "lastCriticalActor": "Western Empire",
    "lastCriticalDelta": 162000,
    "lastCriticalClassification": "Critical anomaly",
    "lastReportPath": "BlacksmithGuild_TreasuryWatch.json"
  }
}
```

## Report command behavior

When `TreasuryDeltaReport` is run from the dev command harness:

```text
1. Write or refresh BlacksmithGuild_TreasuryWatch.json.
2. Update BlacksmithGuild_Status.json treasuryWatch summary.
3. Post a compact in-game toast if suspicious or critical deltas exist.
4. Do not mutate save data.
```

Example toast:

```text
TBG TREASURY: 3 suspicious, 1 critical anomaly — press F7 for status
```

## Acceptance test add-on

After Treasury Watch exists and F7 exists:

```text
1. Load disposable campaign.
2. Run TreasurySnapshotNow.
3. Run TreasuryDeltaReport.
4. Press F7.
5. Confirm F7 shows Treasury Watch ON/OFF, actor count, suspicious count, critical count, and report path.
6. Confirm ordinary daily changes do not spam the notice log.
7. Confirm suspicious or critical changes do post a short notice-log message.
```

## Guardrail

F7 is a status surface, not a data engine. It should read summarized state. It should not perform heavy scans, classify deltas, or mutate campaign data.

The ledger works in the background. F7 shows the verdict card.
