# Remaining Product Gap Register

## Purpose

This register captures known remaining gaps outside the local-iteration harness gap register.

The local-iteration gap register covers harness reliability, evidence discipline, command proof, time budgets, and agent behavior. This file covers product, gameplay, feature, and operator-experience gaps that can be identified from the current project direction without running another live test.

These gaps are not all immediate sprint work. They are inventory. Future patches may prioritize, but they must not pretend these gaps do not exist.

## Relationship to the local-iteration gap register

This register does not replace:

```text
docs/operator/local-iteration-gap-register.md
```

Any patch touching Reboot, validation, evidence, launcher/attach, foreground, command execution, movement proof, smithing, trading, or local harness behavior must still include the ten-gap local iteration coverage matrix.

This register adds the product-side backlog that sits outside that matrix.

## Product gap doctrine

A product gap has:

- a name
- a user-facing consequence
- an owner seam
- an expected fix shape
- a proof shape

A product gap should not be closed by logs alone. It closes when the product behavior is understandable, repeatable, and useful to the operator.

## Gap P1: time-budget doctrine documented but not fully enforced in code

### User-facing consequence

Agents can still run long commands if scripts retain large defaults or lack timeout guards.

### Owner seam

- `scripts/run-autonomous-assist-session.ps1`
- `scripts/run-reboot-iteration.ps1`
- `scripts/run-offline-validation-bundle.ps1`
- `scripts/launcher-auto-nav.ps1`
- future `scripts/time-budget-contract.ps1`

### Expected fix shape

Create an enforceable time-budget contract and wire it into runner, Reboot, launcher, ForgeVerify, and validation flows.

### Proof shape

A contract test fails if normal-path defaults exceed 30 seconds or if any generic 300/600-second timeout exists outside the allowlisted gameplay-long classes.

## Gap P2: Reboot does not yet have positive success terminal semantics

### User-facing consequence

A run can prove movement or visible mechanics but still end with residual phrasing such as `max_iterations_no_repeat`.

### Owner seam

- `scripts/run-reboot-iteration.ps1`
- Reboot summary writer
- Reboot final classification

### Expected fix shape

Add positive terminal classifications:

- `visible_mechanics_observed`
- `movement_proved_no_repeat`
- `smithing_batch_observed`
- `trade_batch_observed`

Stop early when useful proof exists.

### Proof shape

Fixture test proves movement proof causes Reboot exit 0 with a positive classification and does not continue only to exhaust `MaxIterations`.

## Gap P3: ForgeVerify fast/full split is not fully productized

### User-facing consequence

The user can still be pushed into validation runs that are broader or slower than needed.

### Owner seam

- `ForgeVerify.cmd`
- `scripts/run-offline-validation-bundle.ps1`
- validation summary writer

### Expected fix shape

Default `ForgeVerify.cmd` to fast mode. Make full validation opt-in. Add per-step time budgets and written validation summary JSON/MD.

### Proof shape

Test proves `ForgeVerify.cmd -Fast` runs only bounded checks and writes latest validation evidence.

## Gap P4: latest local evidence is not discoverable enough

### User-facing consequence

The next agent may ask for pasted logs even though evidence exists locally.

### Owner seam

- Reboot evidence writer
- validation evidence writer
- live-cert evidence writer
- evidence pointer files

### Expected fix shape

Create latest pointer artifacts:

```text
docs/evidence/latest-reboot.json
docs/evidence/latest-validation.json
docs/evidence/latest-live-cert.json
```

Each pointer should include classification, timestamp, latest directory, summary path, user action needed, and likely owner seam.

### Proof shape

Test proves latest pointer files update after runs and point to existing local evidence files.

## Gap P5: doctrine is still ahead of enforcement

### User-facing consequence

Agents can quote doctrine without being stopped by failing tests when they violate it.

### Owner seam

- doctrine docs
- harness-engine manifest
- verifiers
- regression tests

### Expected fix shape

Add a doctrine-to-contract verifier that maps critical doctrine entries to manifest fields and tests.

### Proof shape

