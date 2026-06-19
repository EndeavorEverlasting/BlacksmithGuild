# Sprint 006I-2 Handoff - BlacksmithGuild Bannerlord Mod

## Repo state

| Field | Value |
|-------|-------|
| Path | `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild` |
| Remote | `https://github.com/EndeavorEverlasting/BlacksmithGuild.git` |
| Branch | `main` |
| HEAD | `6fb5825` — Fix creation-phase intro skip loop and launcher handoff timeout (006I-2) |
| Version | `v0.0.11` |
| Remote sync | 4 commits ahead of `origin/main` — public GitHub may look stale; treat local git as authoritative |
| Open PRs | None |
| Working tree | Clean at implementation commit |

## Sprint status

| Sprint | Status |
|--------|--------|
| 006H | LIVE CERT PASS. Do not regress narrative/bootstrap. |
| 006I hotfix | Partial PASS. Disarm fix and count=1 OnActivate skip confirmed. |
| 006I-2 | SHIPPED. Live cert PENDING. |
| 005E economics | NEXT. No plan file yet. Gated on 006I cert. |

## What shipped in `6fb5825`

### 1. Creation gate

**File:** `src/BlacksmithGuild/DevTools/QuickStart/SandboxCampaignIntroSkip.cs`

- `IsCharacterCreationBootstrapActive()` blocks OnActivate skip while character creation bootstrap is active.
- `CleanAndPushStatePostfix` blocks intro skip when `CampaignSetupStateTracker.Phase == CharacterCreation`.
- **Purpose:** prevent Options → Culture/Narrative restart caused by CleanAndPushState count=2 during character creation.

### 2. Launcher handoff

**File:** `scripts/launcher-auto-nav.ps1`

- 3-poll stable Bannerlord.exe handoff.
- Immediate handoff after crash reporter No.
- Crash reporter text heuristic disabled when game main window exists.
- 180s timeout on Safe Mode/crash path.
- `handoff: <reason>` logging.

### 3. Docs (this checkpoint cycle)

- `docs/sprint-006i-live-results.md`
- `docs/plans/006i-2-creation-skip-gate.plan.md`
- `NEXT_STEPS.md`
- `docs/checkpoints/post-006i-2-handoff.md`

## Build status

- `forge.ps1` PASS
- Release DLL installed to Bannerlord Modules
- Live cert Paths A/B/C **not yet run**

## Live cert protocol

**Precondition:** Close Bannerlord completely. Confirm no `Bannerlord.exe` or Launcher processes remain.

**Run:**

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
Forge.cmd
```

**Analyze:**

```powershell
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log" -Tail 80
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log" -Tail 30
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json" -Tail 60
```

### Path table

| Path | Cert action | PASS condition |
|------|-------------|----------------|
| Forge exit | Forge.cmd completes launcher handoff | Launch.log has `handoff:` reason, no timeout |
| A | Full bootstrap to map | count=1 only, narrative advances, TBG READY |
| B | Culture stage Back | No full campaign_intro replay |
| C | Pause then Quit | Clean exit from bootstrap/map |

### PASS signatures

- Launch.log contains `handoff:`
- Phase1.log contains `intro skip: campaign video via OnActivate (count=1)`
- Phase1.log contains `TBG READY: campaign map ready`
- No launcher timeout
- No forward-bootstrap `CleanAndPushState (count=2)` before TBG READY
- No Options → Culture narrative restart

On Path B only: count=2+ after culture Back is expected.

### FAIL signatures

- `launcher-auto-nav timed out`
- `intro skip: campaign video via CleanAndPushState (count=2)` during forward bootstrap before TBG READY
- Options → Culture narrative restart
- `bootstrap disarmed: returned to main menu` between auto-select and intro skip

## Known gaps

| Gap | Status |
|-----|--------|
| Path A full bootstrap cert | **PENDING** — user must run `Forge.cmd` |
| Path B culture Back regression | **PENDING** — 006I culture-back fix never re-tested; blocked by count=2 loop until 006I-2 |
| Path C quit teardown | **PENDING** |
| Launcher handoff | **PENDING** |
| ForgeContinue.cmd | Optional regression; not re-run |
| Launcher false positives | Mitigated; UIA can still flake by GPU/driver/window timing |
| Version bump | Still `v0.0.11` — bump only after cert PASS |
| Tutorial skip | Out of scope |
| Profile-aware narrative picks | Not implemented |

## Risks for next work

| Risk | Notes |
|------|-------|
| Stale GitHub context | Remote is 4 commits behind local; do not overwrite local state from stale remote |
| 005E scope creep | No plan file exists; must scope before coding |
| Path B never validated | Culture-back fix shipped in 006I but blocked by loop; first real test is post-006I-2 |
| Continue path regression | `ForgeContinue.cmd` not re-run since 006H |

## 005E gate

Next feature:

```text
005E — crafting orders + inventory in forge economics; doctrine tuning on real candidates
```

**Do not start 005E until 006I live cert PASS.**

Before coding 005E:

1. Read existing forge/economics code under `src/BlacksmithGuild/`.
2. Create `docs/plans/005e-*.plan.md`.
3. Wait for plan approval.

Suggested files to inspect:

- `src/BlacksmithGuild/ForgeAdvisor.cs`
- `src/BlacksmithGuild/ForgeDoctrine.cs`
- `src/BlacksmithGuild/MaterialReservePolicy.cs`
- `src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs`

## Git hygiene

- Docs-only checkpoint edits; implementation already committed at `6fb5825`.
- Do not commit unless user requests.
- Do not push unless user requests.
- Never force-push `main`.
- DLLs in `Module/bin` are gitignored.
