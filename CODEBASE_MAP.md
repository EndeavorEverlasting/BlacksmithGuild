# The Blacksmith Guild Codebase Map

Use this map to load only the files needed for a task.

## Agent and harness architecture

- `AGENTS.md` — compact universal invariants and task router.
- `CLAUDE.md` — Claude-compatible progressive-disclosure adapter.
- `.claude/skills/*/SKILL.md` — bounded task workflows.
- `.claude/capabilities/*.md` — reusable safety, evidence, and proof rules.
- `.ai/agent-contract.json` — repository-family inheritance and consumer boundary.
- `harness/api/tbg-harness-api.json` — supported operations and entrypoints.
- `harness/api/agent-capability-manifest.json` — skill/capability dependency graph.
- `harness/api/agent-routing-manifest.json` — deterministic task routing.
- `harness/api/artifact-types.json` — closed artifact role registry.
- `schemas/harness/` — fail-closed manifest, profile, result, and handoff schemas.
- `scripts/Test-TbgAiHarness.ps1` — PowerShell validator.
- `tests/harness/test_tbg_harness_contracts.py` — dependency-free contract suite.
- `.github/workflows/tbg-ai-harness.yml` — Linux and Windows harness CI.

## One-command E2E and handoff

- `harness/e2e/e2e-profiles.json` — safe E2E profiles and journey requirements.
- `scripts/Invoke-TbgHarnessE2E.ps1` — profile runner and evidence emitter.
- `scripts/New-TbgSprintCapsule.ps1` — machine-readable handoff generator.
- `harness/workflows/tbg-sprint-capsule.yaml` — handoff workflow contract.
- `.local/harness-runs/` — ignored run contexts and runtime artifacts.
- `docs/END_TO_END_TESTING_POSTURE.md` — proof classes and merge posture.
- `docs/MACHINE_READABLE_HANDOFF.md` — AgentSwitchboard/SysAdminSuite consumption rules.

## Product entrypoints

- `src/BlacksmithGuild/BlacksmithGuild.csproj` — net472 module build, Bannerlord references, output, and Release install seam.
- `src/BlacksmithGuild/SubModule.cs` — module load entry.
- `src/BlacksmithGuild/Behaviors/` — campaign behaviors.
- `src/BlacksmithGuild/DevTools/` — command bus, inbox, status, lifecycle, and runtime safety.
- `src/BlacksmithGuild/MapTrade/` — autonomous map-trade route and route evidence.
- `Module/BlacksmithGuild/SubModule.xml` — module metadata and version.
- `Module/BlacksmithGuild/bin/` — generated binaries; never commit.

## Build, install, and launcher surfaces

- `Forge.cmd`, `ForgeContinue.cmd`, `ForgeAndLaunch.cmd`, `LaunchForge.cmd` — technician entrypoints.
- `forge.ps1` — build/install/check/certification composition.
- `scripts/copy-client-dll.ps1` and `scripts/install-mod.ps1` — install seams.
- `tools/LaunchControl/` — launcher/session lifecycle UI and runtime state.
- `.vscode/tasks.json` — editor build/install task.

Release builds may install to the game. Use Debug or an explicitly isolated output for build-only validation unless the task owns installation.

## Runtime command and evidence surfaces

- `BlacksmithGuild_CommandInbox.json` — command request surface.
- `BlacksmithGuild_CommandAck.json` — command ACK surface.
- `BlacksmithGuild_Status.json` — current status/certification summary.
- `BlacksmithGuild_Phase1.log` — canonical behavior log.
- `BlacksmithGuild_RuntimeLifecycle.json` and `BlacksmithGuild_ProcessLifecycle.json` — lifecycle evidence.
- `BlacksmithGuild_MapTradeRouteCert.json` and related route artifacts — route proof.
- `docs/evidence/` — sanitized tracked evidence only.
- `artifacts/` and `.local/` — ignored runtime evidence.

These runtime files live outside the repository or under ignored roots. Do not fabricate or commit them.

## Safety and doctrine

- `docs/certification-doctrine.md` — certification tiers.
- `docs/dev-disposable-save.md` — disposable-save policy.
- `docs/in-game-surfaces.md` — visible and file-based surfaces.
- `docs/forge-zero-click-contract.md` — launcher expectations.
- `docs/test-plan.md` — product acceptance journeys.
- `.gitignore` — local evidence, binary, save, credential, and generated-output boundaries.

## Validation surface

- `tests/harness/test_tbg_harness_contracts.py` — harness structure, routing, schema, and handoff checks.
- `scripts/Test-TbgAiHarness.ps1` — Windows parser and contract validation.
- `scripts/Invoke-TbgHarnessE2E.ps1 -Profile default-static` — default composed harness journey.
- `dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Debug -p:GameFolder=<path>` — local build without the Release install target.
- Existing `scripts/verify-*.ps1`, cert helpers, and Forge checks — task-specific product validation.

## Local data boundary

Never commit:

- game saves or save backups;
- TaleWorlds/Bannerlord DLLs;
- generated module binaries;
- raw status, ACK, lifecycle, route, or command JSON;
- full Phase1/Forge logs;
- diagnostic archives;
- credentials or authentication state;
- machine-local absolute paths.

Tracked evidence must be sanitized, minimal, and explicitly allowed by `.gitignore` and the selected workflow.
