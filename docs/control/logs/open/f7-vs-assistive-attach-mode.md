# F7 Cert Mode vs Assistive Attach Mode

**Owner:** Agent C — External State Classifier / Window Safety / F7 Runner  
**Branch:** `fix/f7-gate-stability`

---

## Product framing

Launcher automation was a proving ground for state detection. The product value is **assistive gameplay inside Bannerlord** (smithing, trading, travel, inventory, stamina, market intelligence, smithy workflow, safe actions, skill guidance).

People know how to start the game. The external layer must know **where the player is** and whether a request is safe to route — not force every user through F7 launch purity.

---

## Mode 1: Cert mode (F7 certification — infrastructure / regression)

**Entry:** `run-f7-gate-continue.ps1 -CertTarget continue` (or `play` / `any` per cert matrix)

**Post-pivot posture:** Cert mode is **infrastructure and regression harness** — not the product priority. Old F7 Continue product gate is **closed** @ `205925`. Do not use cert mode as a treadmill seeking legacy MapTransition PASS.

| Rule | Requirement |
|------|-------------|
| Launcher ownership | Runner owns launcher; no user clicks during cert |
| Launch path | `certTarget` must match observed `launchPath` |
| Target mismatch | `targetMismatch=true` is **FAIL** |
| Launch actor | `launchSelectedBy=automation` required for Continue cert |
| Pre-intent spawn | Game running before automation Continue = **contamination** |
| PASS authority | Manifest JSON only (`passFail=PASS`, `exitCode=0`, `stableSeconds>=60`, …) |
| Timeline | `ExternalStateTimeline.json` emitted with `mode=cert` |

Cert mode **must not** be loosened for convenience. Assistive attach is a separate code path.

---

## Mode 2: Assistive attach mode (primary product path)

**Entry:** [`scripts/run-town-to-town-trade-assist-cert.ps1`](../../../scripts/run-town-to-town-trade-assist-cert.ps1) (skeleton; blocked until B probe lands)

| Rule | Requirement |
|------|-------------|
| Manual launch | User may start Bannerlord, click Play or Continue manually |
| Attach | Runner attaches to current legitimate Bannerlord state |
| Manual Play/Continue | **Not contamination** — report `manualLaunchObserved=true`, `assistiveAttach=true` |
| Classification | Expose `classifiedState`, evidence, legal/forbidden actions |
| Clicks | Only when `Test-F7GuardedActionAllowed` passes |
| Timeline | `ExternalStateTimeline.json` with `mode=assistive` |

Use `Get-F7AssistiveAttachResult` in [`f7-launch-contract.ps1`](../../../scripts/f7-launch-contract.ps1). Do **not** call cert contamination helpers for attach workflows.

---

## Manual Play / Continue handling

| Scenario | Cert mode | Assistive attach |
|----------|-----------|------------------|
| User clicks Continue before automation | `contaminated_launch_path`, `targetMismatch=true` | `assistiveAttach=true`, `targetMismatch=false` |
| User clicks Play during Continue cert | `contaminated_launch_path` | Acceptable; classify and attach |
| Automation Continue success | Required for Continue cert PASS | N/A (user may have already continued) |
| Pre-intent game spawn (175909 pattern) | `pre_intent_game_spawn` FAIL | N/A unless attach observes stale spawn attribution |

---

## Wrong-window protection

Before any click or UI mutation:

1. `classifiedState` is known (not `UnknownWindowState` / `UnknownGameSurface` for click actions)
2. Target process is trusted (Bannerlord / TaleWorlds launcher scoped windows)
3. Target `hwnd` recorded in timeline event
4. Window bounds recorded
5. Intended action is in `legalActions` for current state + mode
6. Expected transition recorded
7. Post-action evidence checked (launch verify, state transition)

**Never** click based only on foreground focus or coordinate memory alone.

Coordinate fallback (launcher-auto-nav) is allowed only when fenced by trusted process, known hwnd, known state, known bounds, known action, and post-click validation.

On deny: log `UnknownWindowState`, skip click, route to human or Agent C investigation.

---

## State classifier model

### Process / launcher states

