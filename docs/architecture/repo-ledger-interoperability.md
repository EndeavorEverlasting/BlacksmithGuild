# Repository Ledger Interoperability

## Purpose

BlacksmithGuild owns the **portable compatibility contract** for repo-local agent work ledgers. It does not own the work queued in another repository. The first donor is AxTask at pinned commit `9351c952b057ae4520b1ea0d388e1d8908f4c093`.

The canonical v1 contract content landed at BlacksmithGuild commit `429237aa41d8712d71859865c9be407ca23d8580`. Later validator, registry, documentation, or consumer-layout maintenance does **not** require consumers to repin unless the portable contract itself changes.

The goal is continuity without a central mutable task database: each repository keeps one local coordination ledger that agents can read, claim, update, validate, and hand off. Product code, runtime behavior, proof promotion, deployment authority, secrets, and task priority remain local to that repository.

## Ownership map

| Surface | Authority |
|---|---|
| Portable status/task/proof invariants, adoption schema, compatibility versioning | `EndeavorEverlasting/BlacksmithGuild` |
| AxTask donor behavior, `AXQ` namespace, current work, production/recovery rules | `EndeavorEverlasting/AxTask` |
| AgentSwitchboard `ASQ` queue, local validator, `Work class`, bounded/unbounded frontier, product/runtime truth | `EndeavorEverlasting/AgentSwitchboard` |
| Triage `TRQ` queue, validator/tests/hooks, Prompt Kit/product/artifact truth | `EndeavorEverlasting/web-excel-repair-triage` |

No consumer imports BlacksmithGuild at build or runtime. No BlacksmithGuild command mutates a consumer ledger. A consumer adoption manifest is compatibility metadata only.

### Authority reconciliation

AgentSwitchboard independently landed a strong repository-ledger implementation while this BlacksmithGuild extraction was in progress. That implementation is preserved. Its `agentswitchboard.repository-work-ledger.v1` identifier, `Work class` field, and `EXECUTE` / `DECOMPOSE` frontier are an **AgentSwitchboard-local compatibility and execution profile**, not a second portable or repository-family contract authority.

Triage likewise already landed a complete local adapter with its own ledger, validator, tests, CI, and Git hooks. Those surfaces remain triage-owned. Its portable provenance must point directly to BlacksmithGuild rather than using AgentSwitchboard as an authority proxy.

This reconciliation removes authority duplication without deleting useful consumer work.

## Portable contribution

The v1 portable harness contains:

- one repo-local coordination ledger for unfinished work;
- statuses `READY`, `CLAIMED`, `VERIFY`, `REVIEW`, `MERGE`, `OPERATOR`, `BLOCKED`, and `DONE`;
- claim-before-substantial-mutation behavior;
- continuation states that require continued execution when safe authorized work remains;
- exact gates and first executable next actions for `BLOCKED` / `OPERATOR`;
- strict `DONE`: acceptance gate satisfied, durable proof present, `Gate: none`, and `Next action: none; no safe actionable work remains`;
- concurrent-work preservation;
- exact-commit provenance through `RepoLedgerAdoption.v1`.

Consumers may strengthen local validation. They may not silently weaken these invariants while claiming v1 compatibility.

## Implemented consumer adapters

The contribution registry records the consumer layouts observed during authority reconciliation:

- **AxTask:** native donor ledger `.ai/WORK_QUEUE.md`; native validator `scripts/ai-harness/validate-work-queue.mjs`; `AXQ` remains AxTask-only.
- **AgentSwitchboard:** `.ai/WORK_QUEUE.md`; adoption metadata `.ai/harness/repository-work-ledger-adoption.json`; validator `scripts/Test-RepositoryWorkLedgerContract.ps1`; tests `tests/test_repository_work_ledger_contract.py` and `tests/test_repository_work_ledger_frontier.py`; CI `.github/workflows/repository-work-ledger-contract.yml`; local frontier `scripts/Get-RepositoryWorkLedgerFrontier.ps1`.
- **Triage:** `.ai/WORK_QUEUE.md`; adoption metadata `.ai/work-ledger-adoption.json`; validator `scripts/validate_repository_work_ledger.py`; test `tests/test_repository_work_ledger.py`; CI `.github/workflows/repository-work-ledger-contract.yml`; hooks `.githooks/pre-commit` and `.githooks/pre-push`.

The registry's `observedAtCommit` values are evidence of the layouts inspected during reconciliation. They are not moving runtime dependencies. Compatibility pins fail closed; layout evidence is refreshed only when BlacksmithGuild intentionally claims a newer consumer shape.

## Contribution classifications

- **portable harness:** ledger lifecycle and invariants — adopted;
- **reusable skill:** reference-only — reuse `agent-skill-factoring` and `continuum-interoperability`; do not create a competing skill authority;
- **shared schema/evidence packet:** `RepoLedgerAdoption.v1` — adopted as compatibility metadata, never task/runtime proof;
- **adapter:** consumer-local ledger, namespace, intake pointer, and validator — consumer-owned;
- **reference-only doctrine:** AxTask queue prose and BlacksmithGuild factoring/interoperability doctrine — referenced, not copied as product law;
- **domain-specific:** AxTask `AXQ-*` task bodies, authority id, Render/Neon recovery state, production recovery sequencing — rejected from extraction;
- **domain-specific local extension:** AgentSwitchboard `Work class`, bounded/unbounded semantics, and compact frontier — preserved locally and rejected as a portable v1 requirement.

## Version and stale-reference contract

Consumers pin both the BlacksmithGuild contract and the AxTask donor with full lowercase 40-character commit SHAs. `main`, `HEAD`, branches, tags, and short SHAs are invalid. A changed portable-contract pin is an explicit compatibility update and requires the consumer's own validator to pass again.

**Do not repin consumers for validator-only, documentation-only, registry-only, or CI-only BlacksmithGuild changes.** The pin changes only when the portable contract genuinely changes.

Breaking changes to statuses, required task fields, durable proof semantics, or the strict `DONE` boundary require a new `RepoLedgerInteroperability` major version.

## Source provenance

The canonical donor sources and blob pins live in `.tbg/harness/repo-ledger-contributions.registry.json`. The v1 portable contract intentionally excludes any unverified or stale donor path. In particular, `.ai/AUTHORITY_MAP.md` is **not** a v1 donor source; AxTask's verified authority surface is `.ai/authority.json` at the pinned donor commit.

## Validation

From BlacksmithGuild:

```powershell
pwsh -NoLogo -NoProfile -File scripts/tbg/Test-TbgRepoLedgerInteroperability.ps1
git diff --check
```

The validator checks contract/schema/registry parseability, the canonical portable-contract commit, exact donor commit and blob pins, all six contribution classifications, the three real consumer layouts and unique namespaces, AgentSwitchboard local-extension isolation, no-central-runtime-queue boundaries, and negative stale-reference probes.

Each consumer must separately validate its own adoption manifest and local queue. Passing this BlacksmithGuild validator proves only the shared contract boundary; it does not prove any consumer task complete, deployed, merged, or live.

## Compatibility upgrade procedure

1. Pin and inspect the new donor/contract commit rather than following a moving ref.
2. Change BlacksmithGuild portable contract metadata only when the portable contract genuinely changes.
3. For registry/docs/validator maintenance, leave consumer portable-contract pins unchanged.
4. For a genuine portable-contract change, update each adopting consumer's local manifest/validator pin.
5. Run that consumer's queue validator and repository-required checks.
6. Commit/push/PR independently so one repository cannot silently promote another repository's proof.
