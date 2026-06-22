# Em dashes, log text, and grep (read before writing Phase1 patterns)

**Problem:** Player-facing mod strings use Unicode **em dashes** (`—`, U+2014). ASCII hyphens (`-`, U+002D) and en dashes (`–`, U+2013) look similar in editors and agent chat but **do not match** in log grep, golden-path checks, or evidence tails. This has repeatedly broken F7 gate and golden-path automation.

---

## Three dash characters (do not confuse them)

| Character | Name | Unicode | Example in repo | Use |
|-----------|------|---------|-----------------|-----|
| `-` | Hyphen-minus | U+002D | `MapTransition -> MapReady`, file paths | Code, transitions, paths |
| `–` | En dash | U+2013 | Rare in logs | Avoid in log-matching strings |
| `—` | **Em dash** | **U+2014** | `Blacksmith Guild — Ready:` | **ModDisplay** player notices |

**Rule:** If you are matching text that appears in-game or in `BlacksmithGuild_Phase1.log` from `ModDisplay` / `InGameNotice`, assume **em dash** unless the line is explicitly `[TBG …]` dev prefix.

---

## Canonical source (C#)

All player-facing `"Blacksmith Guild — …"` prefixes come from:

[`src/BlacksmithGuild/DevTools/Reporting/ModDisplay.cs`](../../src/BlacksmithGuild/DevTools/Reporting/ModDisplay.cs)

| Kind | Exact log substring (em dash) |
|------|-------------------------------|
| Ready | `Blacksmith Guild — Ready:` |
| Success | `Blacksmith Guild — Success:` |
| Warn | `Blacksmith Guild — Warn:` |
| Blocked | `Blacksmith Guild — Blocked:` |
| Fail | `Blacksmith Guild — Failed:` |
| Compact | `Blacksmith Guild — {domain}:` |

`InGameNotice.Ready(...)` writes `Blacksmith Guild — Ready: {message}` to Phase1 via `GuildLog.Display`.

**Do not retype these strings from memory.** Copy from `ModDisplay.cs` or use the PowerShell helpers in [`scripts/bannerlord-paths.ps1`](../../scripts/bannerlord-paths.ps1).

---

## PowerShell helpers (automation)

Dot-source `bannerlord-paths.ps1`:

```powershell
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')

# Literal substring for -match / Select-String
$TbgModDisplayReadyPrefix   # Blacksmith Guild — Ready:
Get-TbgReadyGoldenPathPattern  # regex alternation for golden-path tbgReady step
Test-Phase1ReadyLine -Line $line
```

Helpers build the em dash with `[char]0x2014` so keyboard layout and agent paste cannot corrupt the pattern.

---

## Golden path / F7 grep checklist

When adding or editing patterns in:

- [`scripts/compare-phase1-golden-path.ps1`](../../scripts/compare-phase1-golden-path.ps1)
- [`scripts/bannerlord-paths.ps1`](../../scripts/bannerlord-paths.ps1)
- [`scripts/run-f7-gate-continue.ps1`](../../scripts/run-f7-gate-continue.ps1)
- Evidence tail filters

1. Prefer `Get-TbgReadyGoldenPathPattern` or `Test-Phase1ReadyLine` over inline strings.
2. If you must inline, paste from `ModDisplay.cs` or use `[char]0x2014` in PowerShell.
3. After editing, verify against a real Phase1 tail:
   ```powershell
   Select-String -Path "$env:USERPROFILE\Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Phase1.log" -Pattern 'Blacksmith Guild'
   ```
4. **Wrong:** `Blacksmith Guild - Ready:` (ASCII hyphen) — will never match production logs.

---

## Dev / automation prefixes (ASCII, not em dash)

These use ASCII brackets and are safe to type normally:

- `[TBG MAPREADY] StatusFlush ok`
- `[TBG VERSION] Loaded assembly`
- `transition: MainMenu -> MapTransition` (ASCII `->`)
- `TBG READY` (legacy; prefer `Blacksmith Guild — Ready:` for new checks)

---

## Agent handoff rule

When documenting expected log lines in handoff docs or coordination messages:

- Paste **exact** lines from Phase1 tails or from `ModDisplay.cs`.
- Mark em-dash lines explicitly: `` `Blacksmith Guild — Ready:` (em dash U+2014) ``.
- If an agent "fixes" a pattern by replacing `—` with `-`, that is a **regression**.

---

## Related docs

- [`docs/handoff/f7-agent-coordination.md`](../handoff/f7-agent-coordination.md) — live sprint state
- [`docs/handoff/f7-recovery-sprint-handoff.md`](../handoff/f7-recovery-sprint-handoff.md) — target Phase1 sequence
- [`docs/forge-zero-click-contract.md`](../forge-zero-click-contract.md) — PLAY/CONTINUE pipeline
