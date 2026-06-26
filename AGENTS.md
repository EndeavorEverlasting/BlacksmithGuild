# Blacksmith Guild Agent Coordination Contract

This file is the root coordination contract for Codex, Cursor, ChatGPT handoffs, and parallel sub-agents working in The Blacksmith Guild repository.

## Agent identities and ownership

- Agent A = Cert / Evidence / Git / PR judgment
- Agent B = Runtime / Readiness / Gameplay state truth
- Agent C = External runner / launcher / lifecycle / window classifier
- Agent D = Docs / atlas / routing board

## Hard routing rules

- Agent A does not write product code.
- Agent B does not edit launcher/runner scripts unless explicitly routed.
- Agent C does not edit src/** unless explicitly authorized.
- Agent D does not certify gameplay.
- Do not merge PR #8 unless user explicitly authorizes.
- Do not commit scratch evidence folders.
- Do not claim PASS from stale Status.json.
- Do not ask the user to harvest logs manually.
- Runner owns evidence capture.

## Current strategic target

One command should:

1. build/deploy if needed
2. launch Bannerlord
3. select Continue automatically
4. wait for campaign attach
5. consume stateMachine + RuntimeLifecycle
6. start autonomous assist loop without hotkey
7. make the avatar visibly move/train/act
8. log every step
9. allow user toggle-off
10. stop cleanly
11. write summary evidence

## Coordination doctrine

- Read `docs/handoff/blacksmithguild-agent-coordination.md` before changing owned files.
- Runtime truth and runner consumption must follow `docs/handoff/runtime-state-routing.md`.
- Window selection must follow `docs/control/logs/open/window-delta-doctrine.md`.
- The current user-facing product target is `docs/control/logs/open/autonomous-assist-session-target.md`.
- Synthesize parallel reports by preserving each agent's factual findings, resolving ownership conflicts through the routing matrix, and escalating only true contradictions to the user.
