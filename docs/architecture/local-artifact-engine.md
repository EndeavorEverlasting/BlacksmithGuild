# Local Artifact Engine Control Plane

## Purpose

BlacksmithGuild produces useful local artifacts, but an artifact file cannot inspect itself, classify its own proof boundary, choose a downstream workflow, or notify the next engine.

The local artifact engine supplies that missing control plane.

The system turns this passive sequence:

```text
producer writes file -> file remains on disk -> operator notices later
```

into this bounded sequence:

```text
producer writes file
  -> producer emits a named trigger
  -> local toggle grants or denies automatic authority
  -> artifact index parses changed files
  -> registry routes declared downstream engines
  -> engines write paired JSON and English packets
  -> handoff compressor names the next decision
```

The control plane is repo-local. It does not depend on a chat session, a prompt, Continuum, or an external agent framework.

## Operator Surface

Run these commands from the repository root:

```powershell
.\ForgeArtifactEngine.cmd status
.\ForgeArtifactEngine.cmd on
.\ForgeArtifactEngine.cmd off
.\ForgeArtifactEngine.cmd toggle
.\ForgeArtifactEngine.cmd run
.\ForgeArtifactEngine.cmd run -Mode observe
.\ForgeArtifactEngine.cmd run -Mode strict
```

`on` performs an immediate pass and starts a watcher. The default watcher interval is one second.

`off` revokes automatic authority and stops the recorded watcher process. Manual `run` remains available while the automatic toggle is off.

`toggle` changes the current automatic state. It does not infer authority from a prompt, producer, artifact, or previous chat.

`status` reports:

- whether automatic processing is enabled;
- the selected mode;
- whether the watcher process is running;
- the watcher process ID;
- the registry path;
- the output path;
- additional configured artifact roots.

The ignored local authority state lives at:

```text
.local/tbg-artifact-engine/state.json
```

The watcher lease lives at:

```text
.local/tbg-artifact-engine/watcher.json
```

The input fingerprints live at:

```text
.local/tbg-artifact-engine/fingerprints.json
```

## Modes

### Off

Automatic producer triggers and watcher passes do not run. Manual `run` remains available.

### Observe

The router inventories and parses configured local artifacts. It does not enqueue downstream engines.

Use observe mode when the operator wants visibility without an automatic decision cascade.

### Auto

The router inventories changed artifacts and follows declared downstream edges in the registry.

Auto mode does not grant mutation authority. Every registered engine remains read-only.

### Strict

Strict mode performs the auto cascade and returns a nonzero result when parsing or a required dependency produces a blocker.

Strict mode is appropriate for validation gates and unattended checks that must fail closed.

## Registered Engines

The registry is:

```text
.tbg/harness/artifact-engines.registry.json
```

### artifact-index

The artifact index scans configured roots and root-level `BlacksmithGuild_*.json` files.

It understands:

- JSON;
- JSONL;
- Markdown;
- text;
- logs.

It records path, size, modified time, parse state, schema, status, verdict, terminal state, proof-level claim, next command, and a bounded summary when those fields exist.

Files larger than the configured parse limit retain metadata without loading their full contents.

The engine excludes `artifacts/latest/artifact-engine` so its own reports cannot retrigger an infinite loop.

### repo-floor-context

This engine consumes:

```text
artifacts/latest/repo-hygiene-report.json
artifacts/latest/repo-hygiene-report.md
```

It emits a compact repo-floor packet containing branch, HEAD, upstream, verdict, dirty count, conflict count, operation count, worktree count, terminal state, and next command.

A missing hygiene artifact does not mean the repository is clean.

### stale-pr-next-action

This engine consumes:

```text
artifacts/latest/stale-pr-recovery/stale-pr-recovery.result.json
artifacts/latest/stale-pr-recovery/stale-pr-recovery.report.md
```

It also consumes the normalized repo-floor packet.

A bounded recovery instruction cannot become executable merely because the recovery renderer says it is ready. The repo-floor packet must also report a clean floor. Otherwise the engine blocks with the hygiene command.

### runtime-proof-boundary

This engine inspects known launcher, command-acknowledgement, status, lifecycle, route, trade, and guild-loop artifacts when they exist.

It may label a source claim as a candidate, but the parser-created proof level remains:

```text
artifact_inspection
```

Parsing does not verify freshness, causality, command consumption, movement, behavior, trade deltas, or live runtime success.

### handoff-compressor

The handoff engine consumes the normalized engine packets and writes a compact list of:

- engine ID;
- terminal state;
- blocking state;
- result path;
- exact next command.

