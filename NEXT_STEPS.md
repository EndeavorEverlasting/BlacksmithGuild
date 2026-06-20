# Next Steps

**Daily dev:** `Forge.cmd` — [forge-zero-click-contract.md](docs/forge-zero-click-contract.md)  
**Where we are:** [functionality-status.md](docs/functionality-status.md)  
**Handoff:** [post-stage-b-smithing-advisory-handoff.md](docs/checkpoints/post-stage-b-smithing-advisory-handoff.md)

---

## Sprint status

| Sprint | Status |
|--------|--------|
| **Track 2A map rank** | **USER PASS** 2026-06-20 @ 16:34 — Real/Javelin/PASS on Continue; manual javelin craft |
| **Stage B smithing advisory** | **CODE SHIPPED** — SMITHING CREW, charcoal prep steps, Ctrl+Alt+G — **USER cert PENDING** |
| **Stage C auto-refine** | **FOUNDATION** — inbox `RunSmithingSafeActionNow` blocked until refine API mapped |
| **007B / 007C** | USER PASS / shipped |
| **006J closeout** | **PARTIAL** — 1D Path B Back pending |

---

## What works right now

| You can… | How |
|----------|-----|
| Real forge rank on map | **Ctrl+Alt+R** — `source=real`, Javelin-style ranks (USER PASS) |
| Guild loop report | **Ctrl+Alt+G** — market + forge + smithing crew |
| Charcoal prep advisory | **Ctrl+Alt+R** when low charcoal — companion RefineCharcoal in SMITHING CREW + ACTION PLAN |
| Market routes | **Ctrl+Alt+M** |
| Status | **F7** |

| You cannot yet… | Why |
|-----------------|-----|
| Auto-refine charcoal headless | Stage C API not mapped — use smithy UI or inbox shows blocked |
| Auto buy/sell | Scope-locked |
| Inventory spawn on Continue | Rejected — use trade/refine loop |

---

## Next USER cert: Stage B (charcoal-short smoke)

```powershell
.\LaunchForgeContinue.cmd
# On map with low charcoal + some hardwood:
Ctrl+Alt+M
Ctrl+Alt+R    # or Ctrl+Alt+G
.\CollectCertLogs.cmd
```

**PASS:** feed shows `--- SMITHING CREW ---` with companion `RefineCharcoal` and ACTION PLAN prep step before craft.

---

## Cert collection

```powershell
$bl = "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord"
Get-Content -LiteralPath "$bl\BlacksmithGuild_ForgeRecommendations.json"
Get-Content -LiteralPath "$bl\BlacksmithGuild_SmithingAdvisory.json"
Get-Content -LiteralPath "$bl\BlacksmithGuild_SmithingSafeAction.json"
Get-Content -LiteralPath "$bl\BlacksmithGuild_Phase1.log" -Tail 220
```

---

## Remaining gates

| Gate | Action |
|------|--------|
| **Stage B USER cert** | Charcoal-short Continue smoke |
| **Stage C refine API** | Map headless RefineCharcoal; disposable save first |
| **006J 1D Path B** | Quit → Forge.cmd → culture Back once |

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` only |
| Remote | ahead of `origin/main` — push when requested |
