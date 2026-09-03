#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; new_evidence TPS-R02-IDENTITIES
section 'GROUPS'
getent group studiosatops >/dev/null || groupadd --system studiosatops
for u in tpsmedia tps-playout adminfra; do
  if ! id "$u" >/dev/null 2>&1; then
    if [[ $u == adminfra ]]; then useradd -m -s /usr/sbin/nologin "$u"; else useradd --system --home-dir "/var/lib/$u" --create-home --shell /usr/sbin/nologin "$u"; fi
  fi
done
usermod -a -G studiosatops tpsmedia
usermod -a -G studiosatops tps-playout
install -d -o tpsmedia -g tpsmedia -m 0750 /var/lib/tpsmedia/mediamtx
install -d -o tps-playout -g tps-playout -m 0750 /var/lib/tps-playout /run/tps-playout
section 'HUMAN ADMIN CHECK'
if id marco >/dev/null 2>&1; then getent group sudo | grep -Eq '(^|,)marco(,|$)' || log 'WARN=MARCO_NOT_IN_SUDO'; else log 'WARN=MARCO_USER_NOT_CREATED_AUTOMATICALLY'; fi
getent passwd tpsmedia tps-playout adminfra
printf 'IDENTITIES=PASS\n'
