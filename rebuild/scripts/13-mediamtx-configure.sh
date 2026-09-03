#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; require_var PUBLIC_IPV4; new_evidence TPS-R13-MEDIAMTX-CONFIG
BIN=/opt/tpsmedia/mediamtx/current/mediamtx; [[ -x $BIN ]] || die MEDIAMTX_BINARY_MISSING
SECRET=/etc/tps-secrets/media/publish.env; [[ -s $SECRET ]] || die PUBLISH_SECRET_FILE_MISSING
set -a; source "$SECRET"; set +a
require_var PUBLISH_USER; require_var PUBLISH_PASS
install -d -o root -g root -m 0700 /etc/tps-secrets/media
install -d -o tpsmedia -g tpsmedia -m 0750 /var/lib/tpsmedia/mediamtx
backup_path /etc/tpsmedia/mediamtx/mediamtx.yml
python3 - "$PUBLISH_USER" "$PUBLISH_PASS" "$PUBLIC_IPV4" "$STATIONS" "${DERIVED_PATHS:-}" "${ENABLE_SRT:-no}" > /etc/tpsmedia/mediamtx/mediamtx.yml <<'PY'
import json,sys
user,pw,pub,stations,derived,srt=sys.argv[1:]
paths=(stations+' '+derived).split()
expr='~^('+'|'.join(paths)+')$'
q=lambda s: json.dumps(s)
print('logLevel: info')
print('logDestinations: [stdout]')
print('authMethod: internal')
print('authInternalUsers:')
# Remote authenticated publisher.
print(f'  - user: {q(user)}')
print(f'    pass: {q(pw)}')
print('    ips: []')
print('    permissions:')
print('      - action: publish')
print(f'        path: {q(expr)}')
# Local playout publishers, no network exposure beyond loopback identity.
print('  - user: any')
print('    pass:')
print('    ips: ["127.0.0.1", "::1"]')
print('    permissions:')
print('      - action: publish')
print(f'        path: {q(expr)}')
print('      - action: api')
print('      - action: metrics')
# Public playback/read only.
print('  - user: any')
print('    pass:')
print('    ips: []')
print('    permissions:')
print('      - action: read')
print(f'        path: {q(expr)}')
print('api: true')
print('apiAddress: 127.0.0.1:9997')
print('metrics: true')
print('metricsAddress: 127.0.0.1:9998')
print('pprof: false')
print('playback: false')
print('rtsp: true')
print('rtspTransports: [tcp]')
print('rtspAddress: 127.0.0.1:8554')
print('rtmp: true')
print('rtmpAddress: :1935')
print('hls: true')
print('hlsAddress: 127.0.0.1:8888')
print('hlsAllowOrigins: ["*"]')
print('hlsVariant: lowLatency')
print('webrtc: true')
print('webrtcAddress: 127.0.0.1:8889')
print('webrtcAllowOrigins: ["*"]')
print('webrtcLocalUDPAddress: :8189')
print('webrtcLocalTCPAddress: ""')
print(f'webrtcAdditionalHosts: [{q(pub)}]')
print('srt: '+('true' if srt=='yes' else 'false'))
if srt=='yes': print('srtAddress: :8890')
print('pathDefaults:')
print('  source: publisher')
print('paths:')
for p in paths: print(f'  {p}: {{}}')
PY
chown root:tpsmedia /etc/tpsmedia/mediamtx/mediamtx.yml; chmod 0640 /etc/tpsmedia/mediamtx/mediamtx.yml
systemctl stop tps-mediamtx.service 2>/dev/null || true
set +e; timeout --signal=INT 3 runuser -u tpsmedia -- "$BIN" /etc/tpsmedia/mediamtx/mediamtx.yml >"$EVIDENCE_DIR/config-test.log" 2>&1; rc=$?; set -e
[[ $rc -eq 124 || $rc -eq 0 ]] || { cat "$EVIDENCE_DIR/config-test.log"; die MEDIAMTX_CONFIG_TEST_FAIL; }
systemctl enable --now tps-mediamtx.service
systemctl is-active --quiet tps-mediamtx.service || die MEDIAMTX_NOT_ACTIVE
printf 'MEDIAMTX_CONFIG=PASS\n'