It preserves blockers. It does not average them away or promote a partial result into completion.

## Producer Triggers

A producer may trigger the router only after its own artifact write succeeds.

Current producer integrations are:

```text
ForgeRepoHygiene.cmd
  -> ForgeArtifactEngine.cmd trigger repo-hygiene

ForgeStalePrRecovery.cmd
  -> ForgeArtifactEngine.cmd trigger stale-pr-recovery
```

A producer trigger cannot enable automatic processing. When the toggle is off, the trigger reports that no automatic pass ran and returns without changing authority.

A manual trigger is also available:

```powershell
.\ForgeArtifactEngine.cmd trigger repo-hygiene
.\ForgeArtifactEngine.cmd trigger stale-pr-recovery
```

## Trigger and Cascade Safety

The router enforces these boundaries:

1. Every engine must be registered.
2. Every engine must declare `read_only` authority.
3. Every downstream edge must name a registered engine.
4. The registry graph must be acyclic.
5. A pass may not exceed the configured engine limit.
6. Only declared edges may enqueue downstream engines.
7. A local lock prevents overlapping passes from writing the same packet set.
8. A settle delay allows a successful producer to finish atomic output replacement before parsing begins.
9. Input fingerprints suppress unchanged watcher work.
10. The output directory is excluded from artifact discovery.

The router never executes a command found inside an artifact.

## Forbidden Automatic Actions

The artifact engine may not:

- edit tracked source files;
- reset, clean, merge, rebase, cherry-pick, push, delete branches, or remove worktrees;
- open, close, retarget, merge, or comment on pull requests;
- launch Bannerlord;
- write a command inbox;
- mutate a save;
- mutate gameplay state;
- treat parser success as build, launcher, behavior-observed, or live runtime proof.

The output is a bounded next decision, not silent hands.

## Generated Artifacts

The aggregate surfaces are:

```text
artifacts/latest/artifact-engine/artifact-engine.result.json
artifacts/latest/artifact-engine/artifact-engine.report.md
artifacts/latest/artifact-engine/artifact-engine.events.jsonl
artifacts/latest/artifact-engine/artifact-engine.progress.log
artifacts/latest/artifact-engine/artifact-engine.handoff.md
```

Each engine also writes a result packet:

```text
artifacts/latest/artifact-engine/artifact-index.result.json
artifacts/latest/artifact-engine/repo-floor-context.result.json
artifacts/latest/artifact-engine/stale-pr-next-action.result.json
artifacts/latest/artifact-engine/runtime-proof-boundary.result.json
artifacts/latest/artifact-engine/handoff-compressor.result.json
```

JSON owns variables and machine state. Markdown reports own operator explanation. JSONL owns ordered engine events. The progress log owns one complete English sentence per engine action. The handoff owns the compressed next-agent state.

All generated artifacts remain ignored local output by default.

## Adding an Engine

A new engine is not complete when someone adds a parser function alone.

The implementation sprint must:

1. add the engine to the registry;
2. declare its read-only authority;
3. name exact input candidates or source roots;
4. name its output stem;
5. declare emitted events;
6. declare downstream edges;
7. implement a deterministic parser or classifier;
8. produce paired JSON and English output;
9. define a terminal state and exact next command;
10. add fixture coverage to `scripts/tbg/Test-TbgArtifactEngine.ps1`;
11. verify that malformed input fails according to the selected mode;
12. preserve the proof boundary.

Do not add an engine merely to increase harness size. Add one when it removes a real interpretation, routing, audit, or handoff burden.

## Validation

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Test-TbgArtifactEngine.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-powershell-utf8-bom-contract.ps1
git diff --check
git status --short
```

The fixture validator proves:

- the toggle can be disabled and enabled;
- manual execution works while automatic execution is disabled;
- observe mode does not cascade;
- auto mode cascades all registered engines;
- producer trigger identity is preserved;
- repo-floor output feeds stale-recovery gating;
- the proof-boundary engine does not overclaim;
- aggregate JSON, JSONL, progress, report, and handoff artifacts are written;
- event and progress counts agree;
- strict mode fails on malformed required input;
- PowerShell files parse;
- registry and contract JSON parse.

## Proof Boundary

Passing this validator establishes contract proof and static harness proof for artifact discovery, parsing, routing, toggle behavior, producer triggers, cascade behavior, reporting, and strict failure handling.

It does not establish:

- a persistent watcher run on the operator's Windows machine;
- parsing of the operator's current ignored artifact collection;
- build proof;
- launcher proof;
- command acknowledgement proof;
- movement or behavior-observed proof;
- live runtime proof.
