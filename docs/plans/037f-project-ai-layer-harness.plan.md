# Project AI Layer: Harness and Tooling Plan

```text
[TBG | Sprint 037F | Project AI Layer Plan | branch: sprint/037a-local-agent-harness]
```

## Source note

This plan captures the AI-layer harness approach discussed from the Anthropic agent-harness material and adapts it to The Blacksmith Guild repo. The goal is to turn chat-born planning into durable repo guidance before it evaporates.

## Purpose

The Project AI Layer is the operating layer that helps AI agents work inside the repo without rediscovering the whole codebase, bloating context, or stepping into unsafe runtime surfaces.

It complements the Sprint 037A local agent harness:

- `CLAUDE.md` hierarchy for repo rules and local context.
- Start/stop hooks for session initialization and reflection.
- Path-scoped skills for progressive disclosure.
- MCP/LSP integration for symbol-level search.
- Subagents for high-token exploration and research.

## 1. Global rules with `CLAUDE.md`

### Strategy

Keep rule files lean. Use layered `CLAUDE.md` files so agents receive only the rules relevant to the current path.

### Objective

Prevent context bloat while keeping domain-specific conventions available where they matter.

### Proposed hierarchy

```text
CLAUDE.md
src/CLAUDE.md
src/BlacksmithGuild/CLAUDE.md
scripts/CLAUDE.md
scripts/harness/CLAUDE.md
scripts/mcp/CLAUDE.md
docs/CLAUDE.md
.tbg/CLAUDE.md
```

### Root `CLAUDE.md` should include

- Current repo identity and context-banner requirement.
- Runtime boundary: do not launch Bannerlord unless the active contract allows it.
- ForgeStop rule for build/install/runtime workflows.
- Evidence requirements and artifact paths.
- Preferred response format for TBG workstreams.
- Branch/PR distinction requirement.

### Path-specific rule examples

| Path | Local rules |
|---|---|
| `src/BlacksmithGuild/` | C# mod conventions, runtime safety, dev-command boundaries. |
| `scripts/harness/` | JSON result envelope, no runtime side effects, policy-first behavior. |
| `scripts/mcp/` | Read-only first, distinguish missing tool from failed project load. |
| `.tbg/` | Contracts and policies are source-of-behavior, not decoration. |
| `docs/` | Handoff docs must include context banner, scope, and validation commands. |

## 2. Self-improving hooks

### Strategy

Use hooks to keep the harness current without letting hooks become an uncontrolled rewrite machine.

### Start hooks

Start hooks should load or print:

- repo context banner
- active workflow contract
- forbidden runtime scope
- latest harness readiness artifact, if present
- next recommended validation commands

### Stop hooks

Stop hooks should inspect the completed session and propose updates to repo guidance.

Stop hooks may write a proposal artifact such as:

```text
artifacts/latest/claude-rules-update.proposal.md
```

They should not silently rewrite `CLAUDE.md`. The better pattern is proposal first, human or explicit-agent commit second.

### Stop-hook reflection prompts

- Did the agent ask a question already answered by repo rules?
- Did the agent repeat a command pattern that should become a script?
- Did the agent touch files outside the active workflow scope?
- Did a validation failure reveal a missing policy rule?
- Did a new project convention emerge that belongs in path-local `CLAUDE.md`?

## 3. Path-scoped skills

### Strategy

Expose specialized workflows only where relevant. The point is progressive disclosure, not hiding knowledge from the agent.

### Candidate skills

| Skill | Trigger path | Purpose |
|---|---|---|
| Add Dev Command | `src/BlacksmithGuild/DevTools/` | Add command bus entry, hotkey or inbox adapter, result logging, and evidence. |
| Add Harness Policy | `.tbg/harness/policies/` | Add or adjust command/file/runtime/evidence rules. |
| Add Workflow Contract | `.tbg/workflows/` | Define allowed scope, forbidden scope, artifacts, and validations. |
| Add MCP Tool | `scripts/mcp/` or future MCP server source | Add read-only tool with bounded output and clear failure states. |
| Add Runtime Proof | runtime-cert docs/scripts | Require ForgeStop, build/install, run, artifact capture, and clear PASS/FAIL. |
| Add Handoff Doc | `docs/handoff/` | Produce compact context for the next agent or local tester. |

### Skill file concept

A future skill definition should include:

- name
- trigger paths
- allowed files
- forbidden files
- required evidence
- validation commands
- examples of good and bad outputs

## 4. LSP and MCP integration: the search harness

### Strategy

Implement local MCP servers that expose Language Server Protocol capabilities so agents can navigate C# symbols directly.

### Capability

The agent should be able to ask for:

- class definitions
- method definitions
- references/callers
- type information
- diagnostics
- workspace symbols

### Benefit

Symbol-level search reduces broad grep dumps and token waste, especially as the mod grows.

### Required Sprint 037B proof

The symbol smoke test must answer these targeted questions:

```text
Where is MapTradeAutonomousService defined?
Where is StartRouteNow defined?
Who calls StartRouteNow?
Where is CampaignMapReadyOrchestrator defined?
Where is _activeReport assigned, read, and cleared?
Where are hotkeys registered?
Where is command inbox parsing handled?
```

### Failure states

The MCP/LSP layer must distinguish:

```text
mcp_tool_missing
lsp_project_not_loaded
symbol_not_found
symbol_navigation_ready
```

Mush is not allowed. Missing tool, bad project load, and absent symbol are different failures.

## 5. Subagents for exploration

### Strategy

Delegate high-token discovery, research, and repo exploration to subagents while keeping the primary session focused on edits and decisions.

### Good subagent tasks

- Map call graph around route automation.
- Compare two workflow contracts.
- Read recent docs and summarize contradictions.
- Find all command inbox handlers.
- Inspect PR diff and return risk notes.
- Search external MCP/LSP tooling options and return a bounded recommendation.

### Subagent output contract

Subagents should return:

- question asked
- files inspected
- concise findings
- confidence level
- unresolved questions
- next action recommendation

They should not return giant paste dumps unless explicitly requested.

## Implementation action items

- [ ] Add root `CLAUDE.md` with repo identity, context banner rules, and runtime boundary.
- [ ] Add path-local `CLAUDE.md` files for `src`, `scripts`, `.tbg`, and `docs`.
- [ ] Configure start hook to load context banner and active workflow contract.
- [ ] Configure stop hook to write `artifacts/latest/claude-rules-update.proposal.md`.
- [ ] Add a rules-update review workflow so proposed `CLAUDE.md` changes do not auto-merge silently.
- [ ] Deploy local MCP server for symbol search.
- [ ] Add live Sprint 037B MCP/LSP symbol smoke.
- [ ] Define path-scoped skills for dev commands, harness policies, workflow contracts, MCP tools, runtime proof, and handoff docs.
- [ ] Define subagent output contract under `.tbg/harness/schemas`.
- [ ] Add a reusable prompt for exploration subagents.

## Acceptance criteria

This plan is ready when:

1. A new agent can identify its branch, PR, sprint, and forbidden scope without asking the user.
2. Agents receive fewer global rules and more path-relevant rules.
3. Dangerous runtime actions remain contract-gated.
4. Symbol lookup works through MCP/LSP for the known smoke targets.
5. Stop hooks produce rule-update proposals instead of silently editing policy files.
6. Subagent summaries are compact enough to keep the primary session clean.

## Judge note

The AI layer is not a folder of inspirational markdown. It is the difference between a disciplined agent and a raccoon with repo access. Build the discipline first. Then give it sharper tools.
