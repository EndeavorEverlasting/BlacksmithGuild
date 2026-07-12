# Evidence retention harness

```text
[TBG | Evidence Retention | policy: plan-first, verified archive, bounded apply]
```

The retention harness keeps ignored runtime evidence useful for later analysis without allowing generated data to grow unnoticed. Its executable policy is `.tbg/harness/policies/evidence-retention.policy.json`; its public entry point is the `ManageRetention` action in `scripts/harness/Invoke-TbgHarness.ps1`.

## Safety boundary

The default action is a plan. A plan inventories bytes and age, writes one machine-readable result under `artifacts/latest`, and does not create an archive or remove a source. Applying a plan requires the explicit `-ApplyRetention` switch.

Only immediate children of the policy's ignored `artifacts/` root can become bundles. The harness always protects `artifacts/latest`, `artifacts/current`, `artifacts/archive`, the two newest safe bundles, and every bundle newer than 14 days. It rejects any candidate that is tracked, is not ignored, contains a link or reparse point, or escapes the selected worktree. It archives at most four bundles per apply.

The 1 GiB `maximumLiveBytes` value is an observability threshold, not permission to bypass age or newest-bundle protection. Results report `liveCandidateBytes`, `sizePressureBytes`, and `projectedLiveBytesAfterApply`, so agents can see evidence pressure without deleting young or current data.

## Verification and preservation

Apply mode streams each selected bundle into a temporary ZIP and verifies every archived file by relative path, byte length, and SHA-256. It then re-hashes every source file to reject a concurrently changing bundle, publishes the ZIP, publishes and reads back a manifest containing the analytical file inventory, and only then removes the bounded source path. A collision, mutation, hash mismatch, link, or write failure produces `archive_failed_source_preserved` and leaves the source in place.

The archive host defaults to the source worktree. For a worktree that will later be removed, pass `-RetentionArchiveRepoRoot` for a durable registered worktree of the same repository. The harness compares Git common directories and rejects unrelated repositories. The destination remains bounded to that host's ignored `artifacts/archive` path.

### Explicit retired-worktree profile

The active profile never relaxes its 14-day age floor or newest-two protection. A known retired evidence lane uses a separate `retired_detached_worktree` profile and must include the unmistakable `-RetentionRetiredWorktree` switch. That profile lowers the closed-bundle age floor to three days and keeps no additional named bundles beyond the unconditional `latest`, `current`, archive, tracked-content, ignore, and reparse protections.

The retired switch is fail-closed unless the source is detached, has no tracked changes, its HEAD is an ancestor of `origin/main`, and the archive host is a different registered worktree with the same Git common directory. Every selected file must also accept an exclusive read handle. On Windows this detects a writer or other process holding an incompatible open handle; other platforms record the probe as best-effort. Apply repeats the exclusive probe after archive verification and source re-hashing, immediately before the already-bounded removal stage. The result records every prerequisite and locked path under `retiredWorktreeChecks`.

## Commands

Plan the active worktree:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\harness\Invoke-TbgHarness.ps1 -Action ManageRetention
```

Apply exactly the eligible bundles reported by a fresh plan:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\harness\Invoke-TbgHarness.ps1 -Action ManageRetention -ApplyRetention
```

Plan the detached PR #25 evidence lane while naming the protected primary checkout as archive host:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\harness\Invoke-TbgHarness.ps1 -Action ManageRetention -RetentionRepoRoot 'C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr25-launcher-evidence' -RetentionArchiveRepoRoot 'C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild' -RetentionRetiredWorktree
```

After reading `artifacts/latest/evidence-retention.result.json` in the source worktree, explicitly apply that same bounded policy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\harness\Invoke-TbgHarness.ps1 -Action ManageRetention -RetentionRepoRoot 'C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr25-launcher-evidence' -RetentionArchiveRepoRoot 'C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild' -RetentionRetiredWorktree -ApplyRetention
```

For the retired lane, add `-RetentionRetiredWorktree` to the plan command too; omitting it deliberately evaluates the safer active-worktree policy. Never remove a source worktree until the retired apply result is `retention_apply_complete`, every selected row is `archived_verified_source_removed`, all remaining rows are unconditional protected paths or too young, and the archive-host ZIP and manifest paths exist.

## Machine result

`artifacts/latest/evidence-retention.result.json` uses `tbg.evidence-retention.result.v1`. It records source and archive-host roots, branch, mode, policy, total and projected bytes, every discovered bundle and disposition, published archive hashes, manifests, and any source-preserving failure. The companion archive manifest uses `tbg.evidence-retention.archive.v1` and retains per-file path, byte count, and SHA-256 for later analysis.

Run the offline contract test with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\harness\Test-TbgEvidenceRetention.ps1
```

## Bounded gap: active runtime logs

This harness archives closed evidence bundles, including their logs. It intentionally does not rotate root-level live files such as `BlacksmithGuild_Phase1.log` while Bannerlord or a collector may still own them. Active-log size rotation must be implemented at the writer boundary with atomic rollover and an explicit closed-segment handoff into an ignored evidence bundle; retention can then archive those closed segments by age. Until that writer contract exists, size pressure is reported but never used to seize a live log.
