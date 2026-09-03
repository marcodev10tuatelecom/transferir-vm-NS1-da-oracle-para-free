#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mapfile -t scripts < <(find "$ROOT/scripts" -type f -name '*.sh' -print | sort)
((${#scripts[@]} > 0)) || { echo FATAL=NO_SCRIPTS; exit 1; }
for s in "${scripts[@]}"; do bash -n "$s"; done
if command -v shellcheck >/dev/null 2>&1; then shellcheck -x -e SC1090,SC1091 "${scripts[@]}"; else echo FATAL=SHELLCHECK_MISSING; exit 2; fi
printf 'BASH_N=PASS\nSHELLCHECK=PASS\n'
