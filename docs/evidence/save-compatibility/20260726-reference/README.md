# Save compatibility correction reference

This is a sanitized reference to the operator-reported read-only observations that motivated the save compatibility harness.

- Installed game version: `1.4.6.115628`.
- `saveauto1.sav`: reported save version `1.4.7.117484`; expected to fail closed as newer than the installed game.
- Approved aliases `BlacksmithGuildDevStart.sav` and `BlacksmithGuild_DevStart.sav`: reported byte-identical at save version `1.4.6.115628`; SHA-256 is intentionally stored only as `C472…9BDC` here until the tracked classifier performs a fresh local replay.

No save file, absolute personal path, live process detail, or secret is stored in this evidence directory.

This reference is not the generated compatibility artifact and does not promote proof. The generated local `save-compatibility.result.json` is the next authority after the real-file read-only replay.
