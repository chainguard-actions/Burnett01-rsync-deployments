#!/bin/sh

set -eu

if [ "${INPUT_DEBUG:-false}" = "true" ]; then
    set -x
fi

if [ -z "$(echo "$INPUT_REMOTE_PATH" | awk '{$1=$1};1')" ]; then
    echo "The remote_path can not be empty. see: github.com/Burnett01/rsync-deployments/issues/44"
    exit 1
fi

# Initialize SSH and known hosts.
source ssh-init
source hosts-init

# Start the SSH agent and load key.
source agent-start "$GITHUB_ACTION"
echo "$INPUT_REMOTE_KEY" | SSH_PASS="$INPUT_REMOTE_KEY_PASS" agent-add

# Variables.
LEGACY_RSA_HOSTKEYS=""
if [ "${INPUT_LEGACY_ALLOW_RSA_HOSTKEYS:-false}" = "true" ]; then
    LEGACY_RSA_HOSTKEYS="-o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa"
fi

STRICT_HOSTKEYS_CHECKING="-o StrictHostKeyChecking=no"
if [ "${INPUT_STRICT_HOSTKEYS_CHECKING:-false}" = "true" ]; then
    STRICT_HOSTKEYS_CHECKING="-o UserKnownHostsFile=$HOME/.ssh/known_hosts -o StrictHostKeyChecking=yes"

    key="$(ssh-keyscan -p "$INPUT_REMOTE_PORT" "$INPUT_REMOTE_HOST" 2>/dev/null | sed '/^#/d')" || key=""
    if [ -n "$key" ]; then
        # fingerprint verification
        echo "$key" | ssh-keygen -lf -
        # add to known hosts
        echo "$key" | while IFS= read -r line; do hosts-add "$line"; done
    else
        echo "Warning: failed to fetch host key for $INPUT_REMOTE_HOST" >&2
        exit 1
    fi
fi

LOCAL_PATH="$GITHUB_WORKSPACE/$INPUT_PATH"
DSN="$INPUT_REMOTE_USER@$INPUT_REMOTE_HOST"

# Shell-quote a value so it can be safely embedded in an eval'd command.
# Wraps the value in single quotes and escapes any literal single quotes inside.
sq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

# Build the remote shell command.
# $STRICT_HOSTKEYS_CHECKING and $LEGACY_RSA_HOSTKEYS are constructed entirely
# from hard-coded strings (no user input), so they are safe to expand unquoted.
# $INPUT_REMOTE_PORT and $INPUT_RSH are user-controlled and are therefore
# individually single-quoted via sq() to prevent shell metacharacter injection.
RSH="ssh $STRICT_HOSTKEYS_CHECKING $LEGACY_RSA_HOSTKEYS -p $(sq "$INPUT_REMOTE_PORT") $(sq "$INPUT_RSH")"

# Deploy.
# $INPUT_SWITCHES is intentionally word-split so that a value such as
# "-avz --delete" expands into multiple distinct rsync flags.
# Every other user-controlled value ($RSH, $LOCAL_PATH, $DSN, $INPUT_REMOTE_PATH)
# is individually single-quoted via sq() so that shell metacharacters in those
# values cannot be interpreted as shell syntax.
# The `sh -c "..."` wrapper from the original code is intentionally removed:
# that pattern caused all interpolated variables to be re-parsed as shell syntax
# by the child shell, which is the root cause of the injection vulnerability.
# shellcheck disable=SC2086
eval rsync $INPUT_SWITCHES \
    -e "$(sq "$RSH")" \
    "$(sq "$LOCAL_PATH")" \
    "$(sq "$DSN"):$(sq "$INPUT_REMOTE_PATH")"

# Clean up.
source agent-stop "$GITHUB_ACTION"
source hosts-clear

exit 0
