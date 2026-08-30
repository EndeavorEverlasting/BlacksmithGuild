# PR #32 Guardrail Preservation Matrix

```text
[TBG | STALE PR RECOVERY | WAVE D2 PR #32 | 2026-08-29]
```

## Source

| Field | Value |
|---|---|
| Source PR | #32 `docs(guardrails): add default app guardrail map` |
| Source head | `d004aead5b482005bf03e77e8b181a11680b6f46` |
| Source base | `agent-feedback-stop-hook` |
| Source state | closed without merge |
| Reconciliation floor | `main@21d7bce4c6688bfbc95e9f60a2ce8037d163f2c2` |
| Lane | stale-PR guardrail reconciliation |
| Proof ceiling | repository contract / static test only |

PR #32 is a parts bin, not a merge candidate. Its useful rules must map to maintained current-main authorities or be rejected explicitly. The source branch must not become a second guardrail constitution.

## Per-file classification

| PR #32 path | Decision | Current owner / disposition |
|---|---|---|
| `docs/handoff/default-guardrails.md` | **superseded** | `docs/harness-doctrine.md`, `.tbg/harness/policies/harness-doctrine.policy.json`, and `scripts/tbg/Test-TbgHarnessDoctrine.ps1` now own repository-wide execution, proof separation, launcher/campaign readiness boundaries, user takeover, correlated handoffs, and completion discipline. |
| `docs/handoff/guardrail-map.manifest.json` | **superseded** | `.tbg/harness/manifest.json` plus the harness-doctrine policy are the maintained registry/policy authority. Creating a second whole-app guardrail manifest would violate the current existing-authority-before-invention rule. |
| `docs/handoff/proof-claim-discipline.md` | **superseded** | Current harness doctrine owns `contract -> harness -> static test -> build -> launcher -> command ACK -> behavior observed -> live runtime`; `.tbg/workflows/end-to-end-validation.contract.json` carries the same proof order into executable composed validation. `.github/workflows/checkpoint-discipline.yml` separately protects checkpoint/completion semantics. |
| `docs/handoff/runtime-contamination-doctrine.md` | **superseded by stronger lifecycle contracts** | Harness doctrine/policy require fresh frozen launcher identity, background-safe/mouse-independent operation by default, explicit authority for foreground fallback, verified transitions, observer overlap, campaign-readiness gating, and authority-neutral readiness events. `.tbg/workflows/launcher-to-campaign-event-continuity.contract.json` is the canonical launcher-to-campaign specialization. |
| `docs/handoff/campaign-action-evidence-schema.md` | **concept retained; proposed parallel artifact rejected** | Durable generic observations/evidence/claims are owned by `.tbg/workflows/state-envelope.contract.json`; campaign engine action handoffs and branch-specific before/after proof are already represented by `docs/handoff/governor-activity-handoff-contract.md` and its current implementation. Do **not** revive `BlacksmithGuild_CampaignActionEvidence.json` as a second generic authority. |
| `scripts/verify-default-guardrails-contract.ps1` | **superseded** | Current executable ownership is split across focused validators, especially `scripts/tbg/Test-TbgHarnessDoctrine.ps1`, `scripts/tbg/Test-TbgStateEnvelope.ps1`, the launcher/campaign continuity validators, and composed E2E validation. This preservation validator checks the mapping without reviving the stale verifier. |

## Unique-field disposition

### Proof and checkpoint distinctions — retained

PR #32 required separation among build, verifier/static, runtime, visible behavior, and product completion. Current harness doctrine uses a more precise monotonic proof ladder and explicitly states that parser success, checkpoint, command ACK, launcher handoff, or a sanitized capsule cannot prove product behavior or live runtime completion.

**Disposition:** retained in stronger current authority; no replay.

### Manual-input / focus / pause contamination — retained as authority/lifecycle rules

The stale PR framed foreground loss, manual input, and paused campaign time as proof contamination. Current doctrine expresses the safer general contract: background-safe and mouse-independent by default; foreground/coordinate fallback requires explicit task-specific authority and transition verification; campaign readiness and launcher handoff do not grant gameplay authority; downstream task-specific proof remains mandatory.

