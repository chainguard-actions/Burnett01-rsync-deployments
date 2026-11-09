#!/usr/bin/env bash
# Starts a throwaway OpenSSH server (port 2222) inside the job container so the
# rsync-deployments Docker action has a real target to deploy to.
# Usage: bash tests/fixtures/start-sshd.sh [client-key-passphrase]
# Exports to $GITHUB_ENV: DEPLOY_HOST, DEPLOY_PORT, DEPLOY_USER, DEPLOY_KEY, DEPLOY_KEY_PASS
set -euo pipefail

PASS="${1:-}"
SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

if [ ! -x /usr/sbin/sshd ] || ! command -v rsync >/dev/null 2>&1 || ! command -v ssh-keyscan >/dev/null 2>&1; then
  $SUDO apt-get update -qq
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -qq openssh-server openssh-client rsync >/dev/null
fi

$SUDO mkdir -p /run/sshd
$SUDO chmod 0755 /run/sshd

if ! id deployer >/dev/null 2>&1; then
  $SUDO useradd -m -s /bin/sh deployer
fi
# '*' = no password but NOT locked (a '!' locked account is refused with UsePAM=no)
$SUDO usermod -p '*' deployer

SSHDIR=/tmp/act-sshd
$SUDO rm -rf "$SSHDIR"
mkdir -p "$SSHDIR"
ssh-keygen -q -t ed25519 -N '' -f "$SSHDIR/host_ed25519" -C host
ssh-keygen -q -t ed25519 -N "$PASS" -f "$SSHDIR/client_key" -C deploy

$SUDO install -d -m 700 -o deployer -g deployer /home/deployer/.ssh
$SUDO install -m 600 -o deployer -g deployer "$SSHDIR/client_key.pub" /home/deployer/.ssh/authorized_keys

cat > "$SSHDIR/sshd_config" <<EOF
Port 2222
ListenAddress 0.0.0.0
HostKey $SSHDIR/host_ed25519
PidFile $SSHDIR/sshd.pid
UsePAM no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
StrictModes no
AllowUsers deployer
LogLevel VERBOSE
EOF

$SUDO /usr/sbin/sshd -f "$SSHDIR/sshd_config" -E "$SSHDIR/sshd.log"

HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
if [ -z "$HOST_IP" ]; then
  HOST_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}' || true)"
fi
if [ -z "$HOST_IP" ]; then HOST_IP="127.0.0.1"; fi

ok=""
for _ in $(seq 1 20); do
  if ssh-keyscan -p 2222 "$HOST_IP" 2>/dev/null | grep -q ssh-ed25519; then ok=1; break; fi
  sleep 1
done
if [ -z "$ok" ]; then
  echo "FAIL: sshd did not come up on $HOST_IP:2222"
  $SUDO cat "$SSHDIR/sshd.log" || true
  exit 1
fi
echo "sshd listening on $HOST_IP:2222"

{
  echo "DEPLOY_HOST=$HOST_IP"
  echo "DEPLOY_PORT=2222"
  echo "DEPLOY_USER=deployer"
  echo "DEPLOY_KEY_PASS=$PASS"
  echo "DEPLOY_KEY<<__DEPLOY_KEY_EOF__"
  cat "$SSHDIR/client_key"
  echo "__DEPLOY_KEY_EOF__"
} >> "$GITHUB_ENV"
