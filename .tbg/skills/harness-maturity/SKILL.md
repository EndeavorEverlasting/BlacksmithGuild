# Skill: harness-maturity

Use this skill when a sprint asks whether the app should become more harness-driven, whether logic belongs in harness plumbing or a narrow skill/domain module, or whether a proposed refactor is real architecture work versus ceremony.

## Use when

- A change claims to improve harness maturity, agent readiness, workflow governance, or safety.
- A repeated orchestration pattern should maybe become a workflow contract, policy guard, registry, adapter, or evidence/reporting surface.
- A domain behavior is becoming hard to audit because config, permissions, logging, retries, rollback, or evidence are mixed into it.
- An agent proposes moving logic because the app should be closer to a high-harness automation-first architecture.

## Do not use when

- The sprint is implementing route, trade, smithing, save, launcher, or runtime behavior.
- The only goal is to increase a harness percentage.
- The change would hide game or economy behavior inside generic plumbing.
- Static harness changes would be used to claim live runtime proof.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `.tbg/workflows/harness-skill-maturity.contract.json`
4. `docs/architecture/harness-skill-maturity.md`
5. `docs/architecture/local-agent-harness.md`
6. `docs/architecture/effective-policy-english-reports.md`

## Owned scope

- `.tbg/skills/**`
- `.tbg/workflows/*harness*` and architecture workflow contracts
- `.tbg/harness/manifest.json`
- `AGENTS.md` and client adapter docs when they are routing agents to skills
- Architecture docs that explain harness versus skill/domain boundaries

## Forbidden scope

- `src/**` runtime behavior unless a separate feature/runtime skill explicitly owns it.
- Launcher scripts, command inbox writes, save mutation, or Bannerlord execution.
- Runtime proof claims.
- Large framework rewrites without a named current pain point.

## Classification rule

Classify each proposed movement as one of three outcomes.

| Outcome | Use when | Examples |
|---|---|---|
| `harness` | The logic is cross-cutting and protects multiple workflows, agents, runners, or engines. | config loading, dependency injection, capability routing, permission gates, evidence capture, retries, rollback, metrics, English/JSON reporting, UI shims, schemas, adapters. |
| `skill_or_domain` | The logic is stateless, side-effect-free, or domain-specific. | route scoring, smithing advice, market math, save-identity interpretation, economy rules, focused validators. |
| `defer_or_reject` | The change is only percentage chasing, crosses forbidden runtime scope, or adds ceremony without solving drift/safety/replay/audit load. | generic plugin framework without recurring duplication, moving gameplay decisions into harness wrappers, broad rewrite before a pain point is proven. |

## Done gate

A harness maturity sprint is done only when:

- the current pain point is named;
- the change is classified as harness, skill/domain, or rejected;
- the smallest owned surface is changed;
- executable contracts or current source remain authoritative;
- no runtime proof is claimed from static work;
- JSON files parse if JSON changed;
- `git diff --check` passes or the exact local blocker is recorded.

## Common traps

- Treating `90 percent harness` as a quota instead of a warning that low-trust automation needs lots of guardrails.
- Moving domain behavior into harness, making the app safer-looking but harder to reason about.
- Adding a plugin registry before two or more real skill families need it.
- Forgetting that docs and skills explain contracts; they do not become a second policy engine.

## Handoff output

End with:

- pain point;
- classification decision;
- changed surfaces;
- validation run;
- skipped checks;
- remaining risk;
- exact next command.
