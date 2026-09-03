#!/usr/bin/env bash
set -Eeuo pipefail
A=${1:?backup.tar.gz}
[[ -f $A && -f $A.sha256 ]] || { echo FATAL=BACKUP_OR_SHA_MISSING; exit 1; }
(cd "$(dirname "$A")" && sha256sum -c "$(basename "$A").sha256")
tar -tzf "$A" | grep -q 'etc/bind/'
tar -tzf "$A" | grep -q 'etc/nginx/'
tar -tzf "$A" | grep -q 'etc/tpsmedia/'
tar -tzf "$A" | grep -q 'etc/systemd/system/tps-mediamtx.service'
printf 'BACKUP_ARCHIVE_VALIDATION=PASS\n'
printf 'NOTE=Full restore certification must be performed on an isolated replacement VM, not by overwriting the active node.\n'
