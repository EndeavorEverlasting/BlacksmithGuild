# 006C-4 — Sell + Multi-Cycle (implementation record)

**Branch:** `feat/006c-4-sell-loop`  
**Depends on:** 006C-1 buy driver stable  
**Doctrine:** VanillaLegit — delta proof via vanilla `SellItemsAction` / `BuyItemsAction` reflection

## Phases delivered

1. **Sell reflection** — `TryExecuteSell`, inverted PASS rubric vs buy
2. **Sell probe** — `ProbeVanillaSellExecutionNow`, `BlacksmithGuild_MapTradeSellProbe.json`
3. **Mission selection** — spread + surplus sell mission types
4. **Guild loop** — `TryVanillaSell`, `tradeSell` capability, `sellExecution` JSON block
5. **Multi-cycle** — `GuildLoopMaxCyclesPerCommand` re-enters `ContinueFromMarketScan`

## Config

| Key | Default | Cert value |
|-----|---------|------------|
| `GuildLoopMaxCyclesPerCommand` | `1` | `2`–`3` for multi-cycle cert |

## Next after merge

- Live sell cert on Continue save
- Optional: second travel leg for `BuyProfitGoodAndSell` within single command (auto-ride to sell town)
- Wire sell block into `BlacksmithGuild_MapTradeCert.json` export if cert marathon needs unified report
