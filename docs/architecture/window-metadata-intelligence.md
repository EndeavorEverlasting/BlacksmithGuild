# Window metadata intelligence

## Decision

The Blacksmith Guild treats launcher and game windows as state-bearing objects, not pictures and not unnamed click targets.

The current best strategy is:

```text
exact learned fingerprint
  -> tracked metadata identity
  -> launch-context intent
  -> dependency-version prediction
  -> one-time S1/S2 delta discovery
  -> image or manual diagnostic only
```

A screenshot can explain what the operator saw, but the runtime algorithm should prefer process, PID, HWND, title, class, Win32 child text, UI Automation metadata, module dependency metadata, and the frozen launch context.

## Why the old loop failed

The repository accumulated several useful mechanisms at different times:

- launcher PLAY and CONTINUE discovery;
- S1/S2 PID and window snapshots;
- confidence scoring;
- frozen PID and HWND selection;
- Safe Mode recognition;
- UI Automation lookup for `CAUTION`, `Confirm`, and `No`.

Agents could still choose an older mechanism because no single registry stated which window existed, which names belonged to it, which action was legal, and which fallback was allowed. The same known window could therefore be rediscovered through repeated coordinate selection or another PLAY-versus-CONTINUE loop.

The window-intelligence layer makes that ordering executable.

## Canonical identity registry

The tracked registry is:

```text
.tbg/harness/window-identities.registry.json
```

Each identity owns:

- canonical ID;
- human name;
- historical and alternate names;
- expected process names;
- title patterns;
- semantic text patterns;
- expected control names;
- dependency conditions;
- extraction rules;
- action policy;
- action confidence and direct-signal requirements;
- forbidden fallbacks.

A developer may change visible wording without erasing the canonical identity. A high-confidence new wording becomes a local alias attached to the same identity.

## Local learned alias cache

The ignored cache is:

```text
.local/tbg-window-intelligence/learned-window-aliases.json
```

The cache stores:

- fingerprint hash;
- canonical identity ID;
- registry version;
- normalized title;
- class name;
- process name;
- control names;
- first-seen time;
- last-seen time;
- hit count;
- learning source.

The cache accelerates recognition. It does not override tracked action policy. A registry version change requires the cached identity to be revalidated before it retains action authority.

## Fingerprint

The fingerprint is derived from stable metadata rather than pixels:

```text
process name
+ normalized top-level title
+ Win32 class
+ named UI Automation controls
+ normalized semantic text
```

The current HWND is action evidence but is not treated as a permanent alias because handles change between runs.

## The screenshot-derived identity

The supplied screenshot is represented by the fixture:

```text
.tbg/harness/fixtures/window-intelligence/dependency-version-caution.fixture.json
```

The semantic identity is:

```text
bannerlord.dependency-version-caution
```

The parsed content is:

| Dependency | Expected | Current |
|---|---|---|
| Native | 1.4.6.0 | 1.4.7.117484 |
| SandBoxCore | 1.4.6.0 | 1.4.7.117484 |
| Sandbox | 1.4.6.0 | 1.4.7.117484 |
| StoryMode | 1.4.6.0 | 1.4.7.117484 |

The modal offers `Cancel` and `Confirm`. The registered action is `confirm_dependency_version_caution`. The harness may invoke `Confirm` automatically only when the direct modal text or control, the exact `Confirm` control, and the dependency mismatch are all present.

A module-version mismatch can be predicted before the modal appears by comparing:

```text
Module/BlacksmithGuild/SubModule.xml
```

with installed module metadata under:

```text
<BannerlordRoot>/Modules/<ModuleId>/SubModule.xml
```

Prediction reduces reaction time but does not authorize an action before the modal is directly observed.

## PLAY versus CONTINUE

`launcher-window-context.json` is the sole launch-intent authority.

```text
launchIntent=play
launchIntent=continue
```

Window intelligence does not guess the intent from stale logs, a screenshot, the presence of a save, or the current button layout. The current frozen-context launcher path owns that decision. A spawned Singleplayer host is a terminal launcher handoff and must never be rescored as a launcher menu.

## Automatic watcher

`Ensure-TbgLauncherWindowContext` starts a short-lived watcher during `LaunchSetup`:

```text
scripts/tbg/Invoke-TbgWindowIntelligence.ps1
```

Default behavior:

- 100 millisecond polling;
- 90 second bounded lifetime;
- exact process targeting from the launcher context;
- UI Automation named-control invocation first;
- keyboard fallback only with foreground authority;
- one action lease per fingerprint and action;
- syntactic-English events and reports;
- universal state-journal observation when available.

The watcher can react to a known modal before an operator moves the pointer, while still binding the action to the exact matching window.

## First-seen discovery

An unknown window is never clicked automatically.

The existing fast protocol becomes the discovery fallback:

1. capture S1 before launch or transition;
2. capture S2 after the new window appears;
3. compare PIDs, titles, HWNDs, classes, rectangles, controls, and text;
4. write a learning candidate;
5. assign the candidate to a canonical identity;
6. reuse the cached fingerprint on later runs.

This means the delta protocol is paid once per genuinely new identity instead of repeated for every known run.

## Commands

Inspect current relevant windows without acting:

```powershell
.\ForgeWindowIntel.cmd scan -Mode observe
```

Run the bounded automatic watcher:

```powershell
.\ForgeWindowIntel.cmd watch -Mode auto -AllowKnownActions -DurationSeconds 90
```

Display the latest classification:

```powershell
.\ForgeWindowIntel.cmd status
```

Explicitly assign an observed unknown fingerprint to a tracked identity:

```powershell
.\ForgeWindowIntel.cmd learn -IdentityId bannerlord.dependency-version-caution
```

## Artifacts

```text
artifacts/latest/window-intelligence/window-intelligence.result.json
artifacts/latest/window-intelligence/window-intelligence.report.md
artifacts/latest/window-intelligence/window-intelligence.events.jsonl
artifacts/latest/window-intelligence/window-intelligence.progress.log
artifacts/latest/window-intelligence/window-intelligence.handoff.md
artifacts/latest/window-intelligence/window-intelligence.learning-candidates.json
```

## Proof boundary

Recognition proves that metadata matched a registered identity. An action record proves that the harness dispatched an action against the matching HWND. Neither proves that the game accepted the action.

Launcher handoff remains distinct from:

```text
campaign readiness
command acknowledgement
movement
arrival
buy or sell delta
live product success
```

Process-memory scraping is not part of this design. Image and OCR fallback remain diagnostic because the current known modal surfaces already expose enough UI Automation and module metadata to support a safer primary strategy.
