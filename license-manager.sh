#!/usr/bin/env bash
set -Eeuo pipefail
set -a
. /etc/ssh-store-agent/agent.env
set +a
case "${1:-status}" in
  status)
    node /opt/ssh-store-agent/license-agent-check.js
    ;;
  extend)
    echo 'Perpanjangan lokal dinonaktifkan. Silakan pastikan perpanjangan paket ke 081374452477.' >&2
    echo 'Gunakan panel lisensi/hosting setelah pembayaran diverifikasi.' >&2
    exit 1
    ;;
  *)
    echo 'Gunakan: license-manager.sh status|extend JUMLAH_HARI' >&2
    exit 1
    ;;
esac