Verifier fails when a doctrine-critical rule exists only in docs and has no corresponding manifest/test enforcement.

## Gap P6: travel is proven enough to observe movement, but not yet productized as a user-safe travel feature

### User-facing consequence

Travel can be initiated and observed, but the product may not yet give the user a clear safe travel loop with destination, route risk, progress, stop conditions, and arrival handling.

### Owner seam

- `AutoTravelService`
- movement proof ledger
- RouteCouncil / Governor decision artifacts
- Reboot summary
- advisory surfaces

### Expected fix shape

Travel should expose:

- chosen destination
- reason for destination
- route started
- route progress evidence
- hostile/interruption stop condition
- arrival or partial-progress result
- next suggested action

### Proof shape

A live or fixture-backed run proves route start, progress/arrival classification, and summary output without requiring the user to interpret raw logs.

## Gap P7: blacksmithing batch work is not yet a complete user-facing loop

### User-facing consequence

Safe smithing actions exist in pieces, but the user does not yet have a polished loop that selects the right smithing action, consumes real resources/stamina, records the result, and recommends the next action.

### Owner seam

- Smithing audit service
- Smithing advisory service
- safe action/refine path
- forge recommendation artifacts
- stamina/material evidence writers

### Expected fix shape

A batch smithing loop should include:

- current stamina by hero
- material reserves
- available recipes/actions
- chosen action and reason
- one or bounded number of real actions
- before/after stamina/material deltas
- next recommendation

### Proof shape

Evidence proves real resource/stamina mutation and writes a human-readable and machine-readable smithing result.

## Gap P8: trading batch work is not yet a complete user-facing loop

### User-facing consequence

Market intel and trade execution evidence exist in pieces, but the user does not yet have a reliable trade loop that chooses, executes, and proves a trade batch.

### Owner seam

- Market intel artifact
- town-to-town trade probe
- economic-loop cert evidence
- trade execution runner
- inventory/gold evidence writers

### Expected fix shape

A trade loop should include:

- buy/sell candidate
- town and price basis
- inventory/gold before
- action attempted
- inventory/gold after
- profit/spread or reason blocked
- next town/action recommendation

### Proof shape

Evidence proves real inventory/gold mutation or a clear blocked-trade reason.

## Gap P9: advisory surfaces are not yet unified into one operator-facing report

### User-facing consequence

Useful artifacts exist, but the user has to mentally combine market intel, forge recommendations, stamina/material audits, travel status, and next action.

### Owner seam

- GuildLoopReport
- MarketIntel JSON
- ForgeRecommendations JSON
- SmithingAudit JSON
- SmithingAdvisory JSON
- Reboot summary

### Expected fix shape

Create a single operator-facing report that answers:

```text
Where am I?
What can I do now?
What should I do next?
What resource blocks me?
What evidence proves the last action?
```

### Proof shape

Fixture or live output produces one report with source artifact links/paths and no contradiction between recommendations.

## Gap P10: hotkey and command surface governance is incomplete

### User-facing consequence

Hotkeys can conflict with game/platform behavior, such as F12 overlapping Steam screenshots, and command names can become hard to remember or route.

### Owner seam

- dev command names
- hotkey registration
- docs/operator controls
- command inbox handling

### Expected fix shape

Add a command/hotkey registry that documents:

- command name
- hotkey
- owner feature
- safety level
- whether it mutates gameplay
- evidence artifact written
- known conflicts

### Proof shape

Verifier checks that registered hotkeys/commands appear in docs and that high-risk mutating commands declare their evidence artifact.

## Gap P11: character build automation is not yet connected to product doctrine

### User-facing consequence

The desired Aserai trade/smith/steward/leadership build is conceptually clear, but the automation may still be brittle or under-documented.

### Owner seam

- character creation traversal
- preferred culture config
- build preset docs
- quickstart evidence
- fallback culture chain

### Expected fix shape

Create a documented build preset:

```text
TBG Aserai Trade-Smith
primary: Trade, Smithing, Riding
secondary: Steward, Charm/Leadership as available
fallback: Khuzait if Aserai unavailable
```

