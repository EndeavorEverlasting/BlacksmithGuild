# Skill: harness-maturity

Use this skill when a sprint asks whether the app should become more harness-driven, whether logic belongs in harness plumbing or a narrow skill/domain module, or whether a proposed refactor is real architecture work versus ceremony.

## Use when

- A change claims to improve harness maturity, agent readiness, workflow governance, or safety.
- A repeated orchestration pattern should maybe become a workflow contract, policy guard, registry, adapter, or evidence/reporting surface.
- A domain behavior is becoming hard to audit because config, permissions, logging, retries, rollback, or evidence are mixed into it.
- An agent proposes moving logic because the app should be closer to a high-harness automation-first architecture.
- A sprint adds composed E2E profiles, artifact registration, sprint capsules, or AgentSwitchboard/SysAdminSuite consumer handoffs.
- Save/version drift is blocking multiple launcher/runtime workflows and needs one read-only compatibility classifier, artifact shape, and consumer gate instead of repeated model judgment.
- A Bannerlord version change needs deterministic probes that identify compile/API/dynamic-binding/save/runtime-cert gaps and route them into executable owner-lane sprints.

## Do not use when

- The sprint is implementing route, trade, smithing, save mutation, launcher actuation, or runtime behavior.
- The only goal is to increase a harness percentage.
- The change would hide game or economy behavior inside generic plumbing.
- Static harness changes would be used to claim live runtime proof.

## Read first

1. `AGENTS.md`
2. `CODEBASE_MAP.md`
3. `.tbg/skills/manifest.json`
4. `.tbg/workflows/harness-skill-maturity.contract.json`
5. `.tbg/workflows/end-to-end-validation.contract.json` when composed validation is in scope
6. `.tbg/workflows/tbg-sprint-capsule.contract.json` when continuation or cross-repository consumption is in scope
7. `docs/architecture/harness-skill-maturity.md`
8. `docs/architecture/local-agent-harness.md`
9. `docs/architecture/effective-policy-english-reports.md`
10. `.tbg/workflows/save-compatibility-classification.contract.json` when save/version compatibility is the cross-cutting blocker
11. `.tbg/workflows/version-upgrade-impact-probe.contract.json` when the installed/upstream game version moved or candidate-version migration work is being planned

## Owned scope

- `.tbg/skills/**`
- `.tbg/workflows/*harness*`, E2E, handoff, and architecture workflow contracts
- `.tbg/harness/manifest.json`
- `.tbg/harness/e2e/**`, consumer registries, operation APIs, artifact roles, and their schemas
- `scripts/tbg/*EndToEnd*` and `scripts/tbg/*SprintCapsule*`
- read-only compatibility/upgrade-impact adapters, reducers, publishers, and validators under `scripts/tbg/**` when they do not launch, load, mutate product/runtime state, or promote runtime proof
- `AGENTS.md`, `CLAUDE.md`, and `CODEBASE_MAP.md` when routing agents to canonical authorities
- Architecture/operator/handoff docs that explain harness versus skill/domain boundaries

## Forbidden scope

- `src/**` runtime behavior unless a separate feature/runtime skill explicitly owns it.
- Launcher scripts, command inbox writes, save mutation, or Bannerlord execution.
- Runtime proof claims.
- Large framework rewrites without a named current pain point.
- A parallel skill/router tree that competes with `.tbg/skills/manifest.json`.
- Automatic GitHub issue creation from pre-push or CI; remote sprint publication requires explicit operator invocation.

## Classification rule

Classify each proposed movement as one of three outcomes.

