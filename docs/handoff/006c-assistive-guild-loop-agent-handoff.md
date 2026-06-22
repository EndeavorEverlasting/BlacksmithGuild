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

PASS: `tradeExecution.goldDelta < 0`, `quantityBought > 0`, step `ExecuteTrade:Success` or `ExecutePackAnimalBuy:Success`

## 006C-2 pack-animal USER verify

```powershell
.\Forge.cmd
# Low capacity / few pack animals — or travel to town with sumpter/mule stock
.\forge.ps1 -Command ProbePackAnimalBuyNow -Wait
.\forge.ps1 -Command RunAutonomousVisibleTradeRouteNow -Wait
.\ExportTbgEvidence.cmd
```

PASS: `missionType: BuyPackAnimalForCapacityThenTrade`, `tradeExecution.itemClassification: PackAnimal`, gold delta negative.

## 006C-3 weapon smelt USER verify

```powershell
.\Forge.cmd
# Ensure party has tier-1 loot weapon (town buy if needed)
.\Run-WeaponSmeltCert.cmd
.\forge.ps1 -Command RunAutonomousGuildLoopNow -Wait
.\ExportTbgEvidence.cmd
```

PASS: `SmithingSmeltExecution.json` → `attemptSuccess: true`, `weaponsAfter < weaponsBefore`, iron/charcoal increased; guild loop step `TryWeaponSmelt: Success`.

## Next: 006C-4 sell/multi-cycle
