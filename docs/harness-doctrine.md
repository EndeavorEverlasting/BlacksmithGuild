# Harness Doctrine

**Authority:** repository-wide agent execution contract for `EndeavorEverlasting/BlacksmithGuild`  
**Enforcement:** `.tbg/harness/policies/harness-doctrine.policy.json`, `scripts/tbg/Test-TbgHarnessDoctrine.ps1`, and `AGENTS.md`

## Harness, not prompt

A prompt is one artifact inside the harness. The harness is the tracked operational surface that lets a fresh agent enter the repository, select the correct lane and workflow, avoid known traps, mutate only authorized surfaces, validate the result, preserve evidence, and hand off cleanly.

| Component | Canonical surface |
|---|---|
| Repo agent rules | `AGENTS.md`, `CLAUDE.md` |
| Codebase map | `CODEBASE_MAP.md` |
| Workflow specifications | `.tbg/workflows/*.contract.json` |
| Run context | current chat packets, sprint capsules, runtime-context capsules |
| Artifact registry | `.tbg/harness/e2e-artifact-types.registry.json`, consumer handoffs |
| Validators | `scripts/tbg/Test-*.ps1` and focused contract tests |
| Local hooks and guardrails | repository-owned guardrail or hook surfaces when useful |
| Scoped skills | `.tbg/skills/manifest.json`, `.tbg/skills/*/SKILL.md` |
| Read-only code intelligence | repository-registered code-intelligence workflow |
| English operator reports | `docs/handoff/**`, certification and evidence reports |
| Final handoff compression | `.tbg/workflows/tbg-sprint-capsule.contract.json` |

Do not invent a parallel authority surface when one of these already owns the concern.

## Fresh-agent acceptance

`docs/AI_HARNESS_ENTRYPOINT.md` is the canonical fresh-agent front door and must be discoverable through `.tbg/harness/manifest.json`.

A fresh agent must be able to:

1. inspect the repo rules, doctrine, codebase map, harness manifest, generated-output policy, current Git/PR state, and fresh run context;
2. select one primary skill and the narrowest matching workflow contract;
3. load that workflow's authorities, validators, expected artifacts, freshness source, and proof ceiling;
4. run targeted validation before the applicable composed E2E profile and broader safe checks;
5. produce registry-backed artifacts and an English/operator report without tracking raw runtime output;
6. emit a schema-valid sprint capsule containing exact Git or PR evidence and one next decision.

The harness-doctrine and E2E validators must fail when the entrypoint, manifest registration, generated-output boundary, validator path, artifact path, report path, or handoff path is missing. Prompts may route this sequence, but they cannot replace it.

## Required identity

Every serious writing or mutation sprint must name:

- repo;
- branch or worktree;
- PR or sprint;
- lane;
- owned scope;
- forbidden scope;
- expected artifacts;
- validation order when specified.

The narrowest task-specific execution contract overrides generic closeout behavior. Mutable runtime, PR, and worktree facts belong in current-state artifacts, not in this stable doctrine.

## Executable loop

```text
request
  -> evidence review
  -> bounded decision
  -> repo or Git or GitHub mutation
  -> artifacts
  -> validation
  -> report
  -> next decision
```

Rules:

1. **Evidence before confidence.** Inspect repository state, contracts, helpers, artifacts, and relevant logs before concluding.
2. **Existing contracts before invention.** Reuse current workflows, validators, registries, schemas, and helpers.
3. **Preservation before cleanup.** Preserve dirty, unpublished, ignored-evidence, and sibling-worktree state; checkpoint coherent owned work before broad or risky operations.
4. **Bounded mutation before completion.** Requested repository work is not replaced by an acknowledgment, plan, rewritten prompt, summary, or handoff.
5. **Artifacts before claims.** Name paths, freshness, exact head when relevant, and the highest proof level actually reached.
6. **Validation in declared order.** Run targeted contracts first, then relevant harness checks, broader safe checks, and final Git review.
7. **Report one next decision.** Close with exact Git or PR state, gaps, and one exact next command.

## Action-commitment rule

A task that claims it will **install, set up, build, execute, repair, configure, upgrade, deploy, merge, or release** something must require the corresponding mutation and proof.

Valid no-mutation completion exists only when mutation is genuinely blocked. That report must state the exact blocker, provide the smallest useful patch or file content, and give one safest next command.

Invalid closeouts include:

- acknowledgment only;
- summary only;
- rewritten prompt only;
- plan only;
- handoff only;
- preflight only;
- asking for permission when a bounded safe mutation is already authorized.

## Proof ladder

```text
contract -> harness -> static test -> build -> launcher -> command ACK -> behavior observed -> live runtime
```

Proof levels do not collapse. Parser success, a checkpoint, process presence, command ACK, launcher handoff, or a sanitized evidence capsule does not prove product behavior or live runtime completion.

## Runtime-context specialization

`.tbg/workflows/runtime-context-continuity.contract.json` specializes this doctrine for parallel agents, launchers, scripts, and engine handoffs around an already-running Bannerlord session.

