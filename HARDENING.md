<!-- markdownlint-disable -->

# Hardening Report: Burnett01--rsync-deployments/9.0.4

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **Burnett01--rsync-deployments/9.0.4** was hardened automatically. 1 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### script-injection (severity: high)

Sub-rule (b): the entrypoint script sends unquoted, workflow-controlled inputs through a shell with sh -c. Offending line: `sh -c "rsync $INPUT_SWITCHES -e '$RSH' $LOCAL_PATH $DSN:$INPUT_REMOTE_PATH"`. The inputs switches, rsh, port, path, remote_user, remote_host and remote_path are pasted straight into the command string, so characters like ;, |, $(...), backticks or a quote inside any of them will run as shell commands in the container. Build an argument list and call rsync directly instead of using sh -c (for example, use `set --` and quoted variables).

Locations:

- `entrypoint.sh:49`

## Iteration Notes

### Iteration 1

**Fixes applied:** script-injection

**Notes:**

entrypoint.sh: replaced `sh -c "rsync $INPUT_SWITCHES -e '$RSH' $LOCAL_PATH $DSN:$INPUT_REMOTE_PATH"`. The new code checks the switches first: `printf | xargs true` fails on an unmatched quote. It then splits the switches with xargs, which honours quotes the way upstream's sh -c did (the README shows switches like --exclude='.git/'), and runs a fixed `sh -c 'exec rsync "$@" -e "$RSH" "$LOCAL_PATH" "$DSN:$INPUT_REMOTE_PATH"' sh`. RSH, LOCAL_PATH and DSN are exported and each one is passed as a single quoted argument. The script stays POSIX sh, since the Alpine image has no bash. -r is left off xargs on purpose, so rsync still runs once if switches is empty. One change in behaviour: path and remote_path are no longer split on spaces or glob-expanded by a local shell.

