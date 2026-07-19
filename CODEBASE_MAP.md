# The Blacksmith Guild Codebase Map

Load only the smallest surface required by the active `.tbg` skill and workflow contract.

## Root coordination

- `AGENTS.md` — safe bootloader, universal safety, proof ladder, and lane router.
- `CLAUDE.md` — Claude adapter subordinate to `AGENTS.md`.
- `docs/AI_HARNESS_ENTRYPOINT.md` — canonical fresh-agent front door from rules through workflow selection, validation, artifacts, and handoff.
- `CODEBASE_MAP.md` — this smallest-surface navigation map.
- `.tbg/skills/manifest.json` — canonical v2 skill router, ownership, validators, artifacts, and proof ceilings.
- `.tbg/harness/manifest.json` — central path registry and harness doctrine.
- `.tbg/workflows/` — executable workflow contracts.
- `.gitignore` — generated-output, secret, save, crash-dump, and machine-local evidence boundary.
- `artifacts/latest/` — generated current-state and handoff surfaces; freshness must be proven.

## E2E and machine-readable continuation

- `.tbg/harness/e2e/profiles.json` — static, build, read-only runtime, and disposable-save profiles.
- `.tbg/workflows/end-to-end-validation.contract.json` — composed validation sequence and proof promotion rules.
- `.tbg/workflows/tbg-sprint-capsule.contract.json` — handoff compression contract.
- `.tbg/harness/consumer-handoffs.registry.json` — AgentSwitchboard and SysAdminSuite authority/readiness rules.
- `.tbg/harness/e2e-artifact-types.registry.json` — closed run artifact roles.
- `scripts/tbg/Invoke-TbgEndToEndValidation.ps1` — one-command profile runner.
- `scripts/tbg/Test-TbgEndToEndHarness.ps1` — PowerShell contract validator.
- `scripts/tbg/New-TbgSprintCapsule.ps1` — path-free machine-readable handoff generator.
- `tests/harness/test_tbg_end_to_end_harness.py` — dependency-free Linux/static contract.
- `.local/tbg-e2e-runs/` — ignored run contexts and raw harness outputs.

## Existing harness and state systems

- `.tbg/harness/artifact-engines.registry.json` and `.tbg/workflows/local-artifact-engine.contract.json` — deterministic artifact parsing/routing.
- `.tbg/state/` and `.tbg/workflows/state-envelope.contract.json` — state capabilities, constraints, and views.
- `.tbg/harness/window-identities.registry.json` — launcher/window identity policy.
- `docs/harness-doctrine.md`, `.tbg/harness/policies/harness-doctrine.policy.json`, and `scripts/tbg/Test-TbgHarnessDoctrine.ps1` — launcher identity freeze, process-name/PID/HWND/S1-S2 selection, multitasking-safe background actuation, and post-action transition verification doctrine.
- `.tbg/state/game-compatibility.registry.json` — Bannerlord compatibility gate.
- `scripts/tbg/Test-TbgSkillRouting.ps1` — canonical skill/router validator.
- `docs/architecture/runtime-observer-agent-routing.md` — read-only observer capability and incident trigger routing.
- `ForgeArtifactEngine.cmd`, `ForgeAgentStatus.cmd`, `ForgeRepoHygiene.cmd` — operator entrypoints.

## Product and build

- `src/BlacksmithGuild/` — gameplay/module source.
- `src/BlacksmithGuild/BlacksmithGuild.csproj` — net472 build; Release invokes install, Debug is build-only.
- `Module/BlacksmithGuild/SubModule.xml` — module identity/version.
- `Module/BlacksmithGuild/bin/` — generated binaries; never commit.
- `forge.ps1`, `Forge.cmd`, `ForgeContinue.cmd`, `ForgeReboot.cmd`, `ForgeStop.cmd` — build/install/launch lifecycle.
- `tools/LaunchControl/` — launcher/session lifecycle UI.

## Runtime command and evidence seams

- `BlacksmithGuild_CommandInbox.json` — command request.
- `BlacksmithGuild_CommandAck.json` — exact command ACK.
- `BlacksmithGuild_Status.json` — status/certification summary.
- `BlacksmithGuild_RuntimeLifecycle.json` and `BlacksmithGuild_ProcessLifecycle.json` — lifecycle evidence.
- `BlacksmithGuild_Phase1.log` — canonical behavior log.
- route, map-trade, smithing, governor, and regent JSON artifacts — workflow-specific behavior proof.
- `.tbg/workflows/runtime-context-continuity.contract.json` — process ownership, correlated spans, pre/post-state, negative evidence, causality, and crash reconstruction authority.
- `ForgeRuntimeObserver.cmd`, `ForgeRuntimeIncident.cmd`, and `.tbg/skills/runtime-incident-triage/SKILL.md` — observer lease/status and completed-run incident reconstruction entrypoints.
- `.tbg/harness/schemas/runtime-context-capsule.schema.json` and `scripts/tbg/Test-TbgRuntimeContextContinuity.ps1` — sanitized crash-capsule enforcement.
- `docs/evidence/runtime-context/` — bounded remote reconstruction packets; raw logs and crash dumps stay ignored.
- `docs/certification-doctrine.md` and `docs/dev-disposable-save.md` — live proof and save-safety authority.

## Proof-safe validation

- Static harness: `powershell -NoProfile -File scripts/tbg/Invoke-TbgEndToEndValidation.ps1 -Profile default-static`.
- Local build: use the `local-build` profile with a real game root; it invokes Debug, not Release install.
- Read-only runtime: explicit `-AllowLiveRuntime`; refreshes current artifacts without save mutation.
- Disposable-save mutation: profile exists but fails closed until a specific live workflow and disposable save are explicitly supplied.

Never infer build, install, launcher, ACK, behavior, or live-runtime proof from a lower surface.