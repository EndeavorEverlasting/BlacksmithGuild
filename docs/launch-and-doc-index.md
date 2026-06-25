# Launch Guide and Documentation Index

**Start here** if you are asking: *How do I launch? Where is that documented?*

Repo root: `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild`

---

## How to launch (pick one path)

### Path A — Daily dev (most common)

```powershell
.\ForgeContinue.cmd
```

- Auto-clicks launcher **CONTINUE**, loads dev save, lands on campaign map
- Wait for **F7** → `campaignReady: true` (or `Blacksmith Guild — Ready:` / legacy `TBG READY` in Phase1)
- See also: [dev-disposable-save.md](dev-disposable-save.md), [player-command-guide.md](player-command-guide.md) § Play now

### Path B — Fresh bootstrap / cert

```powershell
.\Forge.cmd
```

- Auto-clicks launcher **PLAY**, New Campaign → SandBox, character build, map
- Deep pipeline: [forge-zero-click-contract.md](forge-zero-click-contract.md)

### Path C — Desktop / Start Menu (Launch Control)

One-time install:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/LaunchControl/Install-LaunchControl.ps1
```

Then double-click **The Blacksmith Guild - Launch Control**, or:

```powershell
.\tools\LaunchControl\Launch-Control.cmd
```

Menu wraps **New** → `Forge.cmd`, **Continue** → `ForgeContinue.cmd`. Details: [../tools/LaunchControl/README.md](../tools/LaunchControl/README.md)

---

## After launch — autonomous guild loop (006B)

Only when **campaign map is ready** (`F7` → `campaignReady: true`):

```powershell
.\forge.ps1 -Command RunAutonomousGuildLoopNow -Wait
.\ExportTbgEvidence.cmd
```

Primary JSON: `docs/evidence/latest/BlacksmithGuild_AutonomousGuildLoop.json`

Commands and hotkeys: [automation-playbook.md](automation-playbook.md) and [player-command-guide.md](player-command-guide.md).

---

## Documentation index (self-serve)

| Question | Read this file |
|----------|----------------|
| How do I launch? Play vs Continue? | [player-command-guide.md](player-command-guide.md) § Play now + Launch Control |
| `Forge.cmd` vs `ForgeContinue.cmd` | [dev-disposable-save.md](dev-disposable-save.md) |
| Zero-click pipeline internals | [forge-zero-click-contract.md](forge-zero-click-contract.md) |
| Desktop shortcut / Launch Control | [../tools/LaunchControl/README.md](../tools/LaunchControl/README.md) |
| **Automation explained** | [automation-playbook.md](automation-playbook.md) |
| Hotkeys (F7, Ctrl+Alt+M, etc.) | [player-command-guide.md](player-command-guide.md) + [in-game-surfaces.md](in-game-surfaces.md) |
| All dev command names | [../scripts/dev-command-names.ps1](../scripts/dev-command-names.ps1) |
| Cohesion / map trade / guild loop | [player-command-guide.md](player-command-guide.md) (bottom sections) |
| Copy-paste prompt for another AI agent | [handoff/006b-map-trade-cohesion-agent-handoff.md](handoff/006b-map-trade-cohesion-agent-handoff.md) |
| Sprint 006B scope + known gaps | [plans/006b-map-trade-cohesion.plan.md](plans/006b-map-trade-cohesion.plan.md) |
| Sprint 006C roadmap | [plans/006c-assistive-guild-loop.plan.md](plans/006c-assistive-guild-loop.plan.md) |
| Golden path / Phase1 grep fails on "Ready" | [conventions/em-dashes-and-log-grep.md](conventions/em-dashes-and-log-grep.md) |
| Runtime-state sprint / multi-agent | [handoff/blacksmithguild-agent-coordination.md](handoff/blacksmithguild-agent-coordination.md) |
| F7 control index (open/successful) | [control/indexes/f7-recovery-index.md](control/indexes/f7-recovery-index.md) |
| F7 launch commands / Layer A vs B | [handoff/agent-launch-and-load-playbook.md](handoff/agent-launch-and-load-playbook.md) |
| Build / install mod | [../README.md](../README.md) § Two environments |
| Export JSON evidence | `.\ExportTbgEvidence.cmd` → [evidence/latest/README.md](evidence/latest/README.md) |
| Sprint history | [../README.md](../README.md) sprint table |

### Human “start here”

[player-command-guide.md](player-command-guide.md) — *What do I press? What command do I run? What JSON should I look at?*

### AI agent “start here”

[handoff/006b-map-trade-cohesion-agent-handoff.md](handoff/006b-map-trade-cohesion-agent-handoff.md)

---

## One-line cheat sheet

```text
Launch:   ForgeContinue.cmd (daily) | Forge.cmd (new) | tools/LaunchControl/Launch-Control.cmd
Ready:    F7 → campaignReady: true
Loop:     forge.ps1 -Command RunAutonomousGuildLoopNow -Wait
Evidence: ExportTbgEvidence.cmd → docs/evidence/latest/
Docs:     docs/automation-playbook.md | docs/launch-and-doc-index.md | docs/handoff/006b-map-trade-cohesion-agent-handoff.md (AI)
```
