#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; require_var MEDIAMTX_VERSION; require_var MEDIAMTX_SHA256; new_evidence TPS-R12-MEDIAMTX-INSTALL
case $(dpkg --print-architecture) in amd64) A=amd64;; arm64) A=arm64;; *) die UNSUPPORTED_ARCH;; esac
V=${MEDIAMTX_VERSION#v}; F="mediamtx_v${V}_linux_${A}.tar.gz"; URL="https://github.com/bluenviron/mediamtx/releases/download/v${V}/${F}"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
curl -fL --retry 3 -o "$TMP/$F" "$URL"
actual=$(sha256_file "$TMP/$F"); printf 'EXPECTED=%s\nACTUAL=%s\n' "$MEDIAMTX_SHA256" "$actual"; [[ $actual == "$MEDIAMTX_SHA256" ]] || die MEDIAMTX_SHA256_FAIL
install -d -o root -g root -m 0755 "/opt/tpsmedia/mediamtx/releases/v$V"
tar -xzf "$TMP/$F" -C "$TMP"
install -o root -g root -m 0755 "$TMP/mediamtx" "/opt/tpsmedia/mediamtx/releases/v$V/mediamtx"
ln -sfn "/opt/tpsmedia/mediamtx/releases/v$V" /opt/tpsmedia/mediamtx/current
/opt/tpsmedia/mediamtx/current/mediamtx --version | tee "$EVIDENCE_DIR/version.txt"
grep -q "v$V" "$EVIDENCE_DIR/version.txt" || die VERSION_MISMATCH
install -o root -g root -m 0644 "$DIR/../systemd/tps-mediamtx.service" /etc/systemd/system/tps-mediamtx.service
systemctl daemon-reload
printf 'MEDIAMTX_INSTALL=PASS\n'
