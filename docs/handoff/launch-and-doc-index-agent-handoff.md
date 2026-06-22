# Agent Handoff — Launch, Docs Index, and 006B Continuation

**Copy-paste this entire document to any AI agent working on BlacksmithGuild.**

---

## Repo

- **Path:** `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild`
- **Remote:** `https://github.com/EndeavorEverlasting/BlacksmithGuild`
- **Active feature branch:** `feat/006b-map-trade-cohesion` — [PR #4](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/4) (OPEN, mergeable)
- **Main includes:** Launch Control (PR #3 merged), auto-travel, tavern hero, character profiles
- **Open unrelated PR:** PR #2 (identity schema docs only)

---

## Human doc entrypoints (do not re-derive launch steps)

| Doc | Purpose |
|-----|---------|
| **[docs/launch-and-doc-index.md](launch-and-doc-index.md)** | **Canonical launch + doc index** — read first |
| [docs/player-command-guide.md](player-command-guide.md) | Hotkeys, inbox commands, 006B automation |
| [docs/dev-disposable-save.md](dev-disposable-save.md) | Forge.cmd vs ForgeContinue.cmd |
| [tools/LaunchControl/README.md](../tools/LaunchControl/README.md) | Desktop/Start Menu installer |

---

## How to launch (three paths)

```powershell
# Daily dev (most common)
.\ForgeContinue.cmd

# Fresh bootstrap / cert
.\Forge.cmd

# Desktop menu (after one-time Install-LaunchControl.ps1)
.\tools\LaunchControl\Launch-Control.cmd
```

**Ready gate:** F7 → `campaignReady: true` before inbox commands.

---

## After launch — 006B autonomous loop

```powershell
.\forge.ps1 -Command RunAutonomousGuildLoopNow -Wait
.\ExportTbgEvidence.cmd
```

**Primary JSON:** `docs/evidence/latest/BlacksmithGuild_AutonomousGuildLoop.json`

Full 006B module/command reference: [docs/handoff/006b-map-trade-cohesion-agent-handoff.md](006b-map-trade-cohesion-agent-handoff.md)

---

## Known gaps (006B — honest)

| Gap | Status | 006C target |
|-----|--------|-------------|
| Vanilla town buy/sell | Probe only; `VisibleTradeDriverUnavailable` | Prove gold/inventory deltas |
| Pack-animal capacity | Probe → false in JSON | BuyPackAnimal mission |
| Weapon smelt | Probe → false; no fake smelt | Headless smelt API |
| Multi-cycle rinse-repeat | `guildLoopMaxCyclesPerCommand = 1` | Bounded auto-loop |
| Live cert | USER on disposable save | Rubric in 006b handoff |

---

## JSON paths to analyze

| File | When |
|------|------|
| `BlacksmithGuild_AutonomousGuildLoop.json` | After `RunAutonomousGuildLoopNow` |
| `BlacksmithGuild_CohesionOpportunities.json` | After `AnalyzeCohesionOpportunities` |
| `BlacksmithGuild_MapTradeCert.json` | After `RunAutonomousVisibleTradeRouteNow` |
| `BlacksmithGuild_Status.json` | F7 readiness |
| `BlacksmithGuild_LaunchControlLastRun.json` | After Launch Control use |
| `docs/evidence/latest/README.md` | After `ExportTbgEvidence.cmd` |

---

## Risks

- **Vanilla trade driver** — highest risk; movement/cohesion/forge handoff may PASS while trade blocks
- **Inbox commands** — blocked until campaign map ready; stale ack files caused false PASS (fixed in Send-ForgeCommand)
- **Mutation commands** — disposable save only; risky gate applies to guild loop, cohesion move, map trade route

---

## Repo hygiene checklist

1. `git status` clean before push
2. `dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release` passes
3. Feature work on `feat/006b-map-trade-cohesion`; merge PR #4 to `main` after USER live cert
4. Do not commit runtime JSON at repo root (`.gitignore` covers them; evidence mirror under `docs/evidence/latest/`)

---

## Do NOT

- Teleport parties, direct gold/item mutation, fake smelt, unbounded loops, forced combat
- Conflate `RunGuildLoopNow` (Ctrl+Alt+G advisory) with `RunAutonomousGuildLoopNow` (mutation FSM)
- Re-document launch steps in chat when [docs/launch-and-doc-index.md](launch-and-doc-index.md) exists — point user there

---

## Build

```powershell
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
```

---

## One-line cheat sheet

```text
Launch: ForgeContinue.cmd | Forge.cmd | tools/LaunchControl/Launch-Control.cmd
Docs:   docs/launch-and-doc-index.md
Loop:   RunAutonomousGuildLoopNow -Wait → ExportTbgEvidence.cmd
Agent:  docs/handoff/006b-map-trade-cohesion-agent-handoff.md
PR:     feat/006b-map-trade-cohesion → PR #4
```
