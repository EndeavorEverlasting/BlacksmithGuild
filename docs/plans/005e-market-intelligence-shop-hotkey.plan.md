# 005E Plan — Market Intelligence Shop Hotkey

## Status

**SHIPPED (MVP)** — read-only dev hotkey; user live cert PENDING.

| Gate | Status |
|------|--------|
| F12 / Ctrl+Alt+M hotkey | SHIPPED |
| Nearest-town price scan | SHIPPED |
| Inventory sell targets | SHIPPED |
| Cross-town spread table | SHIPPED |
| Full 005E smithing posse automation | BLOCKED (006I cert) |
| Gauntlet trade UI panel | BACKLOG |

## Purpose

Quick repo test on campaign map: press **F12** to see Trade-skill-style buy/sell intelligence without opening town trade UI.

## Hotkeys

| Key | Command | Action |
|-----|---------|--------|
| F12 | `MarketSnapshotNow` | Scan nearest towns + party inventory; table report |
| Ctrl+Alt+M | `MarketSnapshotNow` | Fallback when F12 swallowed |

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

1. **Sell From Inventory** — party trade goods → best nearby sell town/price
2. **Top Cross-Town Spreads** — buy@town A → sell@town B profit per unit
3. **Nearest Town Goods** — stock + buy/sell at closest town

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

In-game: press **F12**.

**PASS:**
- In-game feed shows `nearest=<town>` and spread/inventory rows
- Phase1 tail contains `TBG REPORT: MARKET INTEL` with table lines
- JSON written with non-empty `spreadRows` or `inventoryRows`
- Prices non-zero

**FAIL:**
- `TBG MARKET: map not ready`
- All prices 0
- Empty town list (increase `MaxMapDistance` in service)

## Scope lock

- Read-only — no buy/sell automation
- Does not unblock full 005E smithing posse plan
- No version bump until user requests
