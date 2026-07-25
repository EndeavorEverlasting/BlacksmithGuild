# PR #101 / #102 Preservation Matrix — 2026-07-25

## Scope

Repository: `EndeavorEverlasting/BlacksmithGuild`

Cleanup base: `main` at `d57ddce42be6480ea92e9882df0871516bbcbc13`.

This matrix records preservation before closing stale mixed-scope PRs. Product C# is not replayed by this cleanup.

## Preservation refs

| Source | Exact source head | Preservation branch |
|---|---|---|
| PR #101 | `38d0223685bbff6b77e212b3aa24f0b364574f76` | `preserve/pr101-runtime-product-20260725` |
| PR #102 | `8e60b9dc5488234d12c7d2c088d3754cb097038a` | `preserve/pr102-runtime-product-20260725` |

The preservation refs are additive and do not rewrite or delete the source branches.

## PR #20

Disposition: `superseded_recorded`.

The governor activity handoff contract is already on `main`. `docs/handoff/governor-activity-handoff-contract.md` has blob `591866d2c03732494f3d3e340addf5a5138f50fa`; `src/BlacksmithGuild/GuildLoop/GovernorActivityHandoff.cs` is also present on `main`. PR #20 is closed and retained as historical provenance.

## PR #101

Prior state: open, unmergeable, 14 commits ahead of its merge base and 39 commits behind current `main`.

### Already preserved/evolved on main

- governor activity handoff contract and implementation;
- segmented full-campaign handoff certification and tests;
- related certification doctrine that prevents movement-only proof collapse.

### Replayed by this cleanup

- `.tbg/harness/schemas/tbg-session-intent.schema.json`;
- `.tbg/harness/policies/session-intent.policy.json`.

The replay was repaired before merge:

- both artifacts are explicitly `contract_only_product_integration_deferred`;
- proof ceiling is `contract`;
- session intent is context/requested posture, never an authority grant;
- human/unknown state fails closed;
- `commitSha` spelling is corrected;
- `scripts/tbg/Test-TbgSessionIntentContract.ps1` validates the contract;
- `.tbg/harness/test-catalog.d/core/session-intent-contract.test.json` routes the validator through `ForgeTest.cmd`.

### Product/runtime remainder

Preserved at `preserve/pr101-runtime-product-20260725` and replaced as active tracking by issue #135. Product/runtime reconstruction must start from current `main`; the stale branch must not be merged wholesale.

## PR #102

Prior state: open, unmergeable, 39 commits ahead of its merge base and 39 commits behind current `main`.

### Superseded harness work

- canonical harness doctrine and its validator are already on `main`;
- current launcher/runtime continuity contracts supersede branch-local launch doctrine;
- `Invoke-TbgGameCompatibility.ps1` already compares built and installed DLL SHA-256 values, so the branch-local DLL-identity validator would duplicate an existing gate;
- current window intelligence/lifecycle contracts supersede a title-prefix-only focus helper as a universal authority surface.

### Rejected as-is

- stale `Phase1.log` without a terminal token must not be promoted to crash proof;
- last marker must not be promoted to root cause;
- tracked raw crash evidence is not canonical remote proof;
- hard-coded live-cert scripts and blind coordinate navigation are not safe universal harness entry points;
- hard-coded version/beta assertions require fresh external evidence before use.

### Product/runtime remainder

Escape-menu and pause/runtime product ideas remain potentially useful. Exact source is preserved at `preserve/pr102-runtime-product-20260725`; active reconstruction is issue #136 and must comply with current crash-observability, process-ownership, save-safety, and proof-ceiling doctrine.

## PR #132 correction

GitHub records PR #132 as one merged commit with five changed files, 554 additions, and one deletion. Larger file counts associated with its rebased local history are not the PR's unique net diff.

## Close criteria

PR #101 and PR #102 may be closed as **superseded after preservation**, not as “merged via rebase.” Closing comments must name the preservation branch, replay destination, and replacement issue.
