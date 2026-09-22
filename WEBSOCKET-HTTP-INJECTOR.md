# SSH WebSocket untuk HTTP Injector

Dokumen ini hanya menjelaskan fitur yang dipasang oleh repository ini: **akun SSH Linux** dan **proxy SSH WebSocket**. Fitur OpenVPN, V2Ray, Trojan, Shadowsocks, dan WireGuard belum dipasang oleh installer ini sehingga tidak dibahas sebagai fitur aktif.

## Komponen yang dipasang

`install.sh` memasang VPS Agent untuk membuat dan mengelola akun SSH. `install-websocket-ssh.sh` memasang proxy WebSocket yang meneruskan koneksi ke SSH lokal pada port 22.

```text
HTTP Injector
    |
    | WebSocket / WSS
    v
Nginx port 80 atau 443
    |
    v
SSH WebSocket Proxy /ssh
    |
    v
SSH server 127.0.0.1:22
```

## Persyaratan

Gunakan Ubuntu/Debian dengan akses root, SSH aktif, Node.js 20 atau lebih baru, serta domain yang dapat diarahkan ke IP publik VPS. Untuk WSS, port TCP 80 dan 443 harus dapat diakses dari internet.

## Instalasi VPS Agent

```bash
git clone https://github.com/usnulnifah-web/ssh-store-ssh-tunneling.git
cd ssh-store-ssh-tunneling
sudo bash install.sh
```

Installer membuat service `ssh-store-agent` dan memasang menu admin SSH. Agent digunakan untuk membuat akun dengan username, password acak, dan tanggal kedaluwarsa.

## Instalasi SSH WebSocket tanpa TLS

Pastikan DNS hostname sudah mengarah ke IP VPS, lalu jalankan:

```bash
sudo DOMAIN=ssh.domain-anda.com bash install-websocket-ssh.sh
```

Endpoint yang dihasilkan:

```text
ws://ssh.domain-anda.com/ssh
```

Port publik: `80`. Path: `/ssh`.

## Instalasi SSH WebSocket dengan TLS/WSS

Buat DNS record terlebih dahulu:

```text
Type: A
Name: ssh
Value: IP_PUBLIK_VPS
TTL: 300
```

Periksa hasil DNS:

```bash
dig +short ssh.domain-anda.com
```

Output harus sama dengan IP publik VPS. Setelah itu jalankan:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo DOMAIN=ssh.domain-anda.com EMAIL=admin@domain-anda.com bash install-websocket-ssh.sh
```

Installer meminta sertifikat Let's Encrypt, mengatur Nginx, dan mengaktifkan WSS jika DNS serta verifikasi port berhasil.

Endpoint TLS:

```text
wss://ssh.domain-anda.com/ssh
```

## Pengaturan HTTP Injector

Gunakan akun SSH yang dibuat melalui menu Agent atau Backend Website.

| Field | Tanpa TLS | Dengan TLS |
|---|---|---|
| WebSocket host | `ssh.domain-anda.com` | `ssh.domain-anda.com` |
| WebSocket port | `80` | `443` |
| WebSocket path | `/ssh` | `/ssh` |
| TLS/SSL | Nonaktif | Aktif |
| SNI/Server Name | kosong atau hostname | `ssh.domain-anda.com` |
| SSH username | username akun | username akun |
| SSH password | password akun | password akun |
| SSH port tujuan | `22` | `22` |

Proxy ini tidak mengganti autentikasi SSH. Username dan password tetap diverifikasi oleh SSH server VPS.

## Perintah penggunaan

Periksa service Agent:

```bash
sudo systemctl status ssh-store-agent --no-pager
sudo journalctl -u ssh-store-agent -n 50 --no-pager
curl http://127.0.0.1:8787/health
```

Periksa service WebSocket:

```bash
sudo systemctl status ssh-store-websocket --no-pager
sudo journalctl -u ssh-store-websocket -n 50 --no-pager
curl http://127.0.0.1:8080/health
sudo systemctl restart ssh-store-websocket
```

Periksa Nginx dan port:

```bash
sudo nginx -t
sudo systemctl reload nginx
sudo ss -ltnp | grep -E ':(80|443|8080)\\b'
```

## Troubleshooting

Jika DNS belum mengarah ke VPS, Let's Encrypt tidak dapat menerbitkan sertifikat. Jika port 80 atau 443 tertutup, buka firewall VPS dan firewall provider. Jika health check internal berhasil tetapi HTTP Injector gagal, periksa hostname, port, path `/ssh`, mode TLS, SNI, username, password, serta tanggal kedaluwarsa akun.
