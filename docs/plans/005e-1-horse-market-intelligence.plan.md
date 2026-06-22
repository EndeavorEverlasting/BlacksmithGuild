# Sprint 005E-1 — Horse Market Intelligence + Semantic Color Output

**Status:** CODE SHIPPED — build PASS; Tier 1 in-game smoke PENDING USER  
**Branch:** `main`

---

## Purpose

Read-only horse market analysis: capacity buffer (25% target), pack/war/noble classification from live `ItemObject` data, buy/hold/sell/watch recommendations. No inventory, gold, or time mutation.

---

## Command

```powershell
.\forge.ps1 -Command AnalyzeHorseMarket -Wait
```

Aliases: `ShowHorseMarketIntel`, `RankHorseMarketActions`

**Output:** `<BannerlordRoot>/BlacksmithGuild_HorseMarketIntel.json`

---

## Shipped

1. `src/BlacksmithGuild/HorseMarket/` — classifier, analyzer, recommendation engine, JSON writer
2. `AnalyzeHorseMarket` registered in `DevCommandRegistry` / routed in `DevCommandBus`
3. Semantic line colors via `ReportLineStyle` + `ReportFormatter.SummaryLine(line, style)`
4. `ReportLineClassifier` TBG HORSE prefix fallbacks for unstyled lines
5. Evidence export includes `BlacksmithGuild_HorseMarketIntel.json`
6. `docs/player-command-guide.md` + `NEXT_STEPS.md` updated

---

## Acceptance (Tier 1)

With campaign loaded at a settlement market:

- [x] Build succeeds (`94780a1`, Release 0 warnings)
- [ ] Command runs from inbox — **PENDING** (needs `campaignReady` + party at settlement market)
- [ ] JSON: `readOnly: true`, `mutationApplied: false`, `capacity.targetBufferPercent: 25`
- [ ] In-game lines use semantic colors (buy=green, sell/warn=amber, blocked=red)
- [ ] No inventory/gold/time mutation

**Smoke command:**
```powershell
.\forge.ps1 -Command AnalyzeHorseMarket -Wait
.\ExportTbgEvidence.cmd
```

---

## Next

**005E-2** — Horse Market Memory + Route Profit (town-to-town price history)
