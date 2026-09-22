#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then echo "Jalankan sebagai root: sudo bash install.sh" >&2; exit 1; fi
if ! command -v node >/dev/null 2>&1; then
  echo "Node.js belum terpasang. Install Node.js 20+ terlebih dahulu." >&2
  exit 1
fi
node_major="$(node -p 'process.versions.node.split(".")[0]')"
if (( node_major < 20 )); then echo "Node.js 20+ diperlukan. Versi saat ini: $(node --version)" >&2; exit 1; fi

read -r -p "IP/domain backend yang diizinkan (opsional, untuk firewall): " BACKEND_IP
read -r -s -p "Secret HMAC Agent (minimal 32 karakter): " AGENT_SECRET; echo
if (( ${#AGENT_SECRET} < 32 )); then echo "Secret terlalu pendek." >&2; exit 1; fi
read -r -p "Bind address agent [127.0.0.1]: " AGENT_BIND_HOST
AGENT_BIND_HOST="${AGENT_BIND_HOST:-127.0.0.1}"
read -r -p "Port lokal agent [8787]: " AGENT_PORT
AGENT_PORT="${AGENT_PORT:-8787}"
if [[ "$AGENT_BIND_HOST" != "127.0.0.1" && "$AGENT_BIND_HOST" != "0.0.0.0" && -z "$BACKEND_IP" ]]; then echo "Bind remote membutuhkan IP backend untuk allowlist firewall." >&2; exit 1; fi
if ! [[ "$AGENT_PORT" =~ ^[0-9]+$ ]] || (( AGENT_PORT < 1024 || AGENT_PORT > 65535 )); then echo "Port tidak valid." >&2; exit 1; fi

install -d -m 0750 /opt/ssh-store-agent /var/lib/ssh-store-agent /etc/ssh-store-agent
install -m 0644 src/agent.js /opt/ssh-store-agent/agent.js
cat > /etc/ssh-store-agent/agent.env <<EOF
AGENT_PORT=${AGENT_PORT}
AGENT_BIND_HOST=${AGENT_BIND_HOST}
AGENT_SHARED_SECRET=${AGENT_SECRET}
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
  echo "Instalasi berhasil. Agent aktif di 127.0.0.1:${AGENT_PORT}."
else
  echo "Service terpasang tetapi health check gagal. Cek: systemctl status ssh-store-agent" >&2
  exit 1
fi
cat <<'INFO'

Langkah berikutnya:
1. Simpan AGENT_SHARED_SECRET yang sama di backend website.
2. Jangan membuka port agent ke publik; gunakan private network/VPN atau allowlist backend.
3. Cek log: journalctl -u ssh-store-agent -f
4. Cek status: systemctl status ssh-store-agent
INFO
