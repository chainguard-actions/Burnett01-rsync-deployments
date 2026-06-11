<!-- markdownlint-disable -->

# Hardening Report: Burnett01--rsync-deployments/8.0.3

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `1`

Action **Burnett01--rsync-deployments/8.0.3** was hardened automatically. 0 finding(s) were identified and resolved across 1 iteration(s).

## Iteration Notes

### Iteration 1

**Fixes applied:** script-injection

**Notes:**

Fixed script injection in entrypoint.sh by: (1) removing the `sh -c "..."` double-quoted string wrapper (the root cause — it caused all interpolated variables to be re-parsed as shell syntax by the child shell); (2) adding a `sq()` POSIX shell-quoting helper that wraps values in single quotes and escapes embedded single quotes; (3) properly quoting `$INPUT_REMOTE_PORT` and `$INPUT_RSH` via `sq()` when building the RSH variable (was line 40); (4) replacing the `sh -c` invocation with `eval rsync $INPUT_SWITCHES -e "$(sq "$RSH")" "$(sq "$LOCAL_PATH")" "$(sq "$DSN"):$(sq "$INPUT_REMOTE_PATH")"` — `$INPUT_SWITCHES` remains intentionally word-split (it carries multiple rsync flags like `-avz --delete`) while every other user-controlled single-value input is individually single-quoted to prevent metacharacter injection.

