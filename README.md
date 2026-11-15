# fblab.it-ffmpeg

## Installazione sul client (Debian/Ubuntu)

```bash
sudo curl -fsS -A "Mozilla/5.0" -o /usr/share/keyrings/fblab-archive-keyring.gpg https://packages.fblab.it/fblab-archive-keyring.gpg
sudo curl -fsS -A "Mozilla/5.0" -o /etc/apt/sources.list.d/fblab.sources https://packages.fblab.it/fblab.sources
sudo apt update
sudo apt install ffmpeg-nonfree-static
```

Lo user-agent esplicito serve perché il front-end OVH blocca quello di curl.
Windows: `https://packages.fblab.it/windows/ffmpeg/ffmpeg-latest-win64-nonfree.zip`.

Build giornaliera di FFmpeg (git master, variante **nonfree**, statica) basata su
[FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds). Produce i pacchetti e li carica
in `incoming/` di packages.fblab.it; la pubblicazione la fa il repo `fblab.it-packages`.

| Target       | Output in incoming/                                            |
|--------------|----------------------------------------------------------------|
| `linux64`    | `deb/stable/non-free/ffmpeg-nonfree-static_<ver>_amd64.deb`     |
| `linuxarm64` | `deb/stable/non-free/ffmpeg-nonfree-static_<ver>_arm64.deb`     |
| `win64`      | `windows/ffmpeg/ffmpeg-<data>-<ver>-win64-nonfree.zip` + `ffmpeg-latest-win64-nonfree.zip` |

> I binari nonfree **non sono ridistribuibili**: il repo è pubblico solo per i minuti
> Actions illimitati; i binari non vengono mai pubblicati su GitHub.

## Librerie aggiuntive

`scripts.d/` contiene script nel formato di FFmpeg-Builds per librerie che la variante
nonfree upstream non include; il workflow li copia in `ffbuilds/scripts.d/` prima della
generazione del Dockerfile. Attualmente: libcodec2, libgsm, libilbc, libshine, libspeex.

Schedulato alle 02:37 UTC; a mano con *Run workflow* (`publish` decide se caricare).

## Secrets

`SFTP_HOST`, `SFTP_PORT`, `SFTP_USER`, `SFTP_PASSWORD`, `SFTP_KNOWN_HOSTS`

## Variables

| Variable | |
|---|---|
| `REMOTE_DIR` | root di packages.fblab.it sull'SFTP (`.`) |
| `FFBUILDS_REF` | commit/branch FFmpeg-Builds (default master) |
| `DEB_MAINTAINER` | campo Maintainer dei .deb |