Before launch, stop, build, install, cleanup, global input injection, or other runtime mutation:

- classify the current canonical Bannerlord processes and session ownership;
- treat PID deltas as secondary correlation, not primary identity;
- fail closed for active human, foreign, or ambiguous sessions;
- preserve the current and intended engine handoff before mutation;
- keep raw logs, saves, crash dumps, credentials, and private machine data local and ignored;
- publish only a schema-valid bounded sanitized capsule when remote diagnosis is needed.

## Launcher identity and multitasking

Launcher Play/Continue automation must select one fresh, unambiguous process/window identity and freeze it for the duration of that operation. Exact PID plus HWND is preferred when available. A unique process name, verified executable path, UI Automation root process ID, or a fresh S1-to-S2 process/window delta is also viable when it uniquely identifies the target. Process name is not inferior merely because PID/HWND exists; use the least invasive selector that is current, unique, and sufficient.

Discovery and actuation are separate. Process name, PID, HWND, executable path, UIA process ownership, and S1/S2 deltas may discover or corroborate the target. Once selected, later broad scans may not silently replace it. If the frozen identity disappears, becomes ambiguous, or no longer matches the expected launcher family, emit a blocked or explicit reselection decision and restart the bounded operation rather than drifting to another window.

Multitasking is the default. Launcher automation must remain background-safe and mouse-independent unless the active narrow workflow explicitly grants foreground-input authority. Prefer named UI Automation controls and supported invoke/select patterns inside the frozen target. A target-scoped background message may be used only when the control contract supports it and the target identity remains proven. Desktop-wide unscoped searches, cursor movement, `mouse_event`, foreground stealing, or guessed coordinates are not normal launcher discovery or actuation.

A foreground, cursor, or coordinate fallback is valid only when all of the following are recorded:

- explicit task-specific authority for foreground input;
- evidence that named-control, UIA-pattern, and target-scoped background paths were unavailable or failed;
- the exact frozen PID/HWND or equivalent unique identity;
- a bounded retry count and timeout;
- preservation and restoration of the operator's foreground where possible;
- post-action verification from a fresh process, window, UIA, or lifecycle transition.

Sending a click, InvokePattern, message, or input event is command dispatch, not success. Play/Continue completion requires a fresh correlated transition such as the launcher control disappearing, the frozen window changing state, a new game process/window appearing, or another workflow-declared expected signal. If the transition is absent, report the dispatch and the missing verification separately; do not sit indefinitely, move the mouse repeatedly, or claim launcher proof.

## Unified launch path and surface invariance

The launcher contract applies to every entry path, not only the path that currently works best. `ForgeContinue`, Auto Launch Nav, the new-game Play path, Steam-mediated launch, and every future registered launch path must create or join the same run context, correlation identity, window observer, external runtime observer, artifact registry, and proof boundary before the first actuation. No launch path may bypass identity resolution, event emission, quarantine, background-safety, transition verification, or operator reporting by calling a legacy helper directly.

Every correlated top-level launch surface must be recorded even when the harness does not interact with it. Required surface classes are:

- the Play/Continue launcher menu;
- the calibration menu;
- the Safe Mode window;
- the dependency Caution window;
- any other launcher-owned window;
- a correlated Steam broker window;
- the Singleplayer game handoff.

Each observation records the launch path, run and correlation IDs, process name, PID, HWND, executable path when available, title, class, UI Automation ownership, first and last seen times, identity resolution or quarantine result, action authority, dispatch result, and verified or missing transition. If an observer was not active or a surface was outside its correlated scope, absence is unknown evidence rather than proof that the window did not appear.

Identity is frozen independently for that surface operation. A verified transition from one surface to another may establish a new frozen identity inside the same run; a broad scan may not silently drift from the Play/Continue menu to calibration, Safe Mode, Caution, Steam, another launcher window, or the game host. Unknown windows remain quarantined. The calibration surface remains observation-only until its exact controls and workflow-owned semantic action are registered and fixture-proven.

Steam is a correlated launch broker, not an automatic action target. Observe only Steam or `steamwebhelper` windows that are tied to the active launch by fresh timing, parent/child process evidence, verified executable path, an owned launch request, or S1/S2 process/window delta. Do not enumerate unrelated Steam windows as Bannerlord surfaces, do not click or focus Steam automatically, and do not hide its presence merely because the harness does not interact with it.

All paths and surfaces emit the same minimum cascade:

```text
launch.path.selected
  -> window.observed
  -> window.identity.resolved_or_quarantined
  -> action.authorized_or_blocked
  -> action.dispatched_or_skipped
  -> transition.verified_or_unverified
  -> launch.handoff_or_blocked
```

Play/Continue intent remains owned by the launch context. Safe Mode maps only to the exact `No` control. Dependency Caution maps only to the exact `Confirm` control. Calibration requires an explicit registered action contract. Steam and unknown windows are observation-only. A path-specific implementation, timeout, mouse fallback, or launcher wrapper may not weaken these rules.

## Cross-boundary observer continuity and campaign readiness cascade

