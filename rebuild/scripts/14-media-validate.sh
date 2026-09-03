#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; new_evidence TPS-R14-MEDIA-VALIDATE
systemctl is-active --quiet tps-mediamtx.service || die MEDIAMTX_NOT_ACTIVE
PID=$(systemctl show tps-mediamtx.service -p MainPID --value); [[ $PID -gt 1 ]] || die MEDIAMTX_PID_INVALID
curl -fsS http://127.0.0.1:9997/v3/info | jq . > "$EVIDENCE_DIR/info.json" || die API_FAIL
curl -fsS http://127.0.0.1:9997/v3/paths/list | jq . > "$EVIDENCE_DIR/paths.json" || die PATH_API_FAIL
curl -fsS http://127.0.0.1:9998/metrics > "$EVIDENCE_DIR/metrics.txt" || die METRICS_FAIL
for spec in '1935 LISTEN' '8554 127.0.0.1' '8888 127.0.0.1' '8889 127.0.0.1' '9997 127.0.0.1' '9998 127.0.0.1'; do port=${spec%% *}; ss -lntp | grep -E ":${port}[[:space:]]" >/dev/null || die "LISTENER_MISSING:$port"; done
ss -lunp | grep -E ':8189[[:space:]]' >/dev/null || die ICE_UDP_MISSING
python3 - "$EVIDENCE_DIR/paths.json" "$STATIONS" "${DERIVED_PATHS:-}" <<'PY' || exit 30
import json,sys
p=json.load(open(sys.argv[1])); got={x['name'] for x in p.get('items',[])}; exp=set((sys.argv[2]+' '+sys.argv[3]).split())
missing=exp-got
if missing: print('MISSING_PATHS='+','.join(sorted(missing))); raise SystemExit(1)
print('PATH_CATALOG=PASS')
PY
printf 'MEDIA_VALIDATE=PASS\n'
