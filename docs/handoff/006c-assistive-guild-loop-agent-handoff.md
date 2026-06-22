# 006C Assistive Guild Loop — Agent Handoff

**Last updated:** 2026-06-21  
**Sprint:** 006C-1 trade driver (code shipped, USER cert pending)

## What shipped

- `MapTradeTradeActionReflection.cs` — BuyItemsAction / SellItemsAction reflection
- `TryExecuteBuy` with gold/inventory delta proof
- `ProbeVanillaTradeExecutionNow`
- `MapTradeExecutionResult` on cert + guild loop JSON

## USER verify

```powershell
.\Forge.cmd
.\forge.ps1 -Command RunAutonomousVisibleTradeRouteNow -Wait
.\ExportTbgEvidence.cmd
```

PASS: `tradeExecution.goldDelta < 0`, `quantityBought > 0`, step `ExecuteTrade:Success`

## Next: 006C-2 pack animals, 006C-3 smelt, 006C-4 multi-cycle
