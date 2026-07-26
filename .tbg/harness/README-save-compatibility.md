# Save compatibility harness index

Canonical surfaces:

- workflow: `.tbg/workflows/save-compatibility-classification.contract.json`
- policy/state registry: `.tbg/state/save-compatibility.registry.json`
- artifact registry: `.tbg/harness/save-compatibility-artifacts.registry.json`
- result schema: `.tbg/harness/schemas/save-compatibility-result.schema.json`
- fixtures: `.tbg/harness/fixtures/save-compatibility.fixtures.json`
- classifier: `scripts/tbg/Invoke-TbgSaveCompatibility.ps1`
- validator: `scripts/tbg/Test-TbgSaveCompatibility.ps1`
- operator entry: `ForgeSaveCompatibility.cmd`
- report: `docs/operator/save-compatibility.md`

This index is descriptive only; the executable workflow and validator remain authoritative.
