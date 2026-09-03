#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root
SRC=${1:?source media file}; STATION=${2:?station}; COMMON=${3:-$TPS_REBUILD_ROOT/common.env}
load_env "$COMMON"; new_evidence TPS-R16-MEDIA-INGEST
[[ -f $SRC && ! -L $SRC ]] || die SOURCE_INVALID
grep -qw "$STATION" <<<" $STATIONS " || die UNKNOWN_STATION
need ffprobe; need sha256sum
ffprobe -v error -show_streams -show_format -of json "$SRC" | jq . > "$EVIDENCE_DIR/ffprobe.json" || die FFPROBE_FAIL
jq -e '.streams|length>0' "$EVIDENCE_DIR/ffprobe.json" >/dev/null || die NO_STREAMS
SHA=$(sha256_file "$SRC"); EXT=${SRC##*.}; OBJ="/srv/tpsmedia/repository/objects/sha256/${SHA:0:2}/${SHA}.$EXT"
install -d -o root -g studiosatops -m 0750 "$(dirname "$OBJ")"
if [[ ! -f $OBJ ]]; then install -o root -g studiosatops -m 0640 "$SRC" "$OBJ"; fi
[[ $(sha256_file "$OBJ") == "$SHA" ]] || die OBJECT_HASH_FAIL
REF="/srv/tpsmedia/repository/channels/$STATION/refs/${SHA}.ref"
printf 'sha256=%s\nobject=%s\nsource_name=%s\n' "$SHA" "$OBJ" "$(basename "$SRC")" > "$REF"
chown root:studiosatops "$REF"; chmod 0640 "$REF"
printf 'INGEST=PASS\nSHA256=%s\nOBJECT=%s\nREF=%s\n' "$SHA" "$OBJ" "$REF"
