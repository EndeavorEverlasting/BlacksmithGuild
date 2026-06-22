# 006C-3 — Weapon Smelt Execution

**Status:** Code shipped on `feat/live-cert-marathon` — USER cert via `Run-WeaponSmeltCert.cmd` / live marathon.

## Goal

One bounded non-combat loot weapon smelt with inventory delta proof (weapon −1, iron/charcoal +).

## Deliverables

| Item | Path |
|------|------|
| API probe | `src/BlacksmithGuild/Forge/SmithingSmeltApi.cs` |
| Loot scanner | `src/BlacksmithGuild/Forge/SmithingLootWeaponScanner.cs` |
| Execution | `src/BlacksmithGuild/Forge/SmithingSmeltService.cs` |
| Commands | `ProbeWeaponSmeltNow`, `RunWeaponSmeltNow` |
| JSON | `BlacksmithGuild_SmithingSmeltProbe.json`, `BlacksmithGuild_SmithingSmeltExecution.json` |
| Cert | `scripts/run-weapon-smelt-cert.ps1` |

## PASS rubric

- `doSmeltingMapped: true` in smelt probe JSON
- Mutation: `weaponsAfter < weaponsBefore` AND iron or charcoal increased
- Guild loop: `TryWeaponSmelt: Success` when preconditions met

## Out of scope

- Multi-weapon batch (006C-4)
- Smithy interior walk if headless fails (006C-3b)
