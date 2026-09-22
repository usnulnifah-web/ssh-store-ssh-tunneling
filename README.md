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

Installer berjalan non-interaktif dengan default aman: bind `127.0.0.1`, port `8787`, dan shared secret HMAC dibuat otomatis. Untuk backend di server berbeda, parameter opsional dapat diberikan tanpa prompt:

```bash
sudo bash install.sh --backend-ip 198.51.100.10 --bind-host 0.0.0.0
```

Secret HMAC bukan password SSH VPS. Secret tersebut hanya mengamankan komunikasi Backend API dengan Agent. Password/SSH key untuk koneksi VPS diatur terpisah dari panel admin website.

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

## Bind address dan koneksi remote

Default agent bind ke `127.0.0.1`, cocok jika Backend API berjalan pada VPS yang sama. Jika Backend API berada di server berbeda, installer dapat memakai bind address `0.0.0.0` atau alamat private interface, tetapi **wajib** mengisi IP backend pada prompt firewall. Jangan membuka port agent ke seluruh internet. Untuk produksi, private network/VPN lebih baik daripada bind publik.

## Jika health check gagal

Versi installer terbaru otomatis mendeteksi lokasi Node.js, termasuk instalasi melalui NVM, lalu memasukkan path tersebut ke unit systemd. Jika service tetap gagal, installer sekarang langsung menampilkan `systemctl status` dan 30 baris `journalctl` agar penyebab terlihat.

Untuk memperbarui installer:

```bash
git pull
sudo bash install.sh
```
