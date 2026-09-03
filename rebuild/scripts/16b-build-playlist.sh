#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; STATION=${1:?station}; COMMON=${2:-$TPS_REBUILD_ROOT/common.env}; load_env "$COMMON"; new_evidence TPS-R16B-PLAYLIST
grep -qw "$STATION" <<<" $STATIONS " || die UNKNOWN_STATION
REFDIR=/srv/tpsmedia/repository/channels/$STATION/refs; OUT=/srv/tpsmedia/repository/channels/$STATION/playlists/playlist.txt
mapfile -t refs < <(find "$REFDIR" -maxdepth 1 -type f -name '*.ref' -print | sort)
((${#refs[@]} > 0)) || die NO_REFS
TMP=$(mktemp)
printf 'ffconcat version 1.0\n' > "$TMP"
for r in "${refs[@]}"; do
  obj=$(awk -F= '$1=="object"{print substr($0,index($0,"=")+1)}' "$r")
  [[ -f $obj ]] || die "OBJECT_MISSING:$obj"
  ffprobe -v error "$obj" >/dev/null 2>&1 || die "FFPROBE_FAIL:$obj"
  esc=${obj//\'/\'\\\'\'}
  printf "file '%s'\n" "$esc" >> "$TMP"
done
install -o root -g studiosatops -m 0640 "$TMP" "$OUT"; rm -f "$TMP"
printf 'PLAYLIST_ITEMS=%d\nPLAYLIST=%s\nPLAYLIST_BUILD=PASS\n' "${#refs[@]}" "$OUT"
