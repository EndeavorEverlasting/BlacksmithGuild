# Skill: Bannerlord Runtime Proof

## Trigger

Bannerlord launch, session attach, command inbox, ACK, status, behavior, route certification, persistence, or live certification.

## Capability dependencies

- `repository-evidence`
- `proof-and-checkpointing`
- `bannerlord-runtime-safety`
- `end-to-end-testing`

## Required gates

- repo floor is safe;
- selected journey names the save class;
- Bannerlord stop/safe-start doctrine is known;
- every wait is bounded;
- command and expected ACK are exact;
- output root is ignored;
- mutation authority is explicit.

## Proof chain

1. safe stop/start if required;
2. launcher/session attach;
3. target surface ready;
4. command issued;
5. exact command ACK;
6. behavior artifact observed;
7. persistence or mutation result observed when required;
8. final save/repository hygiene;
9. machine-readable result and handoff.

## Stop conditions

Stop without retry when credentials, unknown save state, wrong campaign, stale/missing ACK, unexpected mutation, engine ASSERT, route-cert conflict, or unknown partial work appears.
