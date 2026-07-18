# Window lifecycle agent routing

```text
[TBG | P20 | Window Lifecycle Agent Harness | architecture]
```

## Decision

P19 owns lifecycle contracts, the reducer, and the runtime adapter. P20 factors those outputs into the repo-local agent harness: skills, capabilities, operations, and deterministic artifact-engine triggers.

P20 does not invent alternate lifecycle artifact shapes and does not click, launch, or mutate gameplay.

## P19 output contract consumed

| Artifact | Latest path |
|---|---|
| Run context | `artifacts/latest/window-lifecycle/window-lifecycle.run-context.json` |
| Artifact registry | `artifacts/latest/window-lifecycle/window-lifecycle.artifact-registry.json` |
| Events | `artifacts/latest/window-lifecycle/window-lifecycle.events.jsonl` |
| State | `artifacts/latest/window-lifecycle/window-lifecycle.state.json` |
| Result | `artifacts/latest/window-lifecycle/window-lifecycle.result.json` |
| Report | `artifacts/latest/window-lifecycle/window-lifecycle.report.md` |
| Handoff | `artifacts/latest/window-lifecycle/window-lifecycle.handoff.md` |

Schemas: `TbgWindowLifecycleRunContext.v1`, `TbgWindowLifecycleRuntimeEvent.v1`, `TbgWindowLifecycleMaterializedState.v1`, `TbgWindowLifecycleRuntimeResult.v1`.

P19 merge SHA recorded for this factoring lane: `493ea9d93a47ec61451e212ed81437a8f817fda7`.

## Skill dispositions

| Skill | Decision | Guardrail |
|---|---|---|
| `window-lifecycle-runtime` | Create | Inspection/reduction guidance; no clicking |
| `launcher-lifecycle` | Keep and narrow | Launcher open/stop/context/control; compose lifecycle for state interpretation |
| `runtime-evidence-certification` | Keep and rewire | Lifecycle evidence is one input, not live proof |
| `operator-control-surface` | Keep | ACK ceiling remains explicit |
| `route-visible-trade` | Keep | Owns movement/arrival/trade; lifecycle is upstream gate only |

## Capability dispositions

| Capability | Decision | Max proof |
|---|---|---|
| `capability:window-lifecycle-reduction` | Create | harness / static replay |
| `capability:window-lifecycle-runtime-observation` | Create | launcher observation |
| `capability:launcher-control` | Rewire | exact launcher context + lifecycle identity authority |
| `capability:runtime-evidence-certification` | Keep + lifecycle correlation input | live runtime still requires live evidence |
| `capability:operator-control` | Keep | command ACK |
| `capability:route-source-edit` | Keep | route domain ownership |

## Trigger disposition

Engine `window-lifecycle-boundary`:

- Authority: read-only
- Inputs: registered P19 lifecycle state/result/report paths only
- Output: `artifacts/latest/artifact-engine/window-lifecycle-boundary.result.json`
- Emits: `window.lifecycle.updated`
- Downstream: `runtime-proof-boundary`, `handoff-compressor`
- Guardrails: fail closed on malformed JSON; unknown/quarantine yields waiting/diagnostic; never click; never promote parser success to launcher acceptance or live runtime

## Operations

| Operation | Entrypoint | Proof ceiling |
|---|---|---|
| `validate-window-lifecycle-runtime` | `scripts/tbg/Test-TbgWindowLifecycleRuntime.ps1` | static test |
| `replay-window-lifecycle-fixture` | `ForgeWindowLifecycle.cmd` replay | harness |
| `inspect-window-lifecycle-status` | `ForgeWindowLifecycle.cmd` status | harness |

## Routing rules

1. Lifecycle artifact, schema, or `ForgeWindowLifecycle` intent selects `window-lifecycle-runtime` as primary.
2. Launcher command intent selects `launcher-lifecycle`.
3. Command ACK intent selects `operator-control-surface`.
4. Movement/trade intent selects `route-visible-trade`.
5. Lifecycle artifacts alone must not select `route-visible-trade`.
6. Exactly one primary skill; composition is conditional.

## Non-goals

- No P19 schema or adapter edits
- No visible-trade coordinator integration (P21)
- No PR #69/#43 disposition (P21)
- No new MCP server
- No live Bannerlord proof claim

## Proof ceiling

```text
agent-harness / static / artifact-engine harness
```

Not proven: modal acceptance, campaign readiness, command ACK, movement, arrival, trade, gameplay success.
