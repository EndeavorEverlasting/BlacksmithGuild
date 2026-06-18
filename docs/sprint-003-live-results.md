# Sprint 003 Treasury Delta Watch — Live Certification

## Verdict

**PARTIAL PASS** — 2026-06-18 session (machinery proven; strict multi-day F10 retest not completed)

**003B hardening:** deferred snapshots, `snapshotGeneration`, `latestSnapshots[]` in JSON, `TreasurySnapshotNow` dev command.

## Environment

| Field | Value |
|-------|-------|
| Campaign | Disposable save (mod ON), reused from Sprint 002 cert |
| Map | Plain campaign map, paused |
| Test method | F9 only (no F10 fast-forward) — intentional isolation |
| DLL | Treasury MVP @ `94b0d25`, then 003B fixes |

## Certified behaviors (003 MVP session)

| Check | Result |
|-------|--------|
| Treasury watch init | PASS |
| Snapshots taken | PASS — 8 snapshots, 78 actors |
| JSON written | PASS — `BlacksmithGuild_TreasuryWatch.json` |
| F7 cached summary | PASS — `TBG TREASURY: watch=active entities=78` |
| F9 DailyTick | PASS — 8× `DailyTick fired` |
| Treasury deltas | **None observed** — `newDeltas=0`, stable economy |

## Key finding: F9 vs F10

**F9 (`AdvanceOneDay`)** calls `CampaignEventDispatcher.DailyTick()` — it fires daily-tick **listeners** but does **not** advance campaign calendar time.

Evidence: all snapshots logged `day=91077` despite 8 F9 presses.

| Key | Purpose |
|-----|---------|
| **F9** | Sprint 001U DailyTick harness cert |
| **F10 / natural days** | Treasury movement testing (real calendar advancement) |

For treasury delta verification, use **F10 fast-forward 3–5 days** or natural unpaused play — not F9 alone.

## Log excerpts (pre-003B session)

```text
[TBG TREASURY] Treasury Delta Watch initialized.
[TBG TREASURY] Snapshot #1 day=91077 actors=78 newDeltas=0 (map-ready)
[TBG TREASURY] Snapshot #8 day=91077 actors=78 newDeltas=0 (daily-tick)
TBG TREASURY: watch=active entities=78 maxDelta=0 severity=Observed
```

## Status JSON (pre-003B)

```json
"treasuryWatch": {
  "enabled": true,
  "snapshotCount": 8,
  "deltaCount": 0,
  "maxAbsDelta": 0,
  "maxSeverity": "Observed"
}
```

## 003B retest results (2026-06-18)

| Check | Result |
|-------|--------|
| `snapshotGeneration` increments | PASS — gen 1 → 2 → 3 |
| `latestSnapshots[]` populated | PASS — TreasuryWatch JSON |
| Treasury deltas observed | PASS — 5 deltas in session |
| F10 fast-forward machinery | PASS — ON/OFF toggled successfully |
| Campaign day advance (3–5 days) | **Not proven** — day stuck at 91077 (F10 ~2s only) |
| `TreasurySnapshotNow` cert block | **Not run** — no `TBG CERT: 003B TREASURY RETEST` in log |

### Log excerpts (2026-06-18)

```text
TBG TREASURY: Snapshot #1 gen=1 … Snapshot #3 gen=3 … newDeltas=5
TBG F10: Fast-forward ON. / OFF.
TBG F9: DailyTick fired. (multiple Success)
```

Status JSON: `treasuryWatch.snapshotGeneration=3`, `deltaCount=5`, 78 actors tracked.

## 003B retest steps (optional strict completion)

1. Load disposable save → `TBG READY`
2. F7 — confirm `gen=N` in treasury line (003B)
3. F10 ON → wait 3–5 in-game days → F10 OFF
4. F7 again — check `maxDelta`
5. `.\forge.ps1 -Command TreasurySnapshotNow -Wait`
6. Inspect `BlacksmithGuild_TreasuryWatch.json` — expect `snapshotGeneration`, `latestSnapshots[]`

## PASS criteria (003B complete)

- `snapshotGeneration` increments across snapshots
- `latestSnapshots[]` populated in JSON
- Deferred snapshot logs show `(daily-tick)` after tick completes
- Zero deltas acceptable on stable economy if machinery proven

## Failure classification

| Symptom | Likely cause |
|---------|--------------|
| `gen` stuck | Old DLL — close game, `Forge.cmd` |
| Zero deltas after F9 only | Expected — use F10/natural days |
| Zero deltas after F10 | Stable economy PASS; tune thresholds later |
| F7 inactive | No snapshots yet — wait for map-ready or run `TreasurySnapshotNow` |
