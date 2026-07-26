# Harness status — save compatibility

## Working

- The repository now has a tracked read-only save compatibility workflow distinct from the game-build compatibility workflow.
- Save role and save version are independent classifications.
- Catalog mode can inventory compatible and incompatible saves together without selecting an autosave by recency.
- Gate mode evaluates one explicit target and fails closed on newer, older-for-auto-reuse, unknown, ambiguous, missing, non-eligible, or mismatched approved-alias states.
- The approved dev aliases require byte identity, equal length, and equal parsed version.
- Generated results record SHA-256 and parsed version without copying save bytes into the repo.
- The one-click catalog and pre-push hook include the focused save compatibility validator.

## Broken or unproven

- The current workstation's real `.sav` files have not yet been replayed through this newly tracked classifier in this remote harness branch.
- The complete SHA-256 for the reported approved alias pair is not recorded here; only the operator-reported `C472…9BDC` boundary is retained as a regression reference.
- The in-game exact-save load report does not yet consume and prove the same prelaunch SHA/version at the load boundary.
- No new launch is authorized by this harness sprint.

## Missing next implementation

After read-only real-file replay passes, `launcher-lifecycle` must consume a fresh gate result before exact-save selection and correlate the in-game load report with the classified target's SHA/version. New-save creation remains a separately authorized runtime operation followed by read-only reclassification.

## Proof ceiling

`static fixtures + build/static regression + real-file read-only parsing`

This report does not claim a successful launcher action, save load, campaign readiness, map traversal, priority-engine cycle, or live runtime pass.
