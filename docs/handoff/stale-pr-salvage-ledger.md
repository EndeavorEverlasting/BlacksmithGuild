# Stale PR Salvage Ledger

## Outcome

The open historical lanes are now classified as recoverable parts, not disposable branches and not merge-ready features. The machine-readable source of truth is [`.tbg/harness/stale-pr-salvage-ledger.json`](../../.tbg/harness/stale-pr-salvage-ledger.json). It records the exact source head, selected useful commits, collision surface, maintained replacement, validation gate, branch-retention condition, and safe close order for PRs #2, #5, #6, #8, #9, #20, #24, #28-#35, and #38.

This ledger is deliberately stricter than a stale-branch list:

```text
inspect exact source -> classify useful SHA -> replay or reject on current lineage
                     -> validate current result -> link replacement
                     -> close PR -> archive evidence -> delete branch/worktree
```

Closing a PR preserves the GitHub review record. Deleting its branch is a separate, later operation and is forbidden until the ledger's retention conditions pass.

## Maintained foundations discovered during this audit

The remote default branch advanced during the sprint. `origin/main` now points to `60daeb4c8472027ee7eda9d532b9fc01541605d0`, the merge of PR #46. PR #46 already implements the requested local evidence relay:

```text
ForgeAgentStatus.cmd
scripts/tbg/New-TbgChatPacket.ps1
docs/handoff/local-agent-status-relay.md
```

It emits bounded Markdown and JSON, copies the Markdown packet to the clipboard unless disabled, can optionally post the packet to a PR, and caps command/artifact excerpts. Do not fork a second status-relay implementation into PR #43. After the current route lane incorporates current `main`, the operator entrypoint is:

```cmd
ForgeAgentStatus.cmd -PrNumber 43
```

Optional GitHub relay:

```cmd
ForgeAgentStatus.cmd -PrNumber 43 -PostPrComment
```

The other maintained replacement references are:

