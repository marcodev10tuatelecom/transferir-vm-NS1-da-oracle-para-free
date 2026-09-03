#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

TPS_REBUILD_ROOT=${TPS_REBUILD_ROOT:-/root/tps-rebuild}
TPS_EVIDENCE_ROOT=${TPS_EVIDENCE_ROOT:-/var/log/tps-rebuild}

log(){ printf '%s\n' "$*"; }
section(){ printf '\n============================================================\n%s\n============================================================\n' "$1"; }
die(){ printf 'FATAL=%s\n' "$*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "MISSING_COMMAND:$1"; }
require_root(){ [[ ${EUID:-$(id -u)} -eq 0 ]] || die ROOT_REQUIRED; }

load_env(){
  local f=$1
  [[ -f $f && ! -L $f ]] || die "ENV_INVALID:$f"
  # shellcheck disable=SC1090
  source "$f"
}

require_var(){
  local n=$1 v=${!1-}
  [[ -n $v ]] || die "MISSING_VAR:$n"
  [[ $v != *CHANGE_ME* ]] || die "PLACEHOLDER_VAR:$n"
}

new_evidence(){
  local name=$1
  RUN_ID="${name}-$(date -u +%Y%m%dT%H%M%SZ)"
  EVIDENCE_DIR="${TPS_EVIDENCE_ROOT}/${RUN_ID}"
  install -d -m 0700 "$EVIDENCE_DIR"
  exec > >(tee -a "${EVIDENCE_DIR}/execution.log") 2>&1
  export RUN_ID EVIDENCE_DIR
  log "RUN_ID=$RUN_ID"
  log "EVIDENCE_DIR=$EVIDENCE_DIR"
}

backup_path(){
  local p=$1
  [[ -e $p || -L $p ]] || return 0
  local rel=${p#/}
  install -d -m 0700 "${EVIDENCE_DIR}/backup/$(dirname "$rel")"
  cp -a -- "$p" "${EVIDENCE_DIR}/backup/$rel"
}

assert_role(){
  local expected=$1
  [[ ${ROLE-} == "$expected" ]] || die "ROLE_MISMATCH:expected=$expected actual=${ROLE-UNSET}"
}

assert_hostname(){
  [[ $(hostname -s) == ${HOSTNAME_SHORT:?} ]] || die "HOSTNAME_MISMATCH:$(hostname -s):${HOSTNAME_SHORT}"
}

sha256_file(){ sha256sum "$1" | awk '{print $1}'; }

install_checked(){
  local mode=$1 src=$2 dst=$3
  install -D -o root -g root -m "$mode" "$src" "$dst"
  [[ -f $dst ]] || die "INSTALL_FAILED:$dst"
}
