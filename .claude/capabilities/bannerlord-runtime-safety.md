# Capability: Bannerlord Runtime Safety

## Purpose

Keep build, install, launch, command, behavior, and save mutation boundaries explicit.

## Rules

- Release build may invoke the repository install seam; use Debug for build-only validation.
- Stop Bannerlord before replacing installed DLLs unless the selected workflow is read-only.
- Prefer command inbox and ACK surfaces over terminal or window focus.
- Read-only observation does not authorize command-inbox writes.
- Command issue does not prove ACK; ACK does not prove behavior; behavior does not prove persistence.
- Tier-3 mutation requires a disposable save and explicit operator authorization.
- Never use legacy, personal, or unclassified saves for mutation proof.
- Bound waits and retain failure evidence without deleting saves or unknown worktrees.
- Do not automate engine ASSERT dialogs or claim control of external game UI.
