# BlacksmithGuild — Post-006H Handoff

## Repo

| Field        | Value                                                        |
| ------------ | ------------------------------------------------------------ |
| Path         | `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild` |
| Remote       | `https://github.com/EndeavorEverlasting/BlacksmithGuild.git` |
| Branch       | `main`                                                       |
| Commit       | `1cddb09`                                                    |
| Version      | `v0.0.11`                                                    |
| Open PRs     | None                                                         |
| Working tree | Clean                                                        |

## Milestone achieved

Zero-click bootstrap funnel LIVE CERT PASS on 2026-06-19.

```text
Forge.cmd
→ auto PLAY
→ SandBoxNewGame
→ intro skip
→ character creation
→ 6 narrative menus auto-advanced
→ BannerEditor
→ ClanNaming
→ Review
→ Options
→ campaign map
→ TBG READY
```

User checkpoint:
Summer 1, 1084, map near Danustica. Screenshot-confirmed.

## Sprint closure status

| Sprint                            | Result                            |
| --------------------------------- | --------------------------------- |
| 006E Path A — Forge.cmd bootstrap | LIVE CERT PASS                    |
| 006H — narrative stall recovery   | LIVE CERT PASS                    |
| 006F                              | FAIL — superseded by 006H         |
| 006G                              | FAIL — superseded by 006H         |
| 003C Continue path                | PASS, prior cert                  |
| 006E Path B — ForgeContinue.cmd   | PENDING — optional regression     |
| 006A/B live cert                  | Still pending in sequencing table |
| 005E                              | Next feature, not started         |

## Key code from 006H

Do not revert this without direct runtime evidence.

### `src/BlacksmithGuild/DevTools/QuickStart/CharacterCreationReflection.cs`

Important shipped behaviors:

* `GetStringId` uses field-first lookup for `StringId` on v1.4.6 `NarrativeMenu` and `NarrativeMenuOption`.
* `IsCurrentMenuSelected` uses `ReferenceEquals` on `Dictionary<NarrativeMenu, NarrativeMenuOption>` keys.
* `StartNarrativeStage()` runs once.
* Culture gate runs before narrative automation.
* Narrative recovery ladder:

  1. `TrySwitchToNextMenu`
  2. manual `OutputMenuId` / `CurrentMenu`
  3. clear stale selected option
  4. re-select valid option

### `src/BlacksmithGuild/DevTools/QuickStart/AutoCharacterCreationPatches.cs`

Important shipped behavior:

* `ManagerNextStagePostfix` resolves `CharacterCreationState` from `manager._state`.

## Live cert evidence

Analyzed outputs:

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log
```

PASS session:
2026-06-19 00:26:29–00:26:43

Key lines:

```text
[TBG QUICKSTART] narrative stage initialized
[TBG QUICKSTART] narrative auto-selected menu=narrative_parent_menu option=empire_lanlord_option (suitable=6)
[TBG QUICKSTART] narrative advanced to next menu (TrySwitchToNextMenu)
```

Then childhood, education, youth, adulthood, and age-selection narrative menus advanced.

```text
[TBG QUICKSTART] transition: CharacterCreation(NarrativeStage) -> BannerEditor -> ClanNaming -> Review -> Options
[TBG QUICKSTART] culture auto-selected: Empire (count=6)
TBG READY: campaign map ready. Press F8 for commands.
[TBG QUICKSTART] setup complete; handing off to map readiness gate.
```

Must not regress to:

```text
menu=NarrativeMenu option=NarrativeMenuOption
selectedCount=1 switchToNextMenu=false
5s stall at CharacterCreationNarrativeStage
```

## Known gaps

| Gap                           | Status                                                                             |
| ----------------------------- | ---------------------------------------------------------------------------------- |
| ForgeContinue.cmd / Path B    | Not re-certified post-006H. Run once for daily-loop confidence.                    |
| Tutorial skip                 | Out of scope. Map reached, but tutorial may still trigger.                         |
| Profile-aware narrative picks | Not implemented. Current behavior selects first valid option.                      |
| Culture log after narrative   | Ordering quirk. Did not block PASS.                                                |
| Culture Back cutscene replay  | **Fixed in 006I** — live cert pending ([sprint-006i-live-results.md](../sprint-006i-live-results.md)) |
| Pause-menu quit loading loop  | **Fixed in 006I** — live cert pending ([sprint-006i-live-results.md](../sprint-006i-live-results.md)) |
| VideoPlaybackState patch      | Fails on v1.4.6. Non-blocking because intro skip still works through another path. |
| Story Mode                    | Still blocked.                                                                     |
| 006A/B live cert              | Still pending in sequencing table.                                                 |

## Risks for next work

| Risk                      | Notes                                                                                 |
| ------------------------- | ------------------------------------------------------------------------------------- |
| 005E scope creep          | No plan file exists yet. Must scope from existing forge/economics code before coding. |
| Continue path regression  | Untested since narrative fix. Recommend `ForgeContinue.cmd` once.                     |
| Disposable save pollution | Bootstrap creates fresh campaigns. Daily loop should use dev save.                    |

## Next feature gate

Next feature is:

```text
005E — crafting orders + inventory in forge economics; doctrine tuning on real candidates
```

Before coding 005E:

1. Read existing forge/economics code.
2. Identify current seams and shipped behavior.
3. Create a plan file under `docs/plans/005e-*.plan.md`.
4. Wait for plan approval.

Suggested files to inspect before 005E planning:

* `src/BlacksmithGuild/ForgeAdvisor.cs`
* `src/BlacksmithGuild/ForgeDoctrine.cs`
* `src/BlacksmithGuild/MaterialReservePolicy.cs`
* `src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs`
* any existing treasury, candidate, recipe, or doctrine code under `src/BlacksmithGuild/`

## Daily workflows

| Workflow       | Command                                  | Status                       |
| -------------- | ---------------------------------------- | ---------------------------- |
| Bootstrap cert | `Forge.cmd`                              | PASS                         |
| Daily dev loop | `ForgeContinue.cmd`                      | Pending post-006H regression |
| Watch mode     | `ForgeWatch.cmd` or `.\forge.ps1 -Watch` | Available                    |

## Git hygiene

* This checkpoint is docs-only.
* Do not commit unless explicitly instructed.
* DLLs in `Module/bin` are gitignored.
* Never force-push `main`.