Automation should record decisions, costs/drawbacks, and resulting skill/build evidence.

### Proof shape

Generated build evidence matches the preset and shows culture/skill decisions without cheating resources or XP.

## Gap P12: non-cheat doctrine needs broader mutation coverage

### User-facing consequence

The motto is clear, but every mutating action does not yet have a uniform proof rule proving it used real game mechanics.

### Owner seam

- inventory mutation paths
- stamina mutation paths
- time/rest mutation paths
- travel mutation paths
- trade mutation paths
- smithing mutation paths

### Expected fix shape

For every mutating operation, require:

```text
before state
action requested
action accepted
after state
delta
fakeGameplayDelta=false
```

No free gold, resources, XP, stamina, teleport, or time skip unless explicitly marked as dev-only and blocked from product proof.

### Proof shape

Verifier or test rejects mutating evidence that lacks before/after deltas or marks fake gameplay as product proof.

## Gap P13: save/profile safety is not yet fully formalized

### User-facing consequence

Disposable saves are acceptable, but the product still needs clearer boundaries between personal save, disposable cert save, and unsafe dev mutation.

### Owner seam

- save selection docs
- runner preflight
- evidence summaries
- live cert doctrine

### Expected fix shape

Every live mutation run should identify:

- save/profile name if safely available
- disposable vs personal flag
- mutating actions allowed
- backup or non-backup status
- operator confirmation requirement for risky scopes

### Proof shape

Preflight evidence declares save safety classification before mutating gameplay actions.

## Gap P14: companion/stamina handling is not yet productized

### User-facing consequence

The user wants smithing to use real companion stamina where the game allows it, but the rules for companion availability and smithy participation are not fully encoded.

### Owner seam

- Smithing audit service
- hero/companion roster inspection
- smithy UI/runtime state
- stamina evidence writer

### Expected fix shape

Audit should distinguish:

- main hero stamina
- companion stamina
- companion in party
- companion eligible for smithing
- companion visible/usable in smithy
- reason companion cannot be used

### Proof shape

Evidence explains why a companion does or does not appear in smithing selection and what stamina can be consumed.

## Gap P15: route/advisory decisions need explicit risk policy

### User-facing consequence

The agent may choose a route or trade destination without making risk posture visible to the user.

### Owner seam

- RouteCouncil
- Governor decision artifact
- hostile detection
- travel advisory report

### Expected fix shape

Route choices should declare:

- destination
- expected value/reason
- known risk
- hostile proximity / block reason if any
- fallback destination
- when to hold instead of travel

### Proof shape

Advisory artifact includes destination reasoning and risk posture before travel execution.

## Gap P16: generated docs/evidence may outpace repo navigation

### User-facing consequence

Even good docs become hard to use if they are not linked from obvious entrypoints.

### Owner seam

- README or START-HERE docs
- docs/operator index
- handoff docs
- evidence latest pointers

### Expected fix shape

Add an operator index that links:

- local iteration time budget doctrine
- local iteration gap register
- remaining product gap register
- Reboot doctrine
- harness-engine wiring
- latest evidence pointers
- current safe command set

### Proof shape

A docs verifier checks the index contains required operator docs.

## Routing rule

When a future agent patches product behavior, it must include two sections in the final report:

1. local iteration gap coverage matrix, if the patch touches harness/local iteration surfaces
2. remaining product gap impact notes, if the patch touches gameplay/product/advisory/safety surfaces

The product gap notes must say which product gaps were improved, which were intentionally not touched, and which new follow-up remains.

## Current highest-value product patches

1. enforce time budget doctrine in scripts and tests
2. add Reboot positive success classification
3. productize ForgeVerify fast/full mode and validation summaries
4. add latest evidence pointers
5. add doctrine-to-contract verifier
6. unify operator-facing GuildLoopReport
7. make smithing batch loop first-class
8. make trading batch loop first-class
9. formalize non-cheat mutation proof across all mutating operations
10. add operator docs index
