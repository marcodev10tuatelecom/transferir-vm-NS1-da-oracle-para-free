#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; STATION=${1:?station}; COMMON=${2:-$TPS_REBUILD_ROOT/common.env}; load_env "$COMMON"; new_evidence TPS-R17C-TV-PROFILE
PLAYLIST=/srv/tpsmedia/repository/channels/$STATION/playlists/playlist.txt; [[ -s $PLAYLIST ]] || die PLAYLIST_MISSING
fail=0
while IFS= read -r line; do
  [[ $line == file\ * ]] || continue
  f=${line#file }; f=${f#\'}; f=${f%\'}
  j=$(ffprobe -v error -show_streams -of json "$f") || { log "FAIL=$f"; fail=1; continue; }
  v=$(jq -r '[.streams[]|select(.codec_type=="video")][0].codec_name // ""' <<<"$j")
  a=$(jq -r '[.streams[]|select(.codec_type=="audio")][0].codec_name // ""' <<<"$j")
  [[ $v == h264 && $a == aac ]] || { log "PROFILE_FAIL=$f|VIDEO=$v|AUDIO=$a"; fail=1; }
done < "$PLAYLIST"
[[ $fail -eq 0 ]] || die TV_PROFILE_FAIL
printf 'TV_PROFILE=PASS\n'
