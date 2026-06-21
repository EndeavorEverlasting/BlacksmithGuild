# Handoff — Pre–Blacksmith Automation (Launcher cert closed)

**Last updated:** 2026-06-21  
**Authority:** User ruling — Path A passed; Path B waived (obsolete); Continue load + quit passed; Path C passed.

Copy-paste this document to the next AI agent.

---

## Repo

| Field | Value |
|-------|-------|
| Root | [`C:/Users/Cheex/Desktop/dev/Mods/Bannerlord/BlacksmithGuild`](C:/Users/Cheex/Desktop/dev/Mods/Bannerlord/BlacksmithGuild) |
| Branch | `main` (clean) |
| HEAD | `9780797` (Path C cert docs) + fix commits `286df1e`, `f318f3a` |
| Remote | 53 commits ahead — push only when user asks |

---

## Launcher / bootstrap cert matrix — **CLOSED**

These are **named test scenarios** (not file paths). All required launcher gates are **USER PASS** or **WAIVED**.

| Name | Plain English | Entry | Status |
|------|---------------|-------|--------|
| **Path A** | Zero-click new campaign → map | [`Forge.cmd`](../../Forge.cmd) | **USER PASS** (2026-06-20) — `TBG READY`, PLAY click |
| **Path B** | Culture Back does not replay intro | [`Forge.cmd`](../../Forge.cmd) → Back at culture | **WAIVED / OBSOLETE** — auto-skip loads past character creation; guard remains in code but no cert required |
| **Path C-play** | Quit to menu stays idle (play) | [`Forge.cmd`](../../Forge.cmd) → map → Pause → Quit | **USER PASS** (2026-06-21) — `session ended` |
| **Path C-continue** | Quit to menu stays idle (continue) | [`LaunchForgeContinue.cmd`](../../LaunchForgeContinue.cmd) → map → Quit | **USER PASS** (2026-06-21) — `forward launch already completed` |
| **Continue load** | Launcher Continue → map (Module Mismatch) | [`LaunchForgeContinue.cmd`](../../LaunchForgeContinue.cmd) | **USER PASS** (2026-06-20 + 2026-06-21 user confirm) |
| **Continue quit** | Same as Path C-continue | — | **USER PASS** |

**006I / 006J launcher gate:** **CLOSED.** Do not block 005E or smithing work on Path B or stale 006J partials.

Optional only: Layer A `handoff:` line in Launch.log — nice-to-have, not a blocker.

---

## Smithing cert queue (before 005E automation expansion)

Work **top to bottom**. Tier 3 mutation already passed; remaining items are lightweight or advisory.

| # | Cert | Tier | Entry / trigger | PASS criteria | Status |
|---|------|------|-----------------|---------------|--------|
| 1 | **Stage C charcoal refine** | 3 | [`RunStageCCharcoalCert.cmd`](../../RunStageCCharcoalCert.cmd) | Phase1 `RefineCharcoal` charcoal N→N+1, `refineCount=1` | **USER PASS** 2026-06-20 |
| 2 | **Track 2A real forge rank** | 1 | **Ctrl+Alt+M** then **Ctrl+Alt+R** on map | JSON `source=real`, `fallbackUsed=false` | **USER PASS** 2026-06-20 |
| 3 | **Market intel** | 1 | **Ctrl+Alt+M** | ACTION PLAN, BUY@NEAREST, `MarketIntel.json` | **USER PASS** 2026-06-20 |
| 4 | **Stage B smithing crew advisory** | 1 | **Ctrl+Alt+R** or **Ctrl+Alt+G** when charcoal low | Phase1 shows SMITHING CREW + prep; `SmithingAdvisory.json` | Code shipped — **quick smoke recommended** before first 005E automation commit |
| 5 | **Track 2B FORGE MATERIALS** | 1 | **Ctrl+Alt+M** | `--- FORGE MATERIALS ---` section in report | Code shipped — optional visual |
| 6 | **Guild loop report** | 1 | **Ctrl+Alt+G** | `GuildLoopReport.json` + coherent combined advisory | Code shipped — optional smoke |

**Re-cert Stage C only** if `SmithingRefineApi` / `SmithingSafeActionService` mutation code changes.

After rows 4–6 smoke (or explicit user skip), proceed to **[005E smithing posse automation](../plans/005e-smithing-posse-stamina-output.plan.md)** implementation.

---

## 005E — next engineering sprint

**Unblocked** as of 2026-06-21 (launcher gate closed).

Goal: coordinated forge crew — who acts, what action, when to rest, reserve protection. Stage C proved **headless map mutation** works; 005E extends to stamina rotation and multi-hero roles.

Plan: [`docs/plans/005e-smithing-posse-stamina-output.plan.md`](../plans/005e-smithing-posse-stamina-output.plan.md)

---

## Future — travel / party map automation (not started)

**User goal (later):** Watch the hero traverse the campaign map and enact orders — proves the same automation substrate can drive **party movement and map-level will**, not just inbox commands on a static map.

This builds on:

- Map-ready gate (`TBG READY`, `GameSessionState.IsCampaignMapReady`)
- Campaign tick / daily tick hooks
- Dev command bus + evidence JSON pattern
- Stage C proof that game APIs can be invoked without Gauntlet clicks

**Not in scope** until 005E smithing automation slice is stable. Track informally as **party travel automation** — no plan file yet.

---

## Runtime log paths

| Artifact | Path |
|----------|------|
| Phase1 | `C:/Program Files (x86)/Steam/steamapps/common/Mount & Blade II Bannerlord/BlacksmithGuild_Phase1.log` |
| Launch | `C:/Program Files (x86)/Steam/steamapps/common/Mount & Blade II Bannerlord/BlacksmithGuild_Launch.log` |
| Smithing safe action | `C:/Program Files (x86)/Steam/steamapps/common/Mount & Blade II Bannerlord/BlacksmithGuild_SmithingSafeAction.json` |
| Forge recommendations | `C:/Program Files (x86)/Steam/steamapps/common/Mount & Blade II Bannerlord/BlacksmithGuild_ForgeRecommendations.json` |
| Collect all | [`CollectCertLogs.cmd`](../../CollectCertLogs.cmd) from repo root |

---

## Scope lock

- No Path B cert work unless auto-skip is disabled by user
- No launcher rewrite unless regression
- No push unless user asks
- No travel automation until user directs after 005E slice
