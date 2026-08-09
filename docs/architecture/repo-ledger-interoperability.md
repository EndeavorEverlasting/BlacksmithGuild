# Repository Ledger Interoperability

## Purpose

BlacksmithGuild owns the **portable compatibility contract** for repo-local agent work ledgers. It does not own the work queued in another repository. The first donor is AxTask at pinned commit `9351c952b057ae4520b1ea0d388e1d8908f4c093`.

The goal is continuity without a central mutable task database: each repository keeps one local coordination ledger that agents can read, claim, update, validate, and hand off. Product code, runtime behavior, proof promotion, deployment authority, secrets, and task priority remain local to that repository.

## Ownership map

| Surface | Authority |
|---|---|
| Portable status/task/proof invariants and adoption schema | `EndeavorEverlasting/BlacksmithGuild` |
| AxTask donor behavior, `AXQ` namespace, current work, production/recovery rules | `EndeavorEverlasting/AxTask` |
| AgentSwitchboard queue contents, `ASQ` namespace, validator, repo-family/product authority | `EndeavorEverlasting/AgentSwitchboard` |
| Triage queue contents, `TRQ` namespace, validator, product/artifact authority | `EndeavorEverlasting/web-excel-repair-triage` |

No consumer imports BlacksmithGuild at build or runtime. No BlacksmithGuild command mutates a consumer ledger. A consumer adoption manifest is compatibility metadata only.

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

## Contribution classifications

- **portable harness:** ledger lifecycle and invariants — adopted;
- **reusable skill:** reference-only — reuse `agent-skill-factoring` and `continuum-interoperability`; do not create a competing skill authority;
- **shared schema/evidence packet:** `RepoLedgerAdoption.v1` — adopted as compatibility metadata, never task/runtime proof;
- **adapter:** consumer-local ledger, namespace, intake pointer, and validator — consumer-owned;
- **reference-only doctrine:** AxTask queue prose and BlacksmithGuild factoring/interoperability doctrine — referenced, not copied as product law;
- **domain-specific:** AxTask `AXQ-*` task bodies, authority id, Render/Neon recovery state, production recovery sequencing — rejected from extraction.

## Version and stale-reference contract

Consumers pin both the BlacksmithGuild contract and the AxTask donor with full lowercase 40-character commit SHAs. `main`, `HEAD`, branches, tags, and short SHAs are invalid. A changed pin is an explicit compatibility update and requires the consumer's own validator to pass again.

Breaking changes to statuses, required task fields, durable proof semantics, or the strict `DONE` boundary require a new `RepoLedgerInteroperability` major version.

## Source provenance

The canonical donor sources and blob pins live in `.tbg/harness/repo-ledger-contributions.registry.json`. The v1 portable contract intentionally excludes any unverified or stale donor path. In particular, `.ai/AUTHORITY_MAP.md` is **not** a v1 donor source; AxTask's verified authority surface is `.ai/authority.json` at the pinned donor commit.

## Validation

From BlacksmithGuild:

```powershell
pwsh -NoLogo -NoProfile -File scripts/tbg/Test-TbgRepoLedgerInteroperability.ps1
git diff --check
```

The validator checks contract/schema/registry parseability, exact donor commit and blob pins, all six contribution classifications, unique consumer namespaces, no-central-runtime-queue boundaries, and negative stale-reference probes.

Each consumer must separately validate its own adoption manifest and local queue. Passing this BlacksmithGuild validator proves only the shared contract boundary; it does not prove any consumer task complete, deployed, merged, or live.

## Compatibility upgrade procedure

1. Pin and inspect the new donor/contract commit rather than following a moving ref.
2. Change BlacksmithGuild contract metadata only when the portable contract genuinely changes.
3. In each adopting consumer, update only its local adoption manifest/validator pin.
4. Run that consumer's queue validator and repository-required checks.
5. Commit/push/PR independently so one repository cannot silently promote another repository's proof.
