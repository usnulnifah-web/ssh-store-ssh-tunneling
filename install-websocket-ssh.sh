#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then echo "Jalankan sebagai root: sudo bash install-websocket-ssh.sh" >&2; exit 1; fi

DOMAIN="${DOMAIN:-_}"
EMAIL="${EMAIL:-}"
WS_PORT="${WS_PORT:-8080}"
WS_PATH="${WS_PATH:-/ssh}"
SSH_HOST="${SSH_HOST:-127.0.0.1}"
SSH_PORT="${SSH_PORT:-22}"
APP_DIR="${APP_DIR:-/opt/ssh-store-websocket}"

usage(){
  cat <<'HELP'
SSH Store WebSocket + SSH Installer

Memasang proxy WebSocket yang meneruskan data ke SSH lokal. Kompatibel dengan
client WebSocket SSH seperti HTTP Injector, tanpa mematikan autentikasi SSH.

Contoh HTTP WebSocket:
  sudo DOMAIN=ws.domain.com bash install-websocket-ssh.sh

Contoh HTTPS WebSocket + sertifikat Let's Encrypt:
  sudo DOMAIN=ws.domain.com EMAIL=admin@domain.com bash install-websocket-ssh.sh

Opsi environment:
  DOMAIN       domain DNS; default _ (akses HTTP berdasarkan IP)
  EMAIL        email Let's Encrypt; kosong berarti TLS tidak diminta
  WS_PORT      port internal proxy; default 8080
  WS_PATH      path WebSocket; default /ssh
  SSH_PORT     port SSH tujuan; default 22
HELP
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="${2:?domain belum diisi}"; shift 2;;
    --email) EMAIL="${2:?email belum diisi}"; shift 2;;
    --ws-port) WS_PORT="${2:?port belum diisi}"; shift 2;;
    --ws-path) WS_PATH="${2:?path belum diisi}"; shift 2;;
    --ssh-port) SSH_PORT="${2:?port belum diisi}"; shift 2;;
    --help) usage; exit 0;;
    *) echo "Opsi tidak dikenal: $1" >&2; usage; exit 1;;
  esac
done

[[ "$WS_PORT" =~ ^[0-9]+$ && "$SSH_PORT" =~ ^[0-9]+$ ]] || { echo 'Port harus berupa angka' >&2; exit 1; }
[[ "$WS_PATH" == /* && "$WS_PATH" != */ ]] || { echo 'WS_PATH harus diawali / dan tidak diakhiri /' >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl nginx openssl
if ! command -v node >/dev/null 2>&1 || [[ "$(node -p 'process.versions.node.split(".")[0]')" -lt 20 ]]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
install -d -m 0755 "$APP_DIR"
cp "$SCRIPT_DIR/websocket-proxy/server.js" "$APP_DIR/server.js"
cat > "$APP_DIR/package.json" <<'EOF'
{"name":"ssh-store-websocket-proxy","private":true,"type":"module","dependencies":{"ws":"^8.18.0"}}
EOF
cd "$APP_DIR"
npm install --omit=dev --no-audit --no-fund
chown -R root:root "$APP_DIR"

cat > /etc/ssh-store-websocket.env <<EOF
NODE_ENV=production
WS_PORT=${WS_PORT}
WS_PATH=${WS_PATH}
SSH_HOST=${SSH_HOST}
SSH_PORT=${SSH_PORT}
EOF
chmod 0600 /etc/ssh-store-websocket.env

cat > /etc/systemd/system/ssh-store-websocket.service <<EOF
[Unit]
Description=SSH Store WebSocket to SSH Proxy
After=network-online.target ssh.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${APP_DIR}
EnvironmentFile=/etc/ssh-store-websocket.env
ExecStart=$(command -v node) server.js
Restart=always
RestartSec=3
User=www-data
Group=www-data
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/nginx/sites-available/ssh-store-websocket <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location = /health {
        proxy_pass http://127.0.0.1:${WS_PORT}/health;
    }

    location ${WS_PATH} {
        proxy_pass http://127.0.0.1:${WS_PORT}${WS_PATH};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
EOF
ln -sfn /etc/nginx/sites-available/ssh-store-websocket /etc/nginx/sites-enabled/ssh-store-websocket
nginx -t
systemctl daemon-reload
systemctl enable --now ssh-store-websocket
systemctl reload nginx

if [[ "$DOMAIN" != "_" && -n "$EMAIL" ]]; then
  apt-get install -y certbot python3-certbot-nginx
  if certbot --nginx --non-interactive --agree-tos --redirect -m "$EMAIL" -d "$DOMAIN"; then
    echo "TLS Let's Encrypt aktif untuk ${DOMAIN}."
  else
    echo "Peringatan: penerbitan TLS gagal. Pastikan DNS domain sudah mengarah ke VPS dan port 80 terbuka." >&2
  fi
fi

curl -fsS --max-time 5 "http://127.0.0.1:${WS_PORT}/health"
echo
echo "WebSocket endpoint: ws://${DOMAIN}${WS_PATH}"
if [[ "$DOMAIN" != "_" && -n "$EMAIL" ]]; then echo "WebSocket TLS endpoint: wss://${DOMAIN}${WS_PATH}"; fi
echo "SSH target: ${SSH_HOST}:${SSH_PORT}"
echo "Service: systemctl status ssh-store-websocket"
echo "HTTP Injector: gunakan host/domain, port 80 (ws) atau 443 (wss jika TLS aktif), path ${WS_PATH}, lalu login dengan akun SSH biasa."