`ProcessClean`, `LauncherOpening`, `LauncherMenu`, `LauncherMenuContinueAvailable`, `LauncherMenuPlayOnly`, `SafeModeDialog`, `CrashReporterDialog`, `HostedSingleplayerWindow`, `StandaloneGameProcess`, `GameGone`, `UnknownWindowState`, `ContaminatedPreIntentSpawn`, `ContaminatedWrongTarget`

### In-game surface states (from Status when fresh)

`GameLoading`, `MainMenu`, `CampaignMapSurface`, `SettlementTownMenu`, `SettlementInterior`, `SmithyScreen`, `MarketTradeScreen`, `InventoryScreen`, `CharacterSkillsScreen`, `ClanPartyScreen`, `KingdomScreen`, `DialogueScreen`, `BattleLoading`, `BattleActive`, `PauseMenu`, `UnknownGameSurface`

Agent B telemetry maps (when Status.json fresh):

| Status fields | Classified state |
|---------------|------------------|
| `readinessSurface=settlement_menu`, `settlementMenuOpen=true` | `SettlementTownMenu` |
| `readinessSurface=map_surface`, `campaignMapSurfaceOpen=true` | `CampaignMapSurface` |
| `readinessSurface=settlement_interior` | `SettlementInterior` |
| `readinessSurface=main_menu` | `MainMenu` |
| `readinessSurface=loading` | `GameLoading` |
| Stale / missing Status | `UnknownGameSurface` (do not guess) |

### Runtime evidence states (derived)

`Phase1Active`, `StatusFresh`, `CanPollFileInbox`, `CampaignReady`, `SessionReady`, surface readiness aliases, smithing/market availability when present in Status.

Pipeline: **snapshot → classify → legal actions → forbidden actions → expected transition → evidence record**

Implementation: [`f7-external-state-classifier.ps1`](../../../scripts/f7-external-state-classifier.ps1)

Schema: [`external-state-timeline-schema.md`](external-state-timeline-schema.md)

---

## Agent routing table

| Signal / state | Owner | Next move |
|----------------|-------|-----------|
| `contaminated_launch_path`, `targetMismatch`, runner poll/classifier defect | **Agent C** | Fix scripts, re-run static gates |
| Process death, StatusFlush, MapTransition, runtime marker crash | **Agent B** | Harden `src/**`, fail-soft |
| Manifest PASS/FAIL, evidence commit, PR gate | **Agent A** | Live cert, git push, PR report |
| Doc drift, terminology, atlas | **Agent D** | Reconcile handoff docs |
| In-game smithing/trading/travel economics | **Product / B** | Gameplay assistance (not C lane) |
| `UnknownWindowState` / `UnknownGameSurface` during assistive request | **Human or C** | Investigate classification gap |

---

## Settlement menu vs old F7 gate (20260623-205925)

Continue cert may reach **settlement town menu** with `campaignReady=true` but `canPollFileInbox=false` and golden path stuck at `MainMenu -> MapTransition`. The old F7 poll gate (`campaignReady AND canPollFileInbox AND mapReadyPass`) never satisfies.

| Layer | Behavior |
|-------|----------|
| F7 cert poll (`run-f7-gate-continue.ps1`) | After `settlement_menu_ready_observed`, wait **15s**; if gate still false → `fail_settlement_menu_semantic_mismatch`, route **Agent B** |
| Launcher nav (`launcher-auto-nav.ps1`) | **45s** launcher selection cap; `LAUNCH_TIMING` evidence; Play-only during Continue cert → `fail_launcher_play_only` |
| Assistive attach | Classify `SettlementTownMenu`; do not weaken cert contamination rules |

Skeleton gameplay cert: `scripts/run-town-to-town-trade-assist-cert.ps1` (expects `AssistiveTownToTownProbe` from Agent B).

**Product PASS spec:** [`town-to-town-trade-assist-cert.md`](town-to-town-trade-assist-cert.md)

Post-`9bdc759`, F7 cert poll fails fast at settlement_menu semantic mismatch (~15s) instead of 361s MapTransition treadmill.

---

## Related docs

- [`town-to-town-trade-assist-cert.md`](town-to-town-trade-assist-cert.md)
- [`f7-agent-mental-model.mmd`](../../handoff/f7-agent-mental-model.mmd)
- [`f7-next-cert-readiness.md`](f7-next-cert-readiness.md)
- [`launcher-foreground-doctrine.md`](../../conventions/launcher-foreground-doctrine.md)
