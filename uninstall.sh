#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "${EUID}" -ne 0 ]]; then echo "Jalankan sebagai root: sudo bash uninstall.sh" >&2; exit 1; fi
systemctl disable --now ssh-store-agent 2>/dev/null || true
rm -f /etc/systemd/system/ssh-store-agent.service
systemctl daemon-reload
rm -rf /opt/ssh-store-agent /etc/ssh-store-agent
if [[ "${1:-}" == "--purge" ]]; then rm -rf /var/lib/ssh-store-agent; echo "Data agent ikut dihapus."; else echo "Data akun tetap disimpan di /var/lib/ssh-store-agent. Gunakan --purge jika memang ingin menghapusnya."; fi
echo "VPS Agent berhasil dihentikan dan dihapus."
