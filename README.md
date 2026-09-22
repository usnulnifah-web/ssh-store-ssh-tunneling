# SSH Store VPS Agent Installer

Repository ini khusus untuk memasang **VPS Provisioning Agent** di VPS pelanggan. Agent menerima perintah terbatas dari backend website untuk membuat, memperpanjang, menangguhkan, mengaktifkan kembali, menghapus akun SSH, dan mengirim metrics CPU/RAM.

## Repository mana untuk apa?

| Repository | Fungsi | Dipasang di mana? |
|---|---|---|
| [ssh-store](https://github.com/usnulnifah-web/ssh-store) | Website publik, dashboard member, panel admin, Backend API, dan roadmap aplikasi | Hosting/backend website |
| `ssh-store-vps-agent-installer` | Installer, unit systemd, dan source VPS Agent | Setiap VPS yang ingin dihubungkan |

**Pelanggan tidak perlu memasang repository website ke VPS tunnel.** Mereka cukup memasang repository agent ini pada VPS yang akan membuat akun. Backend website tetap menyimpan konfigurasi server dan menghubungi agent melalui jaringan privat atau allowlist.

## Persyaratan

- Ubuntu/Debian dengan systemd.
- Node.js 20 atau lebih baru.
- Akses root/sudo saat instalasi.
- `curl` untuk health check.
- Port agent tidak dibuka ke internet umum.
- Backend website sudah siap dan memiliki secret HMAC yang sama.

## Instalasi

Sebaiknya clone lalu periksa script sebelum menjalankannya:

```bash
git clone https://github.com/usnulnifah-web/ssh-store-vps-agent-installer.git
cd ssh-store-vps-agent-installer
sudo bash install.sh
```

Installer akan meminta:

1. IP backend yang boleh masuk firewall, opsional.
2. Shared secret HMAC minimal 32 karakter.
3. Port agent lokal, default `8787`.

Installer kemudian:

- Menyalin agent ke `/opt/ssh-store-agent`.
- Menyimpan environment rahasia di `/etc/ssh-store-agent/agent.env` dengan mode `0600`.
- Menyimpan data akun di `/var/lib/ssh-store-agent`.
- Membuat service `ssh-store-agent`.
- Mengaktifkan restart otomatis systemd.
- Menolak port agent dari internet melalui UFW jika tersedia.
- Melakukan health check lokal.

## Perintah operasional

```bash
sudo systemctl status ssh-store-agent
sudo journalctl -u ssh-store-agent -f
sudo systemctl restart ssh-store-agent
curl http://127.0.0.1:8787/health
```

Untuk menghapus service tetapi mempertahankan data akun:

```bash
sudo bash uninstall.sh
```

Untuk menghapus service dan data agent secara permanen:

```bash
sudo bash uninstall.sh --purge
```

## Endpoint agent

- `GET /health` — health check lokal.
- `GET /metrics` — metrics CPU, RAM, uptime, dan load; membutuhkan HMAC.
- `POST /accounts` — membuat akun SSH.
- `POST /accounts/extend` — memperpanjang akun.
- `POST /accounts/status` — suspend/aktifkan akun.
- `DELETE /accounts/:username` — menghapus akun.

Semua endpoint selain `/health` memakai signature HMAC dengan timestamp. Agent hanya bind ke `127.0.0.1` secara default dan tidak menerima shell command bebas.

## Rekomendasi untuk pelanggan

- Gunakan domain untuk Host yang ditampilkan ke member; IP cukup disimpan sebagai konfigurasi internal.
- Password VPS didukung untuk setup awal, tetapi SSH key dengan user deploy terbatas lebih direkomendasikan untuk produksi.
- Jangan commit `agent.env`, password VPS, private key, atau shared secret ke GitHub.
- Jangan menjalankan `curl | bash` tanpa memeriksa isi script.
- Batasi akses port agent melalui private network, VPN, atau firewall IP backend.
- Gunakan satu agent per VPS dan satu secret berbeda per VPS.
- Rotasi secret jika ada indikasi bocor.
- Pantau `journalctl`, CPU, RAM, disk, dan kapasitas akun.
- Uji di VPS staging sebelum menghubungkan saldo dan payment gateway nyata.
- Tambahkan kebijakan penggunaan yang melarang DDoS, port scanning, hacking, malware, penipuan, dan akses tanpa izin.

## Catatan produksi

Installer ini memasang agent provisioning, bukan otomatis memasang semua protocol tunnel. Provisioner OpenVPN, V2Ray, VLESS, Trojan, WireGuard, dan WebSocket harus ditambahkan serta diuji sesuai konfigurasi server masing-masing sebelum produk tersebut diaktifkan di website.
