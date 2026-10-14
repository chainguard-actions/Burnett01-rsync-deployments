<!-- markdownlint-disable -->

# Hardening Report: Burnett01--rsync-deployments/9.0.2

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **Burnett01--rsync-deployments/9.0.2** was hardened automatically. 1 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### script-injection (severity: high)

In entrypoint.sh, multiple user-controlled input variables are interpolated unquoted into a `sh -c "..."` command string (sub-rule b: unquoted shell variable expansion of untrusted data). On line 44, `RSH` is constructed by embedding `$INPUT_REMOTE_PORT` and `$INPUT_RSH` unquoted. On line 49, the deploy command `sh -c "rsync $INPUT_SWITCHES -e '$RSH' $LOCAL_PATH $DSN:$INPUT_REMOTE_PATH"` expands all of `$INPUT_SWITCHES`, `$RSH`, `$LOCAL_PATH`, `$DSN`, and `$INPUT_REMOTE_PATH` without double-quoting inside the sh -c string. An attacker can inject shell metacharacters (`;`, `|`, `&`, `$(...)`, backticks, etc.) via any of these action inputs (switches, rsh, remote_port, path, remote_path, remote_host, remote_user) to execute arbitrary commands on the runner.

Locations:

- `entrypoint.sh:44`
- `entrypoint.sh:49`

## Iteration Notes

### Iteration 1

**Fixes applied:** script-injection

**Notes:**

Fixed script injection in entrypoint.sh by eliminating the `sh -c "rsync $INPUT_SWITCHES -e '$RSH' $LOCAL_PATH $DSN:$INPUT_REMOTE_PATH"` pattern. Replaced it with: (1) `set -- $INPUT_SWITCHES` to word-split the switches list into positional parameters (POSIX sh / busybox compatible), then (2) a direct `rsync "$@" -e "$RSH" "$LOCAL_PATH" "$DSN:$INPUT_REMOTE_PATH"` call with all non-list arguments double-quoted. This prevents shell metacharacter injection from remote_path, remote_host, remote_user, path, and rsh inputs. The RSH variable construction on line 44 was left as-is since RSH is now passed as a single double-quoted argument to rsync's -e flag, so its contents are not interpreted by the outer shell.

