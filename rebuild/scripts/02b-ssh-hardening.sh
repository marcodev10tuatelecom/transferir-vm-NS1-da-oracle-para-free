#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; new_evidence TPS-R02B-SSH-HARDENING
[[ ${ALLOW_SSH_HARDENING:-no} == yes ]] || die ALLOW_SSH_HARDENING_NOT_SET
id marco >/dev/null 2>&1 || die MARCO_USER_MISSING
[[ -s /home/marco/.ssh/authorized_keys ]] || die MARCO_AUTHORIZED_KEYS_MISSING
sshd -t
backup_path /etc/ssh/sshd_config.d/90-tps-hardening.conf
cat > /etc/ssh/sshd_config.d/90-tps-hardening.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
X11Forwarding no
AllowUsers marco
EOF
sshd -t || die SSHD_CONFIG_INVALID
systemctl reload ssh
systemctl is-active --quiet ssh || die SSH_NOT_ACTIVE
printf 'SSH_HARDENING=PASS\n'
printf 'WARNING=Do not close the current session before testing a second marco session.\n'
