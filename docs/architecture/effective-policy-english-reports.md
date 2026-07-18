# Effective-Policy English Reports

```text
[TBG | English Renderer + Effective Policy Context | branch: sprint/english-policy-renderer]
```

- Repo: `EndeavorEverlasting/BlacksmithGuild`
- Sprint: separate harness policy/reporting lane based on `origin/main`
- Target files: `.tbg/harness/`, `.tbg/workflows/`, `.tbg/guardrails/`, `scripts/harness/`, `scripts/mcp/`, `scripts/tbg/`, harness documentation, and static CI

## Scope

This harness lane makes executable policy readable without changing Bannerlord behavior. Its owned surfaces are `.tbg/` policy and workflow inputs, `scripts/harness/` resolvers and renderers, static CI, and policy-report documentation.

Forbidden work includes route runtime patches, launching Bannerlord, running `ForgeReboot.cmd`, writing command inbox files, mutating saves, and presenting static output as gameplay proof.

## Effective context is executable truth

Policy prose must start with the same versioned JSON that the harness and workflow validators execute. The reporting profile lives at `.tbg/harness/policies/policy-reporting.policy.json`; applicable manifests, workflow contracts, guardrails, and command-safety policies remain executable sources too. `scripts/harness/TbgEffectivePolicy.psm1` resolves those inputs into one `tbg.harness.effective-policy-context.v1` context before any consumer describes them. `scripts/harness/Get-TbgEffectivePolicyContext.ps1` is the command-line entry point. The context records stable facts such as the selected profile and workflow, applicable policy, lane, runtime preconditions, command decisions, result and artifact paths, proof level, blocker and next-action guidance, validation mode, source files, CI surfaces, and consumers.

The resolved context is the reporting boundary. A consumer may add explanatory doctrine, but it must not maintain a second hand-written account of effective policy. Overrides and workflow-specific values are resolved once, recorded in the context, and reused by every output surface. This keeps an audit sentence from disagreeing with the policy or workflow contract that enforces it.

Every result writer embeds the resolved context as `effectivePolicy` and the rendered prose as `englishSummary`. Its `handoff` object names the machine result, the English report, and the fields that must survive transfer between agents, hooks, engines, scripts, and modules. That makes source inventory, consumer inventory, blockers, and next-patch guidance executable handoff data instead of conversational memory.

## Workspace and runtime-test handoff order

`scripts/harness/Resolve-TbgSprintWorkspace.ps1` automates the preflight that previously depended on an agent noticing a dangerous checkout. It reads the primary checkout's short status, unmerged paths, registered worktrees, remote default branch, and optional foundation PR state. Its pure decision module selects the clean primary checkout, an existing isolated worktree, or a bounded `git worktree add -b` command. A merged foundation PR resolves to the current remote default; an open foundation PR resolves to its remote head. The resolver never resets, cleans, switches, deletes, or creates a worktree itself.

The decision is written to `artifacts/latest/sprint-workspace-decision.json` with an English-first companion report. It records forbidden paths touched, the evidence used, the chosen base and reason, the selected path and branch, and the one safe creation command when creation is required. `scripts/harness/Test-TbgSprintWorkspace.ps1` proves clean, dirty, conflicted, forbidden-path, merged-PR, open-PR, and existing-worktree cases.

The effective context also carries the ordered runtime-test handoff sequence: workspace decision, effective policy, runtime-state preflight, save load, campaign-map travel, town entry, visible trading, and linked English/JSON results. This sprint implements and validates the first two handoff layers only. The save-load/travel/trading CMD entrypoint remains a runtime sprint because it must use the real in-game mechanisms and collect visible proof; static harness output does not pretend that those phases have run.

## Generic English rendering

`scripts/harness/ConvertTo-TbgPolicyEnglish.ps1` exposes the module's English renderer for effective contexts and result rows. It is profile-agnostic: canonical profiles, generic result rows, review rows, policy-audit rows, workflow-contract rows, blocked or passing results, denied command-safety results, and missing prerequisites travel through the same rendering rules.

Adding a profile must not require a profile-named conditional in the renderer. New fields use generic identifier-to-words and value formatting, while stable policy concepts can use shared sentence templates. `scripts/harness/Test-TbgEnglishRenderer.ps1` exercises representative fixtures and rejects empty prose, field-name bullets, and raw-JSON primary output.

## Markdown first, JSON still available

Human-facing reports use English-primary Markdown. The report begins with the effective policy summary, then explains results and review items in prose. Raw JSON remains available as a linked secondary artifact for machines, debugging, and exact-field inspection; it is not the default human report body.

The two forms have distinct jobs:

| Form | Primary consumer | Contract |
|---|---|---|
| Markdown | Developers, reviewers, and future agents | Readable English derived from the effective context |
| JSON | Validators, scripts, and debugging tools | Complete machine-readable context and result fields |

## Consumer surfaces

The effective context and English renderer are shared infrastructure for:

- `scripts/harness/Write-TbgHarnessResult.ps1`
- `scripts/harness/Test-TbgHarnessReadiness.ps1`
- `scripts/harness/Test-TbgDoneGate.ps1`
- `scripts/harness/Test-TbgCommandSafety.ps1`
- `scripts/harness/Test-TbgFileSafety.ps1`
- `scripts/harness/Test-TbgWorkflowGate.ps1`
- architecture and handoff reports
- local MCP or agent adapters that display harness results

Consumers may retain their existing machine result envelopes. Their readable reports should pass the same resolved context to the shared renderer instead of rebuilding policy prose locally.

`scripts/tbg/Invoke-TbgWorkflow.ps1` remains an adapter target rather than an edited consumer in this PR. Its `route-visible-start` result can already be loaded by `ConvertTo-TbgPolicyEnglish.ps1`; changing the runtime runner itself belongs to the route reporting/runtime lane.

## CI and static-proof boundary

`.github/workflows/harness-policy-reports.yml` runs when bounded harness, policy, workflow, guardrail, renderer, MCP, architecture, handoff, workflow, or root-agent-rule surfaces change. It parses every JSON file under `.tbg`, validates English fixtures, checks readiness for `local-mcp-code-intelligence` and `project-ai-layer`, and runs the `local-mcp-code-intelligence` done gate.

These checks are static. They do not build the mod, launch or stop Bannerlord, install a DLL, write to a command inbox, mutate a save, or assert an in-game outcome. A passing policy-report workflow proves that policy inputs parse, report fixtures render correctly, and the local MCP done gate accepted its required static artifacts. Readiness output must still be read for any reported missing prerequisite. Runtime proof requires the separate game-facing workflow and its compact runtime artifacts.

## Validation and handoff

Run the static checks from the repository root:

```powershell
Get-ChildItem .tbg -Recurse -File -Filter *.json | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json | Out-Null
}
./scripts/harness/Test-TbgEnglishRenderer.ps1
./scripts/harness/Test-TbgHarnessReadiness.ps1 -ContractId 'local-mcp-code-intelligence'
./scripts/harness/Test-TbgHarnessReadiness.ps1 -ContractId 'project-ai-layer'
./scripts/harness/Test-TbgDoneGate.ps1 -ContractId 'local-mcp-code-intelligence'
git diff --check
```

The static boundary is the deliberate gap: none of these commands supplies runtime proof. The principal risk is prose drift if a new consumer bypasses the resolver or renderer. Review new report surfaces against the consumer inventory and require their policy statements to originate from the effective context.

Next command:

```powershell
./scripts/harness/Test-TbgEnglishRenderer.ps1
```