| Foundation | Exact reference | Replaces or constrains |
|---|---|---|
| Route workflow contracts | `aa015a5` (PR #36) | Cumulative route workflow pieces on #38 |
| Local agent harness | `809f054351fc2f98f21eee8ac7f8f85adb34f8d2` (PR #39) | Historical feedback/hook architecture on #28-#31 |
| Effective English reporting | `5c20e95` (PR #41) | Historical writers that bypass effective policy context |
| Agent status relay | `60daeb4c8472027ee7eda9d532b9fc01541605d0` (PR #46) | Manual terminal-to-chat handoff |
| Route/operator lane | PR #43, snapshot head `39b196e7ef2e4fa7bf29561441eaf34737b019c8` | Route start, per-engine automation, and unattended proof |
| Replay doctrine | PR #45 | Safe current-main replay and replacement-PR policy |

## PR disposition map

| PR | Exact head | Useful delta | Collision / disposition |
|---:|---|---|---|
| #2 | `61090349037c89d4bcbc1c0e3fd4a3651333e7e6` | Identity/disposition schema | Replay schema path on current main; review the one source-line change separately. |
| #5 | `9ec17ac3fc4bbc6acc4f1f1d472b9e878a91f247` | Sell reflection, mission selection, bounded multi-cycle loop, cert runner | High collision with current GuildLoop/MapTrade; reconstruct contract-first and require fresh sell proof. |
| #6 | `2b5b7e104d1ac095cef9db738e0b56beec939643` | Second-leg transition and arrival evidence | Depends on #5; replay after the sell contract has a maintained home. |
| #8 | `d8a0e0e209846c230e129bb82f288978d8a757aa` | F7 history and fail-closed principles | Newer main runner lineage replaces it. Link the replacement and close; never merge the stale scripts. |
| #9 | `ef0c95ca4f541cca579efe81d039559c1724fb8c` | Historical bisect evidence | Archive as history, never as current PASS; earliest safe close candidate. |
| #20 | `2839b37e0ff6cd9eb24d649a5b6d17fb14c738b0` | Governor-to-worker activity handoff | Most actionable functional replay. Port the model/tests, not old GuildLoop hunks. |
| #24 | `e3c0b14ee3918c87f3e28824ac08a80e673a3bec` | Profile/route helpers, wrappers, and tests | Reconcile with PR #43's per-engine authority; do not create a second control plane. |
| #28 | `1655925e5124c3e0b7a3567766cf3dd216da8eda` | Feedback manifest, review doctrine, verifier | Map useful fields into PR #39/#41 schemas. |
| #29 | `c8bab9873bfb5d6abe041b09040752dc2ff6f169` | Feedback writer and verifier | Adapt only as an effective-policy-context consumer. |
| #30 | `b6f126b24f296bb01afeec455204d29a3a53b088` | Pure remediation planner | Port behind current result schemas with fixture replay. |
| #31 | `c4a6c93e90bab382f3bbc58bf2d0b21623e59745` | Trigger map, hook schema, executable | Reconcile trigger fields; do not restore a parallel done gate. |
| #32 | `d004aead5b482005bf03e77e8b181a11680b6f46` | Guardrail map and proof discipline | Field-level merge into current guardrail/evidence policies. |
| #33 | `340602946dee8eab4b4defd1e37e2be3a5569090` | Pure classifiers/helpers and proof ladder | Replay only with current-schema adapters and tests proving a stub cannot pass. |
| #34 | `63610beefdda0beef269ee4f3f8665cc04e0be5a` | Timeless worktree rules | Factual map is superseded; preserve rules and close early. |
| #35 | `4b291a96b2763988d6c4a37feabe473cd88978b3` | Process detection and focus ownership | Salvage optional focus/process helpers only. Human focus cannot gate unattended proof. |
| #38 | `e618349b7575dc6379cb7a8b378df6ec5be4d282` | Worktree/stop policy, activity ledger, proof validator | Reconstruct unique pieces from current main; the broad conflicted branch is never a base. |

`git cherry` reported every listed source commit as non-patch-equivalent to the PR #43 snapshot. That is a warning to inspect and replay narrowly, not proof that every old line remains desirable. Some concepts have newer maintained implementations with different patch identities.

## Safe close and delete order

The machine ledger owns the authoritative order. The human-readable sequence is:

1. Close historical-only #9 and stale-map #34 after this ledger/replacement links are posted.
2. Close superseded harness/tooling children before their roots: #8, #35, #33, #32, #31, #30, #29, then #28.
3. Close focused replay lanes after their current-main replacements validate: #38, #24, #20, then #2.
4. Close the runtime child before its parent only after fresh current-head behavior is proved or explicitly rejected: #6, then #5.

Closing is not deletion. For each source branch, the cleanup harness must prove all of the following before `git push origin --delete <branch>`:

- the source PR is closed or merged;
- replacement/rejection is reachable from `main`;
- no worktree holds the branch;
- ignored runtime evidence has an archive manifest or explicit discard record;
- the exact source head is still reachable from the PR or a named archive ref.

The detached runtime-evidence worktree and its multi-gigabyte ignored artifacts therefore remain protected until an archive manifest records size, hashes, source head/session, retention class, and archive destination. Moving them into an archive is allowed only after the manifest is durable; silently deleting them is not hygiene.

## Agent-run validation

Static ledger validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-stale-pr-salvage-ledger.ps1
```

Static validation plus exact GitHub head comparison:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-stale-pr-salvage-ledger.ps1 -VerifyRemoteHeads
```

The verifier fails closed when a PR is omitted, duplicated, has a shortened/incorrect head or useful SHA, lacks collision/replacement/retention detail, or is missing from the close sequence. It contains no PR, branch, worktree, runtime, save, or artifact mutation.

## Next actionable recovery

After the exact-head PR #43 proof and current build gates pass, #8/#9 and #34 are the fastest safe closure batch because their maintained replacements already exist. The next functional salvage target is #20: recover its typed governor-to-worker activity model behind the current worker cadence and activity-handoff contracts, then validate it on current main. The sell stack #5/#6 remains last because it requires fresh behavior proof rather than documentation equivalence.
