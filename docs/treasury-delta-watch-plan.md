# Treasury Delta Watch Plan

## Purpose

Add an economy-intelligence feature that tracks treasury changes for non-player kingdoms, clans, and major actors so the player can see when rival empires receive suspicious money swings.

This is not a "the game cheated" siren by default. It is an evidence system.

The mod should record treasury deltas, classify them, and flag changes that are too large, too sudden, or unsupported by visible game events.

## Player question

> Did another empire's treasury change in a way that looks artificial, scripted, or unfair against me?

The mod should answer with:

```text
Who changed?
How much changed?
When did it change?
What likely caused it?
Was the change explainable?
Was the change suspicious?
What evidence supports that judgment?
```

## Design principle

Use the language of **confidence and evidence**, not accusation.

Preferred labels:

```text
Observed
Explained
Partially explained
Unexplained
Suspicious
Critical anomaly
```

Avoid hard labels like:

```text
Cheating
Game cheating
AI cheated
```

unless the feature later gains strong proof from engine-side source tracing.

The first version should be stern and factual: ledger before outrage.

## Why this matters

Bannerlord economy changes can come from many legitimate sources:

```text
- tribute payments
- war declarations and peace settlements
- lord wages
- garrison wages
- caravan profit or loss
- workshops
- taxes
- ransoms
- barter
- settlement ownership changes
- script-driven campaign corrections
- kingdom decisions
- clan expense/income ticks
```

A raw treasury increase is not proof of cheating. The useful feature is the delta ledger plus anomaly scoring.

## Core feature

### Treasury Delta Watch

Track treasury snapshots for relevant actors at regular campaign intervals.

Minimum tracked actor types:

```text
- Player clan
- Non-player kingdoms
- Non-player clans
- Kingdom ruler clans
- Major war enemies
```

Candidate future actor types:

```text
- Towns
- Caravans
- Notables
- Mercenary clans
- Companion parties
```

## Snapshot model

Create a treasury snapshot record:

```csharp
public sealed class TreasurySnapshot
{
    public string ActorId { get; set; }
    public string ActorName { get; set; }
    public string ActorType { get; set; }
    public int Gold { get; set; }
    public int Day { get; set; }
    public float CampaignTime { get; set; }
    public string WarStateAgainstPlayer { get; set; }
}
```

Create a delta record:

```csharp
public sealed class TreasuryDelta
{
    public string ActorId { get; set; }
    public string ActorName { get; set; }
    public string ActorType { get; set; }

    public int PreviousGold { get; set; }
    public int CurrentGold { get; set; }
    public int Delta { get; set; }

    public int PreviousDay { get; set; }
    public int CurrentDay { get; set; }

    public string Classification { get; set; }
    public int SuspicionScore { get; set; }
    public string Explanation { get; set; }
}
```

## Detection cadence

Start simple:

```text
- Take baseline snapshot when campaign becomes ready.
- Take daily snapshot on daily tick.
- Compare current snapshot to previous snapshot.
- Write deltas to log and status JSON.
```

Later:

```text
- Add hourly or event-based snapshots when a war/peace/tribute event occurs.
- Add manual command to dump immediate treasury state.
- Add rolling history per actor.
```

## Anomaly scoring

Start with simple rules.

```text
SuspicionScore = 0

If absolute delta >= 50,000: +20
If absolute delta >= 100,000: +40
If absolute delta >= 250,000: +70
If hostile actor receives large positive delta during active war: +15
If no known explanation attached: +25
If repeated unexplained positive deltas occur within 7 days: +30
If delta reverses major bankruptcy state instantly: +20
```

Classification:

```text
0-24   Observed
25-49  Unexplained
50-74  Suspicious
75+    Critical anomaly
```

These thresholds are starting guesses. Tune after real campaign evidence.

## Explanation engine v0

Attach possible explanations when known.

First-pass explanation categories:

```text
- Tribute or peace payment likely
- War/peace transition near delta
- Settlement ownership changed near delta
- Ransom or prisoner event possible
- Daily economy tick likely
- No matching known event
```

The first version does not need perfect causality. It needs useful context.

## Dev commands

Add these commands after Sprint 001 command harness is certified.

```text
TreasurySnapshotNow
TreasuryDeltaReport
TreasuryWatchToggle
TreasuryWatchClearHistory
```

Suggested bindings later, not for Sprint 001:

```text
F12 = TreasuryDeltaReport
```

Do not steal `Ctrl+Alt+S`; that remains reserved for Sprint 002.

## File outputs

Write a dedicated JSON report:

```text
<Bannerlord install>\BlacksmithGuild_TreasuryWatch.json
```

Suggested shape:

```json
{
  "generatedAt": "campaign-time-or-wall-clock",
  "watchEnabled": true,
  "lastSnapshotDay": 152,
  "actorsTracked": 18,
  "deltas": [
    {
      "actorName": "Southern Empire",
      "actorType": "Kingdom",
      "previousGold": 124000,
      "currentGold": 284000,
      "delta": 160000,
      "classification": "Suspicious",
      "suspicionScore": 80,
      "explanation": "Large hostile treasury increase during active war; no matching known event recorded."
    }
  ]
}
```

