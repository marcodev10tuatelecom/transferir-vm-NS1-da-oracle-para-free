#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; assert_role ns1; new_evidence TPS-R04A-TSIG
need tsig-keygen
KEY=/etc/bind/keys/tpsolutions-ns1-ns2.key
if [[ ! -s $KEY ]]; then
  umask 077
  tsig-keygen -a hmac-sha256 tpsolutions-ns1-ns2 > "$KEY"
fi
chown root:bind "$KEY"; chmod 0640 "$KEY"
sha256sum "$KEY" | tee "$EVIDENCE_DIR/tsig.sha256"
printf 'TSIG=PASS\n'
printf 'ACTION=Securely transfer %s to the same path on NS2; do not paste its content into Git/chat evidence.\n' "$KEY"
