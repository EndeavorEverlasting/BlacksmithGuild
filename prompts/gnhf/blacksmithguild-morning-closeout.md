Repo: EndeavorEverlasting/BlacksmithGuild

Sprint: Reconcile the existing BlacksmithGuild night shift
Lane: closeout of existing overnight work only

Inputs:
- .tbg/plans/gnhf-night-shift/queue.json
- docs/handoff/gnhf-night-shift-report.md
- docs/handoff/gnhf-night-shift-closeout.md
- current GNHF worktree, logs, notes, commits, and validation evidence

Owned scope:
- queue disposition corrections supported by current evidence
- night report and closeout report
- narrowly required final validation repairs only when the existing work is otherwise complete

Forbidden scope:
- starting another feature or broad repair
- Bannerlord launch, save mutation, live proof, personal or production state
- push, merge, PR closure, release, deployment, authentication, credentials, branch deletion, worktree removal, reset, clean, or force push

Objective:
Turn the existing night work into a reviewable state. Do not begin another queue item.

Tasks:
1. Inspect git log, diff, status, queue, night report, launcher summary, GNHF logs, and checkpoint evidence.
2. Map every queue item to completed, blocked, superseded, rejected, or not attempted.
3. Run targeted validation for changed surfaces.
4. Run the default-static E2E profile when required and record PASS, SKIP, or FAIL honestly.
5. Confirm generated artifacts, credentials, personal paths, saves, and runtime logs are not staged.
6. Create or update docs/handoff/gnhf-night-shift-closeout.md.
7. Commit the closeout report and required queue/report corrections.
8. End with a clean generated GNHF worktree or record the exact blocker preserving the current state.

Rules:
- Process exit zero and configured stop text are not delivery proof.
- Skipped or unavailable checks are not passes.
- A checkpoint proves preservation only.
- Preserve exact branch and worktree paths for human review.

Validation:
- pwsh -NoLogo -NoProfile -File ./scripts/tbg/Test-TbgGnhfNightShift.ps1
- targeted checks named by completed queue items
- pwsh -NoLogo -NoProfile -File ./scripts/tbg/Invoke-TbgEndToEndValidation.ps1 -Profile default-static when required
- git diff --check
- git status --short

Closeout report:
- starting and final HEAD
- ordered night commits
- files and queue dispositions
- validation commands and exact results
- artifacts and logs
- blockers and proof ceiling
- recommended human push or PR action
- one exact next command
- final git status --short

Proof ceiling: reviewable repository and deterministic validation evidence only unless a separate authorized workflow produced stronger proof.
