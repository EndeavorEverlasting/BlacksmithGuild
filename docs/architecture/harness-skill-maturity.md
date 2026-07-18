# Harness and Skill Maturity Doctrine

```text
[TBG | Harness Skill Maturity | coordinator/architecture | branch: docs/agent-skills-stale-pr-cherry-pick]
```

## Purpose

This document turns the harness-heavy app idea into a repo rule that can guide future refactors without turning the codebase into ceremony.

The useful lesson is not that The Blacksmith Guild must reach a specific harness percentage. The useful lesson is that low-trust automation needs strong plumbing: policy, evidence, rollback, permissions, workflow contracts, registries, validation, and readable reports.

## Current posture

The Blacksmith Guild is a game mod plus an automation harness. That means it should not blindly chase a 90 percent harness shape.

A thicker harness is valuable when it makes the app safer, easier to audit, easier to replay, or easier for agents to extend. It is harmful when it hides real gameplay, economy, route, save, or smithing behavior behind generic wrappers.

## Harness-owned concerns

Move logic toward harness when it is cross-cutting and repeated across multiple workflows, agents, runners, or engines.

| Concern | Harness-owned shape |
|---|---|
| Config loading | Typed settings resolved once and injected into runners or skills. |
| Capability routing | Registry or manifest chooses the allowed engine, skill, or adapter. |
| Permission gates | Manual, Hybrid, Automation, read-only, write-mode, and runtime preconditions enforced centrally. |
| Evidence capture | Inputs, outputs, verdicts, blockers, proof levels, and artifact links recorded consistently. |
| Retry and timeout budgets | Bounded by policy rather than open-coded loops. |
| Rollback and stop paths | Stop, undo, or retention decisions registered before high-risk work. |
| Metrics and traces | Structured events emitted without direct ad hoc console output. |
| English/JSON reporting | One effective context renders human and machine surfaces. |
| UI or runner shims | Thin adapters that translate operator or client surfaces into the same harness contract. |

## Skill or domain-owned concerns

Keep logic in a skill or domain module when it is narrow, testable, and tied to game meaning.

| Concern | Skill/domain shape |
|---|---|
| Route scoring | A small service or pure function that ranks targets or reasons about path safety. |
| Market/economy math | Focused calculations with explicit input and output schemas. |
| Smithing advice | Candidate ranking, material gaps, refine/smelt eligibility, and forge recommendation logic. |
| Save identity interpretation | Bounded runtime result interpretation, not generic harness policy. |
| Worker decisions | Governor, MapTrade, GuildLoop, Cohesion, HorseMarket, Smithing, Companion, and Assistive behavior should remain visible as domain capability, with harness around them. |

## Decision test

Before moving logic, answer these questions:

1. Does this protect more than one workflow, agent, runner, or engine?
2. Does it enforce safety, evidence, rollback, policy, reporting, or capability routing?
3. Does it reduce duplicated orchestration or stale prompt/context load?
4. Would a domain expert still be able to find the game behavior after the refactor?
5. Can the same goal be achieved with a smaller contract, manifest, skill doc, or validator?

If the answer to the first three questions is mostly no, the change probably belongs in a skill/domain module or should be rejected.

## Migration pattern

Use this order:

1. **Name the pain point.** Do not start from a percentage.
2. **Classify the logic.** Decide harness, skill/domain, or reject.
3. **Choose the smallest surface.** Prefer contract, manifest, skill, validator, or doc before broad framework code.
4. **Preserve authority.** Executable contracts and current source remain truth; docs and skills explain them.
5. **Validate the boundary.** Static changes do not claim runtime proof.
6. **Record the next constraint.** Note what would need a runtime sprint later.

## Good next harness moves

The repo should prefer harness growth in these areas when real duplication or risk appears:

- workflow specs that route named skills and preserve correlation IDs;
- capability registries for engines, runners, skills, and operator controls;
- policy guards for read-only versus write-mode, Manual/Hybrid/Automation, and runtime preconditions;
- evidence replay fixtures for worker inputs and outputs;
- rollback or stop metadata for side-effecting commands;
- shared English/JSON reporting that derives from effective policy context.

## Bad harness moves

Avoid these:

- moving route, trade, smithing, or economy behavior into generic harness wrappers;
- adding plugin systems before there are multiple real plugins to load;
- burying live runtime constraints inside docs only;
- treating a high harness ratio as success;
- counting generated artifacts, docs, or wrappers as app safety without validators.

## Relationship to stale PR recovery

Stale PR cherry-picking should use the same maturity test. When a stale PR contains useful work, classify each piece:

- cross-cutting guard, workflow, policy, registry, or report: replay toward harness;
- narrow behavior, calculation, or validator: replay toward a skill/domain surface;
- stale runtime proof, old generated evidence, or broad prompt prose: preserve as history or reject, but do not reuse as current truth.

## Done gate

A harness maturity change is complete only when:

- the pain point is named;
- the harness versus skill/domain classification is recorded;
- the minimal changed surface is justified;
- no domain behavior is hidden inside harness;
- no runtime proof is claimed from static work;
- JSON files parse if JSON changed;
- `git diff --check` passes or the local blocker is recorded.
