# Skill: End-to-End Validation

## Trigger

Composed journey, merge/release gate, launcher integration, command-bus integration, or harness verification.

## Capability dependencies

- `repository-evidence`
- `proof-and-checkpointing`
- `end-to-end-testing`
- `bannerlord-runtime-safety`

## Procedure

1. Read `harness/e2e/e2e-profiles.json`.
2. Select the lowest-risk profile that can prove the changed integration.
3. Run `scripts/Invoke-TbgHarnessE2E.ps1`.
4. Require every profile-owned required journey to complete.
5. Inspect result, artifact registry, English report, and sprint capsule.
6. Do not promote static CI to live game proof.

## Default command

```powershell
pwsh -NoProfile -File .\scripts\Invoke-TbgHarnessE2E.ps1 -Profile default-static
```

## Forbidden scope

- implicit live-game launch;
- command-inbox write without explicit live profile;
- personal-save mutation;
- tracked raw runtime evidence.
