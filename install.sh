#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then echo "Jalankan sebagai root: sudo bash install.sh" >&2; exit 1; fi
if ! command -v node >/dev/null 2>&1; then echo "Node.js belum terpasang. Install Node.js 20+ terlebih dahulu." >&2; exit 1; fi
node_major="$(node -p 'process.versions.node.split(".")[0]')"
if (( node_major < 20 )); then echo "Node.js 20+ diperlukan. Versi saat ini: $(node --version)" >&2; exit 1; fi

BACKEND_IP="${BACKEND_IP:-}"
AGENT_BIND_HOST="${AGENT_BIND_HOST:-127.0.0.1}"
AGENT_PORT="${AGENT_PORT:-8787}"
AGENT_SHARED_SECRET="${AGENT_SHARED_SECRET:-}"

usage(){
  cat <<'HELP'
Penggunaan:
  sudo bash install.sh [opsi]

Opsi:
  --backend-ip IP       IP backend yang diizinkan firewall (opsional)
  --bind-host HOST      default 127.0.0.1; gunakan 0.0.0.0 hanya dengan firewall
  --port PORT           default 8787
  --secret SECRET       secret HMAC; jika kosong dibuat otomatis
  --help                tampilkan bantuan

Contoh backend berbeda:
  sudo bash install.sh --backend-ip 198.51.100.10 --bind-host 0.0.0.0
HELP
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend-ip) BACKEND_IP="${2:?IP backend belum diisi}"; shift 2;;
    --bind-host) AGENT_BIND_HOST="${2:?bind host belum diisi}"; shift 2;;
    --port) AGENT_PORT="${2:?port belum diisi}"; shift 2;;
    --secret) AGENT_SHARED_SECRET="${2:?secret belum diisi}"; shift 2;;
    --help) usage; exit 0;;
    *) echo "Opsi tidak dikenal: $1" >&2; usage; exit 1;;
  esac
done

if [[ "$AGENT_BIND_HOST" != "127.0.0.1" && "$AGENT_BIND_HOST" != "0.0.0.0" && -z "$BACKEND_IP" ]]; then echo "Bind remote membutuhkan --backend-ip untuk allowlist firewall." >&2; exit 1; fi
if ! [[ "$AGENT_PORT" =~ ^[0-9]+$ ]] || (( AGENT_PORT < 1024 || AGENT_PORT > 65535 )); then echo "Port tidak valid: $AGENT_PORT" >&2; exit 1; fi
if [[ -z "$AGENT_SHARED_SECRET" ]]; then AGENT_SHARED_SECRET="$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | base64 -w0)"; fi
if (( ${#AGENT_SHARED_SECRET} < 32 )); then echo "Secret minimal 32 karakter." >&2; exit 1; fi

install -d -m 0750 /opt/ssh-store-agent /var/lib/ssh-store-agent /etc/ssh-store-agent
install -m 0644 src/agent.js /opt/ssh-store-agent/agent.js
cat > /etc/ssh-store-agent/agent.env <<EOF
AGENT_PORT=${AGENT_PORT}
AGENT_BIND_HOST=${AGENT_BIND_HOST}
AGENT_SHARED_SECRET=${AGENT_SHARED_SECRET}
AGENT_DATA_FILE=/var/lib/ssh-store-agent/accounts.json
AGENT_MAX_SKEW_SECONDS=60
EOF
chmod 0600 /etc/ssh-store-agent/agent.env
chown -R root:root /opt/ssh-store-agent /etc/ssh-store-agent /var/lib/ssh-store-agent

install -m 0644 systemd/ssh-store-agent.service /etc/systemd/system/ssh-store-agent.service
systemctl daemon-reload
systemctl enable --now ssh-store-agent

if command -v ufw >/dev/null 2>&1; then
  ufw deny "${AGENT_PORT}/tcp" >/dev/null || true
  if [[ -n "${BACKEND_IP}" ]]; then ufw allow from "${BACKEND_IP}" to any port "${AGENT_PORT}" proto tcp >/dev/null; fi
fi

if curl -fsS --max-time 5 "http://127.0.0.1:${AGENT_PORT}/health" | grep -q 'ssh-store-agent'; then
  echo "Instalasi berhasil. Agent aktif di ${AGENT_BIND_HOST}:${AGENT_PORT}."
else
  echo "Service terpasang tetapi health check gagal. Cek: systemctl status ssh-store-agent" >&2
  exit 1
fi

echo "Secret tersimpan aman di /etc/ssh-store-agent/agent.env"
echo "Untuk menghubungkan backend, jalankan: sudo grep AGENT_SHARED_SECRET /etc/ssh-store-agent/agent.env"
echo "Log: journalctl -u ssh-store-agent -f"
