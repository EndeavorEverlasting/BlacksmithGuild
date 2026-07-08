# BlacksmithGuild Harness Codebase Map

## Purpose

This map is an operational index for agents working on The Blacksmith Guild harness. It is not decorative documentation. Use it to locate the repo-owned contracts, scripts, handoff surfaces, generated-output boundaries, and runtime-proof rules before editing or launching a sprint.

## Proof doctrine

Do not collapse proof levels.

| Proof level | Meaning | Typical evidence |
| --- | --- | --- |
| contract proof | The repo states the rule or workflow. | docs, JSON contracts, prompt packs |
| harness proof | A repo script can inspect or present the rule. | PowerShell verifier output, generated JSON summaries |
| static test proof | Offline tests passed. | validator output, `git diff --check`, BOM checks |
| build proof | The mod/build artifacts compiled. | build logs |
| launcher/browser proof | Launcher automation reached the claimed surface. | launcher log, window-state evidence |
| command ACK proof | The mod acknowledged a command. | command ack JSON/log entry |
| behavior observed proof | The game behavior actually occurred. | runtime logs/cert proving observed behavior |
| live runtime proof | A bounded live cert proved the behavior chain. | collected cert/log chain from Bannerlord runtime |

Contract proof is not runtime proof. A script finishing means only the script ran. Route assignment is not movement proof. Command ACK is not route movement. Live runtime proof requires an observed behavior/log artifact chain.

## Core guardrail docs

| Path | Role |
| --- | --- |
| `docs/harness/AGENT_RULES.md` | Lean BlacksmithGuild agent rules, proof distinctions, reference-shelf doctrine, and stop-before-runtime guidance. |
| `docs/harness/RUNTIME_EVIDENCE_CONTRACT.md` | Runtime evidence vocabulary and forbidden-claim boundaries. |
| `docs/harness/HANDOFF_TEMPLATE.md` | Required handoff shape for serious sprint work. |
| `docs/harness/TBG_SPRINT_PLAN_PACK.md` | Copy-one-block sprint pack for parallel TBG chats. |
| `docs/harness/prompts/tbg-agent-b-repo-floor-hygiene.md` | Repo-floor coordinator prompt for bounded hygiene work. |
| `docs/handoff/pr38-guardrails-closeout-handoff.md` | PR #38 closeout context and validation handoff. |

## Worktree and runtime-stop surfaces

| Path | Role |
| --- | --- |
| `docs/architecture/local-worktree-sprint-contract.md` | Sibling-worktree doctrine and protected primary checkout warning. |
| `docs/handoff/runtime-stop-guardrails.md` | Runtime stop requirements and ForgeStop expectations. |
| `.tbg/worktrees/local-sprint-worktrees.contract.json` | Machine-readable worktree contract. |
| `.tbg/workflows/runtime-stop-policy.contract.json` | Machine-readable runtime stop policy. |
| `scripts/tbg/Assert-TbgRuntimeStopPolicy.ps1` | Offline policy gate for workflows that need a stop step. |
| `scripts/tbg/Verify-TbgWorktreeStopGuardrails.ps1` | Offline verifier for worktree, stop, activity-ledger, orchestration-map, and harness guardrails. |

When a workflow assumes Bannerlord should not be running, the sprint must include `ForgeStop.cmd soft` first or document that the workflow owns the stop phase.

## Runtime evidence and proof-summary scripts

| Path | Role |
| --- | --- |
| `scripts/tbg/Validate-TbgRuntimeProof.ps1` | Summarizes existing runtime proof artifacts without launching the game. |
| `.tbg/workflows/blacksmith-runtime-harness.contract.json` | Runtime harness proof ladder and forbidden-claim contract. |
| `artifacts/latest/runtime-proof.validation.json` | Local generated validator result; do not commit by default. |

The runtime proof validator summarizes existing artifacts only. It does not create runtime proof, launch Bannerlord, or make behavior happen.

## Sprint plan and orchestration surfaces