| Outcome | Use when | Examples |
|---|---|---|
| `harness` | The logic is cross-cutting and protects multiple workflows, agents, runners, or engines. | config loading, dependency injection, capability routing, permission gates, evidence capture, retries, rollback, metrics, English/JSON reporting, UI shims, schemas, adapters, save/game compatibility registries, version-upgrade impact reducers, sprint packets, and consumer gates. |
| `skill_or_domain` | The logic is stateless, side-effect-free, or domain-specific. | route scoring, smithing advice, market math, save-byte/version interpretation, economy rules, candidate API repair inside the affected product/domain file, focused validators. |
| `defer_or_reject` | The change is only percentage chasing, crosses forbidden runtime scope, or adds ceremony without solving drift/safety/replay/audit load. | generic plugin framework without recurring duplication, moving gameplay decisions into harness wrappers, broad rewrite before a pain point is proven. |

### Save compatibility split

When save versions are the blocker, split responsibility deliberately:

1. **Harness** owns discovery contracts, role/version classifications, artifact shapes, terminal states, proof ceilings, and the launcher consumer gate.
2. **Narrow save-domain helper** may read bytes and interpret version metadata, but remains side-effect-free and read-only.
3. **Launcher-lifecycle** owns selecting/loading an already-classified target and proving the in-game load boundary.
4. **Runtime** owns creating or overwriting a save. After creation, the read-only classifier records the new bytes/version before that save can be reused automatically.

A filename such as `Disposable` or `DevStart` is role metadata only and never overrides the version gate.

### Version-upgrade impact split

When Bannerlord changes version/build:

1. **Game compatibility** observes the installed/upstream/support baseline; it does not diagnose source breakage.
2. **Version-upgrade impact harness** inventories the nine candidate assembly surfaces, checks candidate paths, runs a Debug/no-install compile with isolated outputs, inventories dynamic bindings, compares module dependency versions, invalidates stale save/runtime certification, and reduces findings into sprint contracts.
3. **Product/domain owner** repairs the exact compile/API or dynamic-binding assumption named by the finding. The harness does not patch `src/**` for it.
4. **Save compatibility** reclassifies intended saves against the new exact version.
5. **Runtime evidence certification** re-proves version-sensitive launcher/load/readiness/governor/trade behavior only after static/build/save prerequisites pass.
6. **Remote emission** is a sanitized issue draft by default. `ForgeVersionUpgradePublish.cmd -PublishIssue` is the only issue-write path and requires explicit operator invocation plus existing `gh` authentication.

A green compile is necessary evidence, not a promotion to dynamic-binding or live-runtime compatibility.

## Done gate

A harness maturity sprint is done only when:

- the current pain point is named;
- the change is classified as harness, skill/domain, or rejected;
- the smallest owned surface is changed;
- executable contracts or current source remain authoritative;
- no runtime proof is claimed from static work;
- JSON files parse if JSON changed;
- the composed `default-static` E2E profile passes when the E2E surface changed;
- a schema-backed capsule records consumers, proof ceiling, claims not made, and one exact next command when another lane must continue;
- `git diff --check` passes or the exact local blocker is recorded.

For version-upgrade work specifically, the done gate additionally requires the probe fixture reducer, owner routing, sprint packet, sanitized issue draft, explicit publisher boundary, harness completeness, and both PowerShell host validations to pass.

## Common traps

- Treating `90 percent harness` as a quota instead of a warning that low-trust automation needs lots of guardrails.
- Moving domain behavior into harness, making the app safer-looking but harder to reason about.
- Adding a plugin registry before two or more real skill families need it.
- Forgetting that docs and skills explain contracts; they do not become a second policy engine.
- Replacing the mature `.tbg` router with a client-specific directory tree.
- Treating a disposable-looking filename as proof that the file is compatible with the installed game.
- Letting a successful prelaunch parse masquerade as proof that Bannerlord actually loaded the save.
- Treating a version-number bump as an instruction to blindly edit every dependency version.
- Treating a green candidate compile as proof that reflection/Harmony targets, saves, launcher flow, or runtime behavior still work.
- Opening generic “update the mod” issues without machine findings, owner lane, exact first action, artifact, and completion gate.

## Handoff output

End with:

- pain point;
- classification decision;
- changed surfaces;
- validation run;
- skipped checks;
- remaining risk;
- exact next command;
- `tbg.sprint-capsule.v1` when a later agent or repository consumes the result.
