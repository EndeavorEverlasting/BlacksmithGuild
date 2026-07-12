# Hostile escape and escort-vector contract

The hostile-vector layer answers one bounded question: given a protected party and a snapshot of nearby hostile parties, which normalized direction most strongly increases separation from the complete threat field? It is a recommendation engine, not a movement engine.

## Runtime shape

The runtime adapter enumerates campaign parties once per cadence-controlled safety decision. It classifies hostile parties inside the configured influence radius and converts them to game-agnostic snapshots. `HostileEscapeVectorAnalyzer` then performs two linear passes over that supplied list: one to accumulate a strength- and proximity-weighted repulsion vector and one to project the resulting minimum clearance. It never reads `MobileParty.All`, never writes evidence, and never issues a movement command.

This separation matters for both performance and correctness:

- one hostile, many hostiles, and hostiles arriving from orthogonal directions use the same math;
- opposite vectors expose a cancellation ratio and low-confidence “surrounded” result instead of presenting an unstable direction as certain;
- the analyzer reports whether the proposed step improves the protected party’s minimum clearance;
- a spawning or despawning party cannot mutate the collection while the pure analyzer is running;
- the explicit evidence file overwrites the previous latest snapshot and is never appended or written per campaign tick.

The current MapTrade adapter does not estimate velocity, so it passes a zero-second prediction horizon. The pure model already accepts hostile velocity and a bounded prediction horizon; a future shared snapshot provider can populate them without changing the geometry contract.

## Safety boundary

The result cannot directly move the player, a caravan, or a companion party. A controller must still validate terrain, settlements, map boundaries, current authority mode, and whether vanilla movement APIs are available. A failed campaign snapshot is a hold/block condition. A surrounded result or a recommendation that does not improve minimum clearance is evidence for a higher-level reroute, shelter, escort, or hold decision—not authority to force movement. Teleport and raw-position mutation remain forbidden.

## Future caravan and companion protection

“Protected party” is an input rather than a hard-coded player singleton. That keeps the same analysis reusable when the mod can legitimately command a clan companion party to protect a player caravan:

1. A shared cadence worker captures one nearby-party snapshot.
2. The caravan is evaluated as the protected party.
3. The escort controller evaluates the same threat field for the companion party and a route corridor.
4. The controller selects a vanilla-visible escort, intercept, shadow, shelter, or hold action under companion-command authority.
5. Runtime evidence records the recommendation and the separately authorized action.

Multiple protected parties may share the same immutable hostile snapshot. Each protected party still receives its own clearance computation; this prevents a caravan-safety loop and a player-safety loop from independently enumerating the world on the same decision interval.

## Machine gates

The normative policy is `.tbg/operator/hostile-escape-vector.json`. Executable geometry cases live in `.tbg/harness/fixtures/hostile-escape-vector.fixtures.json`. `scripts/verify-hostile-escape-vector-contract.ps1` compiles the game-agnostic analyzer by itself, executes the fixture matrix, verifies single-enumeration runtime wiring, and rejects evidence append/per-frame mutation patterns.