| Path | Role |
| --- | --- |
| `scripts/tbg/Show-TbgSprintPlanPack.ps1` | Presents launch order and sprint-pack path; may generate a local result JSON. |
| `scripts/tbg/Verify-TbgSprintPlanPack.ps1` | Dedicated sprint-pack verifier. |
| `scripts/tbg/Show-TbgOrchestrationMap.ps1` | Presents orchestration map assets and may generate a local result JSON. |
| `docs/architecture/agent-orchestration-map.md` | Human-readable orchestration model. |
| `docs/handoff/orchestration-map-guardrails.md` | Guardrails for editing map layers together. |
| `docs/assets/agent-orchestration-map.mmd` | Editable Mermaid source of truth. |
| `docs/assets/agent-orchestration-map.mir.json` | Machine-readable representation. |
| `docs/assets/agent-orchestration-map.svg` | Presentation rendering. |

The orchestration map is not a screenshot. If the model changes, update the doc, Mermaid source, MIR JSON, presentation layer, and verifier expectations together.

## Activity-ledger doctrine

| Path | Role |
| --- | --- |
| `docs/architecture/campaign-activity-ledger.md` | Doctrine for meaningful-event logging, bounded hot-state reads, plan comparison, and English reporting. |
| `.tbg/workflows/campaign-activity-ledger.contract.json` | Machine-readable activity-ledger contract. |
| `.tbg/plans/campaign-activity-ledger-sprint/README.md` | Sprint plan for eventual implementation. |

Activity ledger is still doctrine unless implementation code and runtime evidence prove otherwise. Do not claim the ledger is listening in-game from these docs alone.

## Runtime ownership warnings

Route runtime work is a separate lane. Guardrail and repo-floor lanes must not edit route runtime files.

Forbidden for PR #38-style docs/harness guardrail work:

```text
src/BlacksmithGuild/MapTrade/*
```

Route-visible-start and route-owned-clock work must prove the full chain separately:

```text
CampaignMapReadyOrchestrator
-> AgentAutoMapTradeRoute trigger
-> MapTradeAutonomousService.StartRouteNow("AgentAutoMapTradeRoute")
-> route issued/started
-> movement observed or blocked with reason
```

## Launcher and ForgeStop safety surfaces

Use these surfaces before any build/install/launch/live-cert flow that assumes the game is stopped:

```text
ForgeStop.cmd
ForgeReboot.cmd
scripts/tbg/Assert-TbgRuntimeStopPolicy.ps1
scripts/tbg/Invoke-TbgWorkflow.ps1
```

Do not rely on terminal focus. Do not leave the user with hanging prompts. Do not start Bannerlord from docs-only validation.

## AI harness reference shelf

External harness repos are references, not vendored source.

Default reference root:

```powershell
Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Desktop\dev\references\ai-harnesses'
```

Override:

```powershell
$env:TBG_AI_HARNESS_REFERENCE_ROOT
```

Expected references when available:

```text
Archon
helpline
```

Missing references must not stall repo-local BlacksmithGuild sprint work. Use repo-local contracts first.

## 037B MCP/LSP lane note

The MCP/LSP symbol-smoke lane is separate from PR #38 guardrails. It may prove that a bridge exists and that C# tools are listed, but it must not claim symbol navigation unless `csharp-ls` is installed and the project load succeeds.

Known honest blocked state:

```text
status = missing_prereqs
verdict = lsp_project_not_loaded
```

## Generated-output warning

These local outputs may be produced by PR #38 scripts and should not be committed unless repo policy explicitly changes:

```text
artifacts/latest/tbg-sprint-plan-pack.result.json
artifacts/latest/tbg-sprint-plan-pack.validation.json
artifacts/latest/ai-harness-references.result.json
artifacts/latest/runtime-proof.validation.json
artifacts/latest/agent-orchestration-map.result.json
```

Runtime logs, saves, generated evidence, `.local` tool folders, and Bannerlord runtime files are local evidence, not repo source.

## Fast local validation sequence

Run offline/static checks only from a safe PR-specific worktree:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Resolve-TbgAiHarnessReferences.ps1 -WriteResult
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Show-TbgSprintPlanPack.ps1 -WriteResult
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Show-TbgOrchestrationMap.ps1 -WriteResult
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Validate-TbgRuntimeProof.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Verify-TbgWorktreeStopGuardrails.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Verify-TbgSprintPlanPack.ps1
git diff --check
git status --short --ignored
```

This sequence can raise harness/static proof only. It cannot raise build proof, command ACK proof, behavior observed proof, or live runtime proof.
