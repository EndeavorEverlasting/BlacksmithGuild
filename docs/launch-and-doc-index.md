# Launch Guide and Documentation Index

**Start here** if you are asking: *How do I launch? Where is that documented?*

Repo root: `<path-to-BlacksmithGuild>`

---

## First test after cloning `main`

Before launching Bannerlord or testing hotkeys, run the safe no-game first test:

```powershell
git status --short
git branch --show-current
git log --oneline --decorate -5
dotnet --version
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Debug
git diff --check
```

Full guide: [first-test-after-clone.md](first-test-after-clone.md)

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

## After launch — click-first command wrappers

Prefer root `.cmd` files for repeat human/operator tests. Do not ask the user to type `forge.ps1 -Command ...` when an equivalent root wrapper exists.

Common wrappers:

```powershell
.\Run-MarketIntel.cmd
.\Run-FoodAdvisory.cmd
.\Run-HorseMarketIntel.cmd
.\Run-GuildLoopAdvisory.cmd
.\Run-AutonomousGuildLoop.cmd
.\Run-CohesionAnalyze.cmd
.\Run-CohesionMove.cmd
.\Run-AutoTravelChoices.cmd
.\Run-TickCostProfilerSmoke.cmd
.\Run-ExportEvidence.cmd
```

Full matrix and agent rules: [clickable-command-surface.md](clickable-command-surface.md)

Implementation roadmap: [plans/click-first-command-surface.plan.md](plans/click-first-command-surface.plan.md)

---

## After launch — autonomous guild loop (006B)

Only when **campaign map is ready** (`F7` → `campaignReady: true`):

```powershell
.\Run-AutonomousGuildLoop.cmd
.\Run-ExportEvidence.cmd
```

Primary JSON: `docs/evidence/latest/BlacksmithGuild_AutonomousGuildLoop.json`

Commands and hotkeys: [automation-playbook.md](automation-playbook.md), [player-command-guide.md](player-command-guide.md), and [clickable-command-surface.md](clickable-command-surface.md).

---

## Food check

Food now has a direct read-only command:

```powershell
.\Run-FoodAdvisory.cmd
.\Run-ExportEvidence.cmd
```

Underlying inbox command:

```powershell
.\forge.ps1 -Command AnalyzeFood -Wait
```

Inspect `BlacksmithGuild_FoodAdvisory.json` for food runway, diversity, forecast, candidate planning, read-only market stock, market matches, execution gate, and `buyFoodSupported`. Automated food acquisition is not active yet.

---

## Documentation index (self-serve)

| Question | Read this file |
|----------|----------------|
| What should I run first after cloning `main`? | [first-test-after-clone.md](first-test-after-clone.md) |
| How do I launch? Play vs Continue? | [player-command-guide.md](player-command-guide.md) § Play now + Launch Control |
| Which root `.cmd` file should a human click? | [clickable-command-surface.md](clickable-command-surface.md) |
| What is the plan to finish the root CMD / click wrapper surface? | [plans/click-first-command-surface.plan.md](plans/click-first-command-surface.plan.md) |
| Food status / runway / provisioning gap? | [clickable-command-surface.md](clickable-command-surface.md) § Food-specific note |
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
| Export JSON evidence | `.\Run-ExportEvidence.cmd` → [evidence/latest/README.md](evidence/latest/README.md) |
| Sprint history | [../README.md](../README.md) sprint table |

### Human “start here”

[player-command-guide.md](player-command-guide.md) — *What do I press? What command do I run? What JSON should I look at?*

### AI agent “start here”

[clickable-command-surface.md](clickable-command-surface.md), [plans/click-first-command-surface.plan.md](plans/click-first-command-surface.plan.md), then [handoff/006b-map-trade-cohesion-agent-handoff.md](handoff/006b-map-trade-cohesion-agent-handoff.md)

---

## One-line cheat sheet

```text
First:    docs/first-test-after-clone.md
Launch:   ForgeContinue.cmd (daily) | Forge.cmd (new) | tools/LaunchControl/Launch-Control.cmd
Ready:    F7 → campaignReady: true
Click:    Run-MarketIntel.cmd | Run-FoodAdvisory.cmd | Run-HorseMarketIntel.cmd | Run-GuildLoopAdvisory.cmd
Plan:     docs/plans/click-first-command-surface.plan.md
Evidence: Run-ExportEvidence.cmd → docs/evidence/latest/
Docs:     docs/clickable-command-surface.md | docs/automation-playbook.md | docs/launch-and-doc-index.md
```
