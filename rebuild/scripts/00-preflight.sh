#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/tps-common.sh
source "$DIR/lib/tps-common.sh"
require_root
COMMON=${1:-$TPS_REBUILD_ROOT/common.env}
NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"
new_evidence TPS-R00-PREFLIGHT
for v in ROLE HOSTNAME_SHORT PUBLIC_IPV4 PRIVATE_IPV4 PEER_PRIVATE_IPV4 PRIVATE_CIDR SSH_ADMIN_CIDR; do require_var "$v"; done
for c in bash awk sed grep ip ss systemctl hostnamectl timedatectl apt-get sha256sum curl openssl; do need "$c"; done
section 'OS'
. /etc/os-release
printf 'ID=%s VERSION_ID=%s ARCH=%s\n' "$ID" "$VERSION_ID" "$(dpkg --print-architecture)"
[[ $ID == ubuntu ]] || die UNSUPPORTED_OS
[[ $VERSION_ID == 22.04 ]] || die "UNSUPPORTED_UBUNTU:$VERSION_ID"
section 'HOST'
printf 'HOST=%s ROLE=%s PRIVATE=%s PUBLIC=%s\n' "$(hostname -s)" "$ROLE" "$PRIVATE_IPV4" "$PUBLIC_IPV4"
ip -br addr
ip route
section 'TIME'
timedatectl status
[[ $(timedatectl show -p NTPSynchronized --value) == yes ]] || die NTP_NOT_SYNCED
section 'LISTENERS BEFORE BUILD'
ss -lntup || true
section 'CAPACITY'
df -hT /
free -h
printf 'PRECHECK=PASS\n'
