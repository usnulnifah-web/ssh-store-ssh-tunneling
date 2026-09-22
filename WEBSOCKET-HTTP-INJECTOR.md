# SSH WebSocket untuk HTTP Injector

## Arti terpisah

Komponen dibuat terpisah supaya satu website dapat mengelola banyak VPS tunnel:

```text
Website + Backend API (ssh-store)
              |
              | HMAC/API
              v
VPS Tunnel (ssh-store-vps-agent-installer)
  - SSH server
  - SSH WebSocket proxy
  - Nginx port 80/443
```

Repository website memasang halaman publik, member, admin, dan API. Repository VPS memasang service pada VPS yang menjadi endpoint tunnel. Keduanya dapat berada pada server yang sama atau berbeda.

## Instalasi

Pada VPS Ubuntu/Debian yang menjalankan SSH:

```bash
git clone https://github.com/usnulnifah-web/ssh-store-website-ssh-tunneling.git
cd ssh-store-vps-agent-installer
sudo DOMAIN=ws.domain-anda.com EMAIL=admin@domain-anda.com bash install-websocket-ssh.sh
```

Untuk WebSocket tanpa TLS saat uji coba:

```bash
sudo DOMAIN=_ bash install-websocket-ssh.sh
```

Untuk HTTPS/WSS, DNS domain harus sudah menunjuk ke IP VPS dan port 80/443 harus dapat diakses. Installer meminta sertifikat Let's Encrypt jika `DOMAIN` dan `EMAIL` diisi.

## Pengaturan HTTP Injector

Gunakan akun SSH yang dibuat oleh VPS Agent:

| Pengaturan | WebSocket biasa | WebSocket TLS |
|---|---:|---:|
| Host | domain VPS | domain VPS |
| Port | 80 | 443 |
| Path | `/ssh` | `/ssh` |
| TLS/SSL | Nonaktif | Aktif |
| Username/password | akun SSH | akun SSH |

Gunakan `wss://domain/ssh` hanya setelah sertifikat TLS berhasil diterbitkan. Proxy ini hanya meneruskan koneksi WebSocket ke `127.0.0.1:22`; autentikasi tetap dilakukan oleh SSH.

## Perintah operasional

```bash
sudo systemctl status ssh-store-websocket
sudo journalctl -u ssh-store-websocket -f
curl http://127.0.0.1:8080/health
sudo systemctl restart ssh-store-websocket
```

## Catatan penting

Installer ini memasang **SSH WebSocket proxy nyata**, bukan sekadar menu. Ia tidak memasang payload bypass, tidak menerima perintah shell melalui HTTP, dan tidak menghapus keamanan login SSH. Jangan gunakan untuk akses tanpa izin, DDoS, port scanning, malware, atau pelanggaran jaringan.

Jika website dan WebSocket dipasang pada VPS yang sama dengan domain berbeda, keduanya dapat berbagi Nginx. Jika memakai domain yang sama, konfigurasi Nginx harus digabung agar route `/ssh` diteruskan ke proxy dan route website tetap dilayani oleh website.
