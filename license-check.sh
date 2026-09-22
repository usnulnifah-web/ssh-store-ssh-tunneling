#!/usr/bin/env bash
set -Eeuo pipefail
LICENSE_FILE=/var/lib/ssh-store-agent/license.env
if [[ ! -r "$LICENSE_FILE" ]]; then echo 'Lisensi tidak ditemukan. Hubungi admin website.' >&2; exit 1; fi
. "$LICENSE_FILE"
now=$(date +%s)
if [[ "${LICENSE_STATUS:-active}" != "active" || ! "${LICENSE_EXPIRES_EPOCH:-}" =~ ^[0-9]+$ || "$now" -ge "$LICENSE_EXPIRES_EPOCH" ]]; then
  echo 'Masa trial/lisensi sudah berakhir. Perpanjang lisensi untuk menjalankan agent.' >&2
  exit 1
fi
