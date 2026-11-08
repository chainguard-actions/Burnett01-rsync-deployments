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

RSH="ssh $STRICT_HOSTKEYS_CHECKING $LEGACY_RSA_HOSTKEYS -p $INPUT_REMOTE_PORT $INPUT_RSH"
LOCAL_PATH="$GITHUB_WORKSPACE/$INPUT_PATH"
DSN="$INPUT_REMOTE_USER@$INPUT_REMOTE_HOST"

# Deploy.
# INPUT_SWITCHES is a list of rsync flags that may contain quoted values
# (e.g. --exclude='.git/'). Tokenize it quote-aware with xargs (no evaluation
# of ;, |, $(...) or backticks) and hand every other value to rsync as a
# single, quoted argument. The inner script is a fixed string; all values
# arrive as positional parameters or environment variables.
export RSH LOCAL_PATH DSN
# Fail on an unmatched quote instead of silently dropping arguments.
printf '%s' "$INPUT_SWITCHES" | xargs true >/dev/null
printf '%s' "$INPUT_SWITCHES" | xargs sh -c 'exec rsync "$@" -e "$RSH" "$LOCAL_PATH" "$DSN:$INPUT_REMOTE_PATH" </dev/null' sh

# Clean up.
source agent-stop "$GITHUB_ACTION"
source hosts-clear

exit 0
