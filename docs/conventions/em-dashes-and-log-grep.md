# Em-dashes and log grep safety

The ready branding line uses U+2014 em dash: `Blacksmith Guild — Ready`.

PowerShell 5.1 can misread non-ASCII strings when a script is saved without a UTF-8 BOM. That risk has already produced misleading F7/Continue diagnostics, so scripts should prefer `Get-TbgReadyGoldenPathPattern` from `scripts/bannerlord-paths.ps1` and should never grep for the ASCII-hyphen lookalike `Blacksmith Guild - Ready`.

## Rules

1. Do not add `Blacksmith Guild - Ready` or `Blacksmith Guild - Ready:` as a grep/log-ready pattern in scripts.
2. Do not rewrite prose titles, Windows shortcut names, or user-facing document headings merely because they contain a hyphen.
3. Prefer helper functions in `scripts/bannerlord-paths.ps1` for log paths and ready-line patterns.
4. Validate script patterns with `scripts/verify-log-grep-patterns.ps1` before handing off F7 work.

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-log-grep-patterns.ps1
```
