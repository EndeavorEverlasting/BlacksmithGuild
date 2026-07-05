# Focused Route Proof Lifecycle

## Purpose

Route proof is not valid unless the harness owns the gameplay conditions required for route execution.

The route brain selecting a destination is useful progress. It is not movement proof.

## Problem model

Bannerlord is not a normal background process for this proof.

When the operator switches from the game to a terminal, the game can lose foreground focus. When that happens, pause overlay behavior or campaign time pause can prevent route travel from executing.

Invalid proof shape:

```text
Launch game
Switch to terminal
Write command JSON
Wait in terminal
Collect logs
Expect party movement
```

Correct proof shape:

```text
Launch game
Wait for campaign map
Acquire a route proof focus lease
Dismiss or avoid pause overlay
Ensure campaign time is unpaused
Trigger route action
Maintain the focus lease for the route window
Collect route cert and movement evidence after execution
```

## Required status interpretation

This state is not movement proof:

```text
campaignReady=true
mapStateActive=true
safeToExecuteTravel=true
targetSettlement=Quyaz
nextPlannedBranch=travel
timePaused=true
```

Allowed claim:

```text
route brain selected Quyaz and travel was safe to attempt
```

Forbidden claim:

```text
autonomous route movement occurred
```

## Implementation seam

The first repo-side implementation is:

```text
scripts/start-bannerlord-focus-keeper.ps1
```

It provides three modes:

```text
Observe
SyntheticFocusPulse
ForegroundLease
```

### Observe

Records Bannerlord foreground/focus state without trying to change it.

### SyntheticFocusPulse

Posts a conservative activation/focus message pulse to the Bannerlord window handle while the operator keeps using another window.

Boundary:

```text
This is experimental. It can make the harness attempt focus ownership without stealing foreground, but it does not prove the engine accepted focus until route evidence confirms movement.
```

### ForegroundLease

Actively restores and foregrounds the Bannerlord window during the route proof window.

Boundary:

```text
This is more honest for runtime proof, but it can interrupt the operator because Windows only has one real foreground window.
```

## Required proof artifact

The focus keeper writes:

```text
BlacksmithGuild_FocusLease.json
```

The artifact must include:

```text
mode
durationSeconds
pulseMilliseconds
processId
windowHandle
windowTitle
foregroundSamples
lostForegroundSamples
focusPulseSamples
unpausePulseSamples
proofBoundary
classification
```

## Classification rules

```text
Observe + lost foreground = observed_only
SyntheticFocusPulse + no movement evidence = focus_attempted_not_proven
SyntheticFocusPulse + movement evidence = focus_attempt_supported_by_route_evidence
ForegroundLease + no lost foreground samples + movement evidence = focus_lease_supported
ForegroundLease + lost foreground samples = focus_lease_contested
```

## Required next implementation

The route proof harness should wrap route execution as one owned sequence:

```text
build/install
launch Continue fast
wait for campaign map
start focus keeper
ensure unpaused
trigger route
hold focus keeper for route window
collect route cert/log proof
stop focus keeper
summarize proof
```

## Non-goals

This lifecycle does not claim:

```text
route completion
movement proof
runtime command success
zero-click proof
```

unless fresh route evidence confirms those claims after the focus-owned route window.
