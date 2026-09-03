#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; new_evidence TPS-R15-REPOSITORY
ROOT=/srv/tpsmedia/repository
install -d -o root -g studiosatops -m 0750 "$ROOT" "$ROOT/objects/sha256" "$ROOT/quarantine" "$ROOT/channels"
printf 'TPS_CANONICAL_REPOSITORY=1\nSCHEMA=2\n' > "$ROOT/.tps-canonical-repository"
chown root:studiosatops "$ROOT/.tps-canonical-repository"; chmod 0640 "$ROOT/.tps-canonical-repository"
for s in $STATIONS; do
  install -d -o root -g studiosatops -m 0750 "$ROOT/channels/$s/refs" "$ROOT/channels/$s/playlists" "$ROOT/channels/$s/catalog"
done
install -d -o root -g studiosatops -m 0750 /srv/tpsmedia/library/channels
printf 'REPOSITORY_LAYOUT=PASS\n'
