# Sprint 002 Live Certification Results

## Verdict

**Live-certified** — 2026-06-18, module version **v0.0.5**

## Environment

| Field | Value |
|-------|-------|
| Campaign | Disposable (mod ON) |
| Map | Plain campaign map, paused |
| Session | `phase=MapPaused inbox=True` |
| Cert path | File inbox (`forge.ps1 -CertifyProgression -Wait`) |

## Certified behaviors

| Check | Command | Result |
|-------|---------|--------|
| `rich_smithing_progression` | `RichSmithingProgressionTest` | PASS |
| `add_smithing_xp` | `AddSmithingXp` | PASS |
| `add_smithing_focus` | `AddSmithingFocus` | PASS |
| `add_endurance_attribute` | `AddEnduranceAttribute` | PASS |

**Overall:** `certification002.overall: PASS` (4/4)

## Engineering record (log excerpts)

Source: `BlacksmithGuild_Phase1.log`, session 2026-06-18 16:23.

```text
[TBG TEST] Smithing focus before: 3
[TBG TEST] Smithing focus added: 3
[TBG TEST] Smithing focus after: 6
[TBG TEST] PASS
[TBG TEST] AddSmithingFocus succeeded (file/inbox source).
[TBG TEST] Command received: AddEnduranceAttribute (source: forge.ps1)
[TBG TEST] Endurance before: 5
[TBG TEST] Endurance attribute added: 1
[TBG TEST] Endurance after: 6
[TBG TEST] PASS
[TBG TEST] AddEnduranceAttribute succeeded (file/inbox source).
```

## Note on `-CertifyProgression` closing line

The cert script may print `Certification002 overall: IN_PROGRESS (3/4)` immediately after the last ACK because status JSON flushes asynchronously. **Source of truth:** `.\forge.ps1 -Check -SkipInstall` or F7 / status JSON after a moment.

## Next gate

Sprint 003 Treasury Delta Watch MVP — gated on this PASS (cleared).