Logical listener survival is a continuous evidence and lease property; it does not require one operating-system hook or one process to observe every layer. The window observer and external runtime observer must overlap across the final launcher handoff, use the same `runId` and `correlationId`, and write into the same registered event lineage. Both observers must be active before the first launcher actuation. The window observer may retire only after a same-run runtime-observer attachment acknowledgement identifies the game host and confirms that the runtime observer owns continued observation. A restart or lost callback must emit `observer.gap` and `observer.reconciled` or remain blocked; silence is not continuity.

A verified launcher surface transition must name its predecessor and successor. The final launcher surface emits `launch.handoff.verified` only after the Singleplayer host is freshly observed and the runtime observer acknowledges the same process/session lineage. Same-process game hosting under `TaleWorlds.MountAndBlade.Launcher` is valid when a fresh HWND, title, UIA ownership, or lifecycle transition proves the host change. Window disappearance, click dispatch, process presence, or a launcher terminal state alone is not a clean handoff. Launcher handoff is not campaign readiness.

The in-game chain is equally explicit. `SetupPhase.MapTransition` is not MapReady or campaign readiness. `MapReady` alone is not permission to release automation. The campaign readiness gate requires fresh same-session evidence for `sessionReady:true`, `mapReady:true`, `campaignReady:true`, `canPollFileInbox:true`, a healthy runtime observer, a live correlated game process, no unreconciled observer gap, and a complete 60-second stable map-ready interval. Any false, missing, stale, mismatched, or interrupted signal blocks release.

The successful gate emits `campaign.automation.ready`. The registered campaign trigger publishes `campaign.readiness.cascade_published` so skills, agents, reports, and authorized workflows can learn that the map is ready. The readiness cascade grants no gameplay authority: it may not move the party, issue a command, mutate a save, trade, smith, or enable an engine unless the downstream task-specific workflow independently grants that authority and requires its own proof.

The minimum cross-boundary chain is:

```text
observer.window.started
  -> observer.runtime.started
  -> launch.path.selected
  -> launcher surface cascade
  -> launch.handoff.verified_or_blocked
  -> runtime.observer.attached_or_blocked
  -> game.runtime.lifecycle.observed
  -> campaign.map.transition_observed
  -> campaign.map.ready_observed
  -> campaign.readiness.stable_or_blocked
  -> campaign.command_poll.ready_or_blocked
  -> campaign.automation.ready_or_blocked
  -> campaign.readiness.cascade_published_or_blocked
```

Missing successor events, a changed run or correlation ID, premature window-observer retirement, an unreconciled observer gap, or a readiness trigger fired from lower proof must fail closed. The canonical specialization is `.tbg/workflows/launcher-to-campaign-event-continuity.contract.json`.

## Crash observability and negative evidence

Crash-sensitive engine calls, API calls, and state transitions must be reconstructable from correlated evidence rather than guessed from the last log line.

Before the call or transition, emit a trace boundary containing the run, command when present, correlation ID, span ID, parent span, operation, start time, pre-state snapshot, and expected signals. When control returns, emit the matching post-state snapshot, observed signals, completion time, and terminal span status. If the process disappears first, the external harness records `process_lost`, preserves the open span, and leaves the post-state null. A missing closing marker narrows the unresolved execution interval; it is not proof of the failing statement or root cause.

Negative evidence is valid only when the signal was declared in advance, the observer and source were active and fresh, the observation window completed, and the expected signal was not observed. Record the expected signal, observer, source, observation window, freshness, and explicit absence. Silence from a stale log, missing observer, incomplete window, or wrong process is unknown evidence, not negative evidence.

Every crash report separates:

- **observation:** what was directly recorded;
- **inference:** the bounded conclusion supported by those observations;
- **hypotheses:** plausible explanations still requiring tests;
- **proven cause:** a cause supported by correlated evidence or a successful counterfactual repair.

The last marker is always a boundary, never a cause. `native_crash_confirmed` requires correlated external terminal evidence such as Windows Error Reporting, a TaleWorlds crash report, debugger or dump metadata, or equivalent process-exit evidence. Log staleness or process non-observation alone may produce `log_stalled`, `process_unobserved`, or `native_crash_suspected`, but not a confirmed native-crash claim.

After a crash, live-behavior certification may not resume until crash observability passes: a fresh agent who was not present must be able to reconstruct the attempted operation, pre-state, post-state or process-loss boundary, expected signals, observed signals, valid absent signals, active span, terminal process evidence, causality status, exact head, and next decision from the sanitized repository artifacts alone.

## Completion contract

Every serious completion report names:

- completed work;
- exact files changed;
- generated artifacts;
- validation commands and results;
- skipped checks and reasons;
- blockers and risks;
- important paths;
- branch, commit SHA, push, and PR state;
- one exact next command.

Interrupted or resumed work additionally names the checkpoint SHA or artifact, preserved and excluded files, last completed validation, first pending validation, and exact resume command.

## Scope lock

This doctrine grants no gameplay, launcher, save-mutation, deployment, process-termination, merge, or release authority by itself. Those permissions must come from the active narrow workflow and task contract.
