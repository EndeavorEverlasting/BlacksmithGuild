# Sprint 007 Auto Travel

## Player commands

- `ShowAutoTravelChoices` displays five numbered destination choices ranked for accessible trading travel.
- `AutoTravelChoice1` through `AutoTravelChoice5` starts auto-travel to one of the displayed choices, avoiding name spelling requirements for dyslexic users.
- `AutoTravelToRecommended` starts auto-travel to the current first recommendation.
- `AutoTravel:<town-or-village-name>` starts auto-travel by typed settlement name when the player prefers direct entry.

## Safety behavior

The first implementation uses Bannerlord's map movement order for the main party and adds a cautious route monitor. If a hostile party at war with the player is close and at least as large as the main party, the service blocks or pauses travel instead of steering into the threat. This creates a small, testable foundation for later army-command intelligence.

## Movement API (v1.4.6)

Primary path: `MobileParty.SetMoveGoToSettlement(destination, MobileParty.NavigationType.Default, false)`. Reflection fallbacks remain for `party.Ai` and legacy single-parameter signatures.

## Tier 2 smoke rubric

**Save:** disposable or Continue save on campaign map (`campaignReady: true`).

```powershell
.\forge.ps1 -Command ShowAutoTravelChoices -Wait
.\forge.ps1 -Command AutoTravelChoice1 -Wait
```

**PASS when Phase1 contains:**

```text
[TBG TRAVEL] auto-travel started to <town>
```

Optional: observe party movement on map; verify hostile pause near war parties.
