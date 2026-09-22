# SSH Store VPS Agent Installer

Repository ini khusus untuk memasang **VPS Provisioning Agent** di VPS pelanggan. Agent menerima perintah terbatas dari backend website untuk membuat, memperpanjang, menangguhkan, mengaktifkan kembali, menghapus akun SSH, dan mengirim metrics CPU/RAM.

## Repository mana untuk apa?

| Repository | Fungsi | Dipasang di mana? |
|---|---|---|
| [ssh-store-website](https://github.com/usnulnifah-web/ssh-store-website) | Website publik, dashboard member, panel admin, Backend API, dan roadmap aplikasi | Hosting/backend website |
| `ssh-store-ssh-tunneling` | Installer, unit systemd, dan source VPS Agent | Setiap VPS yang ingin dihubungkan |

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
git clone https://github.com/usnulnifah-web/ssh-store-ssh-tunneling.git
cd ssh-store-ssh-tunneling
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

Manual operasi admin dan user tersedia di [ADMIN-USER-MANUAL.md](https://github.com/usnulnifah-web/ssh-store-website/blob/main/ADMIN-USER-MANUAL.md).

## Menu terminal admin Habibillah

Installer terbaru juga memasang menu terminal berwarna untuk login SSH root interaktif. Menu menampilkan nama **HABIBILLAH STORE**, status agent, dan daftar protocol bernomor.

Saat root login melalui SSH secara interaktif, menu muncul otomatis. Pilihan utama:

```text
1. SSH WebSocket
2. OpenVPN WebSocket
3. V2Ray / VLESS
4. Trojan
5. Shadowsocks
6. WireGuard
7. WebSocket SSL / TLS
0. Keluar ke shell
```

Pilih `1` untuk submenu SSH WebSocket:

```text
1. Lihat daftar akun
2. Buat akun baru
3. Perpanjang akun
4. Suspend / aktifkan akun
5. Hapus akun
0. Kembali
```

Penghapusan akun meminta konfirmasi dengan mengetik `HAPUS`. Menu hanya berjalan pada terminal SSH interaktif root, sehingga tidak mengganggu `scp`, cron, API, atau perintah SSH otomatis. Jika ingin keluar dari menu ke shell, pilih `0`.

Menu ini mengelola akun melalui VPS Agent lokal. Provisioner OpenVPN, V2Ray, Trojan, Shadowsocks, dan WireGuard harus diaktifkan setelah konfigurasi protocol masing-masing selesai diuji dari panel admin.

## Lisensi Premium dan Trial

Menu dan agent menampilkan status **SCRIPT INI PREMIUM BERLANGGANAN**. Instalasi baru mendapat trial 3 hari. Setelah masa trial berakhir, systemd menolak menjalankan agent dan menu terminal menampilkan pesan lisensi tidak aktif.

Admin dapat melihat status lisensi:

```bash
sudo ssh-store-license-manager status
```

Perpanjangan manual untuk testing/admin:

```bash
sudo ssh-store-license-manager extend 30
```

Pada produksi, perpanjangan sebaiknya dilakukan oleh Backend API setelah pembayaran/aktivasi pelanggan terverifikasi. File lisensi berada di `/var/lib/ssh-store-agent/license.env` dan tidak boleh diedit atau dibagikan sembarangan.

## Informasi OS dan Halaman Admin

Menu login SSH mendeteksi dan menampilkan tipe OS VPS, misalnya `Ubuntu 24.04`. Menu juga menampilkan alamat panel admin dengan format:

```text
https://www.domain-anda.com/admin
```

Saat memasang agent, alamat tersebut dapat diganti dengan domain website sebenarnya:

```bash
sudo ADMIN_PANEL_URL=https://www.domain-asli.com/admin bash install.sh
```

## SSH WebSocket untuk HTTP Injector

Installer WebSocket proxy tersedia di `install-websocket-ssh.sh`. Dokumentasi lengkap penggunaan dan pengaturan client ada di [WEBSOCKET-HTTP-INJECTOR.md](./WEBSOCKET-HTTP-INJECTOR.md).

```bash
sudo DOMAIN=ws.domain-anda.com EMAIL=admin@domain-anda.com bash install-websocket-ssh.sh
```

Installer ini memasang proxy WebSocket nyata ke SSH lokal, Nginx, service systemd, health check, dan TLS Let's Encrypt opsional. Gunakan port `80` dengan path `/ssh` untuk WS atau port `443` dengan path `/ssh` setelah TLS aktif untuk WSS.


## DNS produk dan domain tunnel

Hostname harus diarahkan ke IP VPS tempat layanan tersebut berjalan. Untuk SSH WebSocket, buat record seperti berikut:

```text
Type: A
Name: ssh
Value: IP_PUBLIK_VPS_TUNNEL
TTL: 300
```

Kemudian verifikasi:

```bash
dig +short ssh.domain-anda.com
```

Hasil harus sama dengan IP publik VPS tunnel. Instalasi WSS membutuhkan port TCP `80` untuk verifikasi sertifikat dan TCP `443` untuk koneksi TLS:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo DOMAIN=ssh.domain-anda.com EMAIL=admin@domain-anda.com bash install-websocket-ssh.sh
```

Gunakan pemetaan berikut saat membuat produk pada panel admin:

| Produk | Hostname | Target DNS | Endpoint |
|---|---|---|---|
| SSH WebSocket | `ssh.domain-anda.com` | IP VPS SSH tunnel | `80/ssh` |
| SSH WebSocket TLS | `ssh.domain-anda.com` | IP VPS SSH tunnel | `443/ssh` |
| OpenVPN WebSocket | `vpn.domain-anda.com` | IP VPS OpenVPN | port/path OpenVPN |
| V2Ray/VLESS | `vless.domain-anda.com` | IP VPS V2Ray | port/path VLESS |
| Trojan | `trojan.domain-anda.com` | IP VPS Trojan | port Trojan |
| WireGuard | `wg.domain-anda.com` | IP VPS WireGuard | UDP port WireGuard |

Jangan menggunakan hostname SSH untuk produk V2Ray atau OpenVPN jika produk tersebut berada pada VPS yang berbeda. Detail HTTP Injector untuk SSH TLS adalah host `ssh.domain-anda.com`, port `443`, path `/ssh`, TLS aktif, serta username dan password akun SSH.