Also add summary fields to `BlacksmithGuild_Status.json`:

```json
{
  "treasuryWatch": {
    "enabled": true,
    "lastRunDay": 152,
    "criticalAnomalies": 1,
    "suspiciousDeltas": 3,
    "lastReportPath": "BlacksmithGuild_TreasuryWatch.json"
  }
}
```

## In-game feedback

Only toast severe changes.

Examples:

```text
TBG TREASURY: Western Empire +162,000 gold — Suspicious
TBG TREASURY: Northern Empire -84,000 gold — Observed
```

Do not spam ordinary daily changes.

## UI later

Future panel:

```text
The Blacksmith Guild > Ledger > Treasury Watch
```

Columns:

```text
Actor
Type
Gold before
Gold after
Delta
Classification
Likely explanation
Day
```

Filters:

```text
- Only enemies
- Only unexplained
- Only suspicious or critical
- Last 7 days
- Current war only
```

## Implementation sequence

### Phase TW-0: research and safe read spike

Goal:

```text
Find reliable read paths for kingdom/clan/hero money without mutation.
```

Tasks:

```text
- Inspect Bannerlord assemblies for treasury/money ownership fields.
- Identify whether kingdom, clan, hero, or settlement treasuries are directly readable.
- Add read-only dev command: TreasurySnapshotNow.
- Log actor names and gold values only.
```

Definition of done:

```text
TreasurySnapshotNow logs at least player clan and one non-player faction/clan without crashing.
```

### Phase TW-1: daily snapshot ledger

Goal:

```text
Persist previous daily snapshots and compute deltas.
```

Tasks:

```text
- Add TreasurySnapshotService.
- Capture baseline when campaign is ready.
- Capture daily snapshots on daily tick.
- Compute deltas.
- Write BlacksmithGuild_TreasuryWatch.json.
```

Definition of done:

```text
Daily treasury deltas appear in JSON after advancing campaign days.
```

### Phase TW-2: anomaly scoring

Goal:

```text
Classify deltas by size, hostility, repetition, and explanation confidence.
```

Tasks:

```text
- Add TreasuryDeltaClassifier.
- Add thresholds.
- Add hostile/enemy modifier.
- Add repeated-delta modifier.
- Only toast Suspicious and Critical anomaly events.
```

Definition of done:

```text
Large unexplained hostile gains are flagged as Suspicious or Critical anomaly.
```

### Phase TW-3: explanation context

Goal:

```text
Reduce false positives by attaching nearby campaign events.
```

Tasks:

```text
- Track war/peace events if available.
- Track tribute/payment relevant events if available.
- Track settlement ownership changes if available.
- Attach likely explanation to deltas.
```

Definition of done:

```text
Treasury deltas show likely explanation where the game exposed enough context.
```

### Phase TW-4: anti-cheat evidence mode

Goal:

```text
Give the player a readable evidence trail when the game appears to be injecting resources.
```

Tasks:

```text
- Add rolling history.
- Add actor-specific reports.
- Add current-war report.
- Add export summary.
- Add confidence rating.
```

Definition of done:

```text
Player can inspect why a treasury change was classified as Suspicious or Critical anomaly.
```

## Acceptance tests

### Test A: read-only snapshot

```text
1. Load disposable campaign.
2. Run TreasurySnapshotNow.
3. Confirm report JSON exists.
4. Confirm player clan appears.
5. Confirm at least one non-player kingdom or clan appears.
6. No gold is changed.
```

### Test B: daily delta

```text
1. Capture baseline.
2. Advance one day using dev command harness.
3. Capture next snapshot.
4. Confirm deltas exist.
5. Confirm report includes before/after gold.
```

### Test C: anomaly classification

```text
1. Use a controlled debug-only mutation or test fixture if safe.
2. Force one non-player actor to gain a large amount.
3. Confirm classification becomes Suspicious or Critical anomaly.
4. Confirm in-game toast appears only for high-severity cases.
```

### Test D: no false cheat language

```text
1. Trigger ordinary small daily deltas.
2. Confirm they classify as Observed or Explained.
3. Confirm no toast says "cheating".
4. Confirm report uses evidence language.
```

## Guardrails

```text
- No treasury mutation in watch mode.
- No save corruption risk.
- No infinite per-tick scans.
- No accusations without evidence.
- No UI work until JSON/log reports are useful.
- No smithing work inside this feature.
```

## Dependencies

Must wait until Sprint 001 is stable:

```text
- DevCommandBus
- GameReadinessService
- Status JSON
- File command inbox
- Reliable command certification path
```

Treasury Watch should be Sprint 003 or later unless it becomes the preferred economy-intelligence sprint before recommendations.

## Suggested sprint name

```text
Sprint 003: Treasury Delta Watch
```

Alternate names:

```text
Ledger of Kings
Crown Audit
Imperial Forensics
The Accountant's Spyglass
```

Recommended final name:

```text
Treasury Delta Watch
```

Clear beats cute. The ledger must not sing; it must testify.