**Disposition:** semantic intent retained in stronger current lifecycle and authority contracts; do not recreate a parallel contamination classifier from the stale branch.

### Campaign action evidence — retained without duplicate schema authority

PR #32 proposed a single `TbgCampaignActionEvidence.v1` / `BlacksmithGuild_CampaignActionEvidence.json` artifact. Current main has since separated the problem into durable typed state (`observation`, `evidence`, `claim`, `constraint`, `objective`, `work-item`, `capability`) and domain/governor handoff evidence. The governor contract requires branch-specific evidence such as arrival checkpoints, inventory/gold deltas, stamina/material deltas, roster deltas, and explicit blocked/terminal states.

**Disposition:** preserve the evidence discipline; reject the stale one-file generic schema/output because it would duplicate maintained state and governor authorities.

### Engine boundaries — retained

PR #32 required engines to recommend/observe while orchestration and authority govern dispatch and evidence governs completion. Current governor activity handoff contract formalizes `ObservedOnly`, `Recommended`, `Dictated`, `Blocked`, and `Terminal` authority modes and requires one governor-owned interpretation of local checkpoints.

**Disposition:** retained and implemented by current authority; no replay.

### Byte-safe replacement helper — rejected as a PR #32 guardrail owner

The old map listed a future byte-safe replacement helper. Current repository hygiene already has PowerShell BOM enforcement plus diff hygiene in composed validation. A generic mutation helper is not required to preserve PR #32's guardrail semantics and should not be invented from a stale doctrine PR without a concrete current mutation defect.

**Disposition:** rejected from this replay; future helper work requires a current failing use case and its own owner.

### Agent feedback / stop-hook outputs — excluded from this disposition

PR #32 mentioned `BlacksmithGuild_AgentFeedback.json`, remediation planning, and stop-hook outputs because it was stacked on PR #31. Those surfaces belong to the separate PR #28-#31 stale-recovery lineage and are **not** silently declared complete by the PR #32 disposition.

**Disposition:** excluded; preserve dependency boundaries.

## Explicit rejections

1. Reopen, merge, rebase, or wholesale cherry-pick PR #32.
2. Restore `docs/handoff/default-guardrails.md` as a competing repository-wide constitution.
3. Restore `guardrail-map.manifest.json` as a second manifest authority.
4. Treat `BlacksmithGuild_CampaignActionEvidence.json` as a new generic evidence authority beside the state envelope and governor activity handoffs.
5. Use a static guardrail map to claim launcher, campaign, gameplay, movement, trade, smithing, or live-runtime proof.
6. Mark PR #28, #29, #30, or #31 complete as a side effect of disposing PR #32.

## Validation

The focused verifier is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Test-TbgPr32GuardrailPreservation.ps1
```

It is also invoked by the stale-PR recovery E2E adapter, so composed `default-static` proof fails if this mapping or any required current authority disappears.

## Terminal ledger gate

After this matrix is merged and the focused/static provider gates are green, update PR #32 **only through the registered progress producer**:

```powershell
.\ForgeStalePrProgress.cmd set -PrNumber 32 -Status superseded_recorded -Disposition "PR #32 guardrail intent is preserved by maintained harness doctrine, state-envelope, launcher/campaign continuity, governor activity handoff, and focused validators; stale parallel guardrail/evidence authorities are rejected." -Evidence "docs/handoff/pr32-guardrail-preservation-matrix-20260829.md; PR #169 merged 21d7bce4c6688bfbc95e9f60a2ce8037d163f2c2; <PR32 reconciliation merge SHA>" -NextAction "No further replay work remains for PR #32."
```

Do not hand-edit `docs/handoff/stale-pr-cherry-pick-progress.md`; the registered producer regenerates it from the canonical ledger.

## Proof boundary

This matrix proves only a repository-level preservation/rejection mapping against current tracked authorities. It does not prove runtime behavior or disposition PR #32 in the canonical progress ledger until the registered producer records that terminal state after this reconciliation is merged.
