# PowerShell UTF-8 BOM doctrine (read before editing any `.ps1`)

**This is not optional.** PowerShell 5.1 (Windows PowerShell) and PowerShell 7 (`pwsh`) disagree on how to read script files that lack a byte-order mark. Agents routinely edit scripts on pwsh 7, run offline tests there, and ship files that **parse or behave differently** under PS 5.1 — the runtime used by `Forge.cmd`, most F7 gate runners, and CI-style contract invocations.

The em dash (`—`, U+2014) is the most visible symptom. The underlying rule is **file encoding + BOM**, not “avoid fancy punctuation.”

---

## The failure mode (why you were caught)

| Step | What happens |
|------|----------------|
| 1 | Agent edits or creates `something.ps1` in Cursor / pwsh 7. File is saved as **UTF-8 without BOM**. |
| 2 | Script contains non-ASCII: em dash in a comment, arrow `→`, smart quotes, or a copied `Blacksmith Guild — Ready:` literal. |
| 3 | **pwsh 7** loads the file as UTF-8 → parses fine → offline test **PASS**. |
| 4 | **PS 5.1** (no BOM) assumes **Windows-1252 / system ANSI** → bytes misread → **parse error**, **wrong string literals**, or **silent grep mismatch**. |
| 5 | `Forge.cmd` / `verify-f7-runner-contract.ps1` (invoked via `powershell.exe`) fails while the agent believed the tree was green. |

**Non-regression:** A script that only passes under pwsh 7 is **not** certified for this repo until `test-powershell-utf8-bom-contract.ps1` passes under PS 5.1 invocation.

---

## PS 5.1 vs PS 7 — encoding defaults

| Topic | Windows PowerShell 5.1 | PowerShell 7+ (`pwsh`) |
|-------|------------------------|-------------------------|
| **Read `.ps1` without BOM** | System default code page (often Windows-1252) | UTF-8 |
| **`Set-Content -Encoding UTF8`** | Writes **UTF-8 with BOM** | Writes **UTF-8 without BOM** (use `utf8BOM` for BOM) |
| **`Get-Content` default** | System default | UTF-8 |
| **Typical repo entrypoint** | `powershell.exe -File …` | `pwsh -File …` (dev only unless documented) |

**Trap:** An agent on pwsh 7 who `Set-Content -Encoding UTF8` a new `.ps1` creates a **no-BOM** file. That file may work locally and fail in production PS 5.1 paths.

---

## Repo rule (hard)

1. **Every tracked** `*.ps1`, `*.psm1`, `*.psd1` under the repository root **must** start with the UTF-8 BOM bytes `EF BB BF`.
2. **ASCII-only scripts without BOM** may parse on PS 5.1 today but are still **non-compliant** — the next agent paste of an em dash will break them without a contract failure if we only checked non-ASCII files.
3. After creating or bulk-editing PowerShell files, run:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tools\Add-Utf8Bom.ps1 -Fix
   ```
4. Before claiming green, run (must pass under **PS 5.1**):
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-powershell-utf8-bom-contract.ps1
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-f7-runner-contract.ps1
   ```

---

## Em dash is a special case of BOM failure

Player-facing log text uses em dashes. See [`em-dashes-and-log-grep.md`](em-dashes-and-log-grep.md) for grep helpers.

| Approach | PS 5.1 safe? | Notes |
|----------|--------------|-------|
| Paste `—` in a no-BOM `.ps1` | **No** | Mojibake or parse failure |
| `[char]0x2014` in PowerShell | **Yes** (if file has BOM or line is ASCII-only) | Preferred for pattern builders |
| Copy literal from `ModDisplay.cs` into BOM-backed `.ps1` | **Yes** | OK after `Add-Utf8Bom.ps1 -Fix` |
| ASCII hyphen `-` instead of em dash in log matchers | **Avoid** | Wrong semantics; grep guard catches some cases |

**Both doctrines apply:** correct character **and** correct file encoding.

---

## Fix tool

[`scripts/tools/Add-Utf8Bom.ps1`](../../scripts/tools/Add-Utf8Bom.ps1)

```powershell
# Report only
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tools\Add-Utf8Bom.ps1

# Apply BOM to all scripts missing it (idempotent)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tools\Add-Utf8Bom.ps1 -Fix
```

Dry-run lists `[NEEDS BOM]`. `-Fix` prepends `EF BB BF` without re-encoding content (safe for already-valid UTF-8 bodies).

---

## Regression guard

[`scripts/test-powershell-utf8-bom-contract.ps1`](../../scripts/test-powershell-utf8-bom-contract.ps1) — fails closed if any tracked script lacks BOM.

Wired into [`scripts/verify-f7-runner-contract.ps1`](../../scripts/verify-f7-runner-contract.ps1) so Agent A cert lane cannot miss it.

---

## Agent checklist (copy into handoffs)

When you touch `scripts/**` or root `*.ps1`:

- [ ] Ran `Add-Utf8Bom.ps1 -Fix` after edits
- [ ] Ran `test-powershell-utf8-bom-contract.ps1` via **`powershell.exe`** (5.1)
- [ ] Did not “fix” em dashes to ASCII hyphens to silence errors
- [ ] If adding log grep patterns, used `bannerlord-paths.ps1` helpers or `[char]0x2014`
- [ ] Did not assume pwsh-only green is repo green

---

## Symptoms → diagnosis

| Symptom | Likely cause |
|---------|----------------|
| `ParserError: Unexpected token` in PS 5.1 only | No BOM + non-ASCII in file |
| String match fails; log line “looks right” in editor | Mojibake em dash vs real U+2014 |
| `verify-f7-runner-contract` PASS in pwsh, FAIL in CI/Forge | BOM / 5.1 vs 7 invocation split |
| `Add-Utf8Bom` reports `[NEEDS BOM]` on your new file | You forgot the fix step |

---

## Related docs

- [`em-dashes-and-log-grep.md`](em-dashes-and-log-grep.md) — U+2014 in log patterns
- [`forge-zero-click-contract.md`](../forge-zero-click-contract.md) — Layer A Forge.cmd encoding note
- [`agent-launch-and-load-playbook.md`](../handoff/agent-launch-and-load-playbook.md) — invoke `powershell.exe` vs `pwsh`
- [`AGENTS.md`](../../AGENTS.md) — root coordination contract

---

## History

- **2026-06-26:** Doctrine written after live sprint caught new runner scripts shipping UTF-8 **no-BOM** with em-dash / Unicode content — green under pwsh 7, broken under PS 5.1. Contract test added so agents cannot repeat without an explicit FAIL.
