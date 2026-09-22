#!/usr/bin/env bash
set -Eeuo pipefail
LICENSE_FILE=/var/lib/ssh-store-agent/license.env
if [[ ! -r "$LICENSE_FILE" ]]; then echo 'Lisensi belum tersedia.'; exit 1; fi
. "$LICENSE_FILE"
case "${1:-status}" in
  status) printf 'Status: %s | Berakhir: ' "$LICENSE_STATUS"; date -d "@${LICENSE_EXPIRES_EPOCH}" '+%Y-%m-%d %H:%M:%S %Z';;
  extend) [[ "${2:-}" =~ ^[0-9]+$ ]] || { echo 'Gunakan: license-manager.sh extend JUMLAH_HARI'; exit 1; }; new_exp=$(( $(date +%s) + 86400 * $2 )); printf 'LICENSE_STATUS=active\nLICENSE_EXPIRES_EPOCH=%s\n' "$new_exp" > "$LICENSE_FILE"; chmod 600 "$LICENSE_FILE"; echo "Lisensi diperpanjang $2 hari.";;
  *) echo 'Gunakan: license-manager.sh status|extend JUMLAH_HARI'; exit 1;;
esac
