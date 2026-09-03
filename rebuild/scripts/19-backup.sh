#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; new_evidence TPS-R19-BACKUP
DEST=${1:-/root/tps-backups}; install -d -m 0700 "$DEST"
STAMP=$(date -u +%Y%m%dT%H%M%SZ); HOST=$(hostname -s); OUT="$DEST/TPS-${HOST}-CONFIG-BACKUP-$STAMP.tar.gz"
# Contains secrets. Root-only and must be moved to encrypted/off-node storage.
tar --xattrs --acls -czf "$OUT" \
  /etc/bind /etc/nginx /etc/letsencrypt /etc/tpsmedia /etc/tps-secrets \
  /etc/systemd/system/tps-* /usr/local/sbin/tps-* \
  /srv/tpsmedia/repository/.tps-canonical-repository \
  2>"$EVIDENCE_DIR/tar.stderr" || die BACKUP_TAR_FAIL
chmod 0600 "$OUT"
sha256sum "$OUT" | tee "$OUT.sha256" | tee "$EVIDENCE_DIR/archive.sha256"
tar -tzf "$OUT" >/dev/null || die BACKUP_INTEGRITY_FAIL
printf 'BACKUP=PASS\nARCHIVE=%s\nSENSITIVITY=CONTAINS_PRIVATE_KEYS_AND_TSIG\n' "$OUT"
