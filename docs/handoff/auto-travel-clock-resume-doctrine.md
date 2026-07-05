# Auto Travel Clock Resume Doctrine

## PR 25 runtime lesson

A successful travel command is not the same thing as successful travel.

During PR 25 runtime proof, AutoTravelToRecommended returned Success and the in-game log showed travel intent toward Quyaz, but the party did not move while the campaign clock remained stopped.

Observed facts:

- AutoTravelToRecommended returned Success.
- The in-game log printed travel intent toward Quyaz.
- Status remained MapPaused with timePaused true.
- No fresh movement or travel proof artifact was written.
- The party moved only after the operator focused the game and manually resumed time.
- After time resumed, the party reached Quyaz and the surface became settlement_menu.

Therefore, route assignment is only a checkpoint. It is not terminal movement proof.

## Required distinction

Travel automation must distinguish command acknowledgement, route assignment, clock state, movement, and arrival.

- Command ack success means the inbox command was processed.
- Route intent means Bannerlord accepted a destination.
- Clock running means the campaign can advance.
- Movement delta means runtime movement occurred.
- Settlement menu at the target means terminal arrival proof.

A travel command may only claim successful execution after movement delta or target arrival is proven.

## Route-owned clock resume

When an automation-owned travel command successfully assigns a route, it may resume the campaign clock as part of that same route operation.

The safe seam is:

1. Assistive travel command accepted.
2. Destination resolved.
3. SetMoveGoToSettlement or equivalent route assignment succeeds.
4. Travel-start evidence is emitted.
5. Campaign clock is resumed through CampaignClockResumeHelper.
6. Runtime proof watches for movement delta or target settlement arrival.

This is narrow by design. Automation should not globally unpause the game whenever it sees MapPaused.

## Full access policy

A future Full Access toggle may permit automation to resume the campaign clock after confirmed automation-owned route assignment.

Even with Full Access enabled:

- Allowed: resume after confirmed automation-owned route assignment.
- Allowed: resume after explicit ResumeCampaignClock or ToggleFastForward.
- Not allowed: resume just because the map is paused.
- Not allowed: resume from escape menu interruption.
- Not allowed: resume from settlement menu idle.

The toggle expands permission. It does not erase context.

## Merge bar

PRs touching travel automation must not treat command acknowledgement as travel success.

The merge bar is:

1. route assignment succeeds
2. campaign clock is running or deliberately resumed
3. movement or arrival is proven
4. stale movement artifacts are not used as current proof

This prevents fake travel passes where the command succeeded but the party never moved.
