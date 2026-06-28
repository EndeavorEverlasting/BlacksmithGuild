# Reboot Iteration Doctrine

The Reboot harness exists so routine iteration does not consume AI tokens just to rediscover the same blocker.

## Principle

- AI tokens are for designing patches, not babysitting retries.
- Double-click Reboot should collect enough local evidence to identify the next gap.
- The same normalized context twice means `stable_gap`.
- A stable gap is a patch target, not a reason to wait forever.

## Local entrypoint

- `ForgeReboot.cmd` runs `scripts\run-reboot-iteration.ps1`.
- The script wraps the existing autonomous assist runner.
- Generated reboot evidence is local under `docs\evidence\reboot*-reboot-session\` and must not be committed.

## Wait policy

- Normal action cap: 30 seconds.
- Exceptions may use longer timeouts only when classified as:
  - long-distance travel
  - smithing with a large party
  - massive trade operations
- A normal operation exceeding the cap is classified by the runner/harness rather than silently waited out.

## Stable-gap rule

The classifier removes noisy fields such as timestamps, raw session IDs, volatile process IDs, window handles, and absolute evidence folder names. It compares semantic state:

- failure class and stop reason
- proof mode and visible mechanics proof
- gameplay surface and planned branch
- target and target source
- command and acknowledgement state
- movement intent and `partyMovedDistance` bucket
- operator interruption and foreground-loss state
- safe-idle class and checkpoint progress

If two consecutive normalized contexts match at the repeat threshold, the harness stops and writes:

- `stable-gap-context.json`
- `stable-gap-handoff.md`
- `reboot-summary.md`

## Proof doctrine

- Live game proof still requires real visible mechanics.
- `partyMovedDistance > 0` remains the movement proof line.
- Attach readiness or route intent alone is not visible mechanics proof.

## Evidence doctrine

- Do not commit live reboot evidence.
- Do not commit `docs\evidence\live-cert\*-autonomous-assist-session\` scratch output.
- Sanitized fixtures may be committed only when intentionally created for tests.
- Reboot evidence is local/generated unless explicitly sanitized as a fixture.