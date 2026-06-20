# 005E Plan — Market Intelligence Shop Hotkey

## Status

**USER PASS (2026-06-20)** — read-only dev hotkey; live cert complete @ Danustica.

| Gate | Status |
|------|--------|
| Ctrl+Alt+M hotkey (primary) | **USER PASS** — F12 remapped due to Steam screenshot collision |
| Legacy F12 | Off by default (`LegacyF12MarketHotkey=false`) |
| Nearest-town price scan | **USER PASS** |
| Inventory sell targets | **USER PASS** |
| Cross-town spread table | **USER PASS** |
| **Action plan (buy @ nearest + ride to sell)** | **USER PASS** |
| Expanded scan fallback (60u / 8 towns) | **USER PASS** (observed: `expanded scan (no routes in 30u)`) |
| Full 005E smithing posse automation | BLOCKED (real forge rank cert pending) |
| Gauntlet trade UI panel | BACKLOG |

## Purpose

Quick repo test on campaign map: press **Ctrl+Alt+M** to see Trade-skill-style buy/sell intelligence without opening town trade UI.

## Hotkeys

| Key | Command | Action |
|-----|---------|--------|
| Ctrl+Alt+M | `MarketSnapshotNow` | Primary — scan nearest towns + party inventory; table report |
| F12 | `MarketSnapshotNow` | Legacy only when `LegacyF12MarketHotkey=true` (conflicts with Steam) |

Also available via file inbox: `.\forge.ps1 -Command MarketSnapshotNow -Wait`

## Bannerlord APIs

```csharp
town.GetItemPrice(item, MobileParty.MainParty, isSelling: false); // buy
town.GetItemPrice(item, MobileParty.MainParty, isSelling: true);  // sell
settlement.ItemRoster.GetItemNumber(item);                         // stock
item.IsTradeGood;                                                  // filter
```

Fallback: `town.MarketData.GetPrice(item, party, isSelling, settlement.Party)`

## Report sections

1. **Action Plan** — numbered steps: enter nearest town, buy item, ride to sell town
2. **Buy @ Nearest** — in-stock goods at nearest town ranked by profit spread (smithing inputs tagged `[smith]`)
3. **Sell From Inventory** — party trade goods → best nearby sell town/price (zero-spread rows suppressed in feed)
4. **Top Cross-Town Spreads** — global buy@town A → sell@town B profit per unit
5. **Nearest Town Goods** — stock + buy/sell at closest town

When no routes exist within 30 map units, scan auto-expands to 60u / 8 towns (`expandedScanUsed` in JSON).

## Output files

```text
<Bannerlord>\BlacksmithGuild_Phase1.log       (full table)
<Bannerlord>\BlacksmithGuild_MarketIntel.json (structured evidence)
```

## Live cert rubric

**Precondition:** `TBG READY` on campaign map, near at least one town.

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\Forge.cmd
```

In-game: press **Ctrl+Alt+M**.

**PASS:**
- In-game feed shows `--- ACTION PLAN ---` with buy + destination (not just inventory `+0` rows)
- Feed shows `--- BUY@NEAREST ---` when routes exist
- Phase1 tail contains `TBG REPORT: MARKET INTEL` with Action Plan section
- JSON written with non-empty `routeRows` and `actionPlan` (or expanded scan note if still empty)
- Prices non-zero

**FAIL:**
- `TBG MARKET: map not ready`
- All prices 0
- Empty town list (increase `MaxMapDistance` in service)

### User cert record (2026-06-20)

Location: Danustica @ 4.1u, 3 towns scanned, expanded scan used.

Feed: ACTION PLAN (Felt → Husn Fulq +880), BUY@NEAREST (Felt/Planks/Oil), TOP SPREADS (Velvet Onira→Danustica +862).

See [functionality-status.md](../functionality-status.md).

## Scope lock

- Read-only — no buy/sell automation
- Does not unblock full 005E smithing posse plan
- No version bump until user requests
