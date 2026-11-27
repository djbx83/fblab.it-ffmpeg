# fblab.it-ffmpeg

[![ffmpeg-nightly](https://github.com/djbx83/fblab.it-ffmpeg/actions/workflows/nightly.yml/badge.svg)](https://github.com/djbx83/fblab.it-ffmpeg/actions/workflows/nightly.yml)

## Installazione sul client (Debian/Ubuntu)

```bash
sudo curl -fsS -A "Mozilla/5.0" -o /usr/share/keyrings/fblab-archive-keyring.gpg https://packages.fblab.it/fblab-archive-keyring.gpg
sudo curl -fsS -A "Mozilla/5.0" -o /etc/apt/sources.list.d/fblab.sources https://packages.fblab.it/fblab.sources
sudo apt update
sudo apt install ffmpeg-nonfree-static
```

Lo user-agent esplicito serve perché il front-end OVH blocca quello di curl.
Windows: `https://packages.fblab.it/windows/ffmpeg/ffmpeg-latest-win64-nonfree.zip` (statico)
oppure `ffmpeg-latest-win64-nonfree-shared.zip` (con DLL, `.lib`/`.dll.a` e header per sviluppo).

Build giornaliera di FFmpeg (git master, variante **nonfree**, statica) basata su
[FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds). Produce i pacchetti e li carica
in `incoming/` di packages.fblab.it; la pubblicazione la fa il repo `fblab.it-packages`.

| Target       | Output in incoming/                                            |
|--------------|----------------------------------------------------------------|
| `linux64`    | `deb/stable/non-free/ffmpeg-nonfree-static_<ver>_amd64.deb`     |
| `linuxarm64` | `deb/stable/non-free/ffmpeg-nonfree-static_<ver>_arm64.deb`     |
| `win64`      | `windows/ffmpeg/ffmpeg-<data>-<ver>-win64-nonfree.zip` e `-nonfree-shared.zip` (DLL), più i rispettivi `ffmpeg-latest-*` |

> I binari nonfree **non sono ridistribuibili**: il repo è pubblico solo per i minuti
> Actions illimitati; i binari non vengono mai pubblicati su GitHub.

## Librerie aggiuntive

`scripts.d/` contiene script nel formato di FFmpeg-Builds per librerie che la variante
nonfree upstream non include; il workflow li copia in `ffbuilds/scripts.d/` prima della
generazione del Dockerfile. Attualmente: libcodec2, libgsm, libilbc, libshine, libspeex,
liblc3, libvo-amrwbenc, libmodplug, libbs2b, libmysofa, libsvtjpegxs, libxevd, libxeve,
libqrencode, libquirc, libklvanc, decklink (header Desktop Video SDK 12.0 da OBS Studio;
il driver Blackmagic Desktop Video va installato sul client, caricato a run time),
libmpeghdec (MPEG-H 3D Audio, Fraunhofer), libflite, librabbitmq, libcaca (driver
ncurses su Linux, console win32 su Windows), libxavs. Inoltre `apply-overlay.sh` abilita
libfdk-xhe-aac (encoder xHE-AAC), già compilata dallo stage fdk-aac di FFmpeg-Builds.

Schedulato alle 02:37 UTC (tutti i target); a mano con *Run workflow*: `target` sceglie
un singolo target o `all`, `publish` decide se caricare in incoming/.

### NDI (`libndi_newtek`)

Il device NDI, rimosso da FFmpeg nel 2019, viene reinserito da `packaging/ffpatch/`
(sorgenti da [moocowsheep/ffmpeg-ndi-patch](https://github.com/moocowsheep/ffmpeg-ndi-patch),
modificati per caricare il runtime a run time); `scripts.d/50-libndi.sh` fornisce solo gli
header dell'SDK NDI 6 (MIT). ffmpeg **non** dipende da libndi: il runtime serve solo quando
si usa `-f libndi_newtek`, e va installato a parte (NDI Runtime / NDI Tools).

Linux, dal repo: `sudo apt install ndi-runtime-installer`. Il pacchetto (`ndi-installer/`,
workflow *ndi-runtime-installer*, a mano dopo aver alzato `ndi-installer/VERSION`) non
contiene binari NDI: chiede via debconf l'accettazione della licenza NDI SDK, scarica
l'SDK da ndi.video e installa solo `libndi.so.6` in `/usr/lib/ndi-runtime` (ldconfig).
Aggiornare il runtime: `sudo update-ndi-runtime`. Windows: `winget install --exact --id NDI.NDIRuntime`.

Ricerca del runtime: `$NDI_RUNTIME_DIR_V6` (impostata dall'installer Windows), poi
`$NDI_RUNTIME_DIR_V5`; Linux `libndi.so.6` → `libndi.so.5` → `libndi.so` (ld.so.cache,
`LD_LIBRARY_PATH`); Windows `Processing.NDI.Lib.x64.dll` accanto a ffmpeg.exe o in System32.

```
ffmpeg -f libndi_newtek -find_sources 1 -i dummy
ffmpeg -f libndi_newtek -i "HOST (Sorgente)" ...
ffmpeg -re -i input.mp4 -pix_fmt uyvy422 -c:a pcm_s16le -f libndi_newtek "Nome uscita"
```

## Secrets

`SFTP_HOST`, `SFTP_PORT`, `SFTP_USER`, `SFTP_PASSWORD`, `SFTP_KNOWN_HOSTS`

## Variables

| Variable | |
|---|---|
| `REMOTE_DIR` | root di packages.fblab.it sull'SFTP (`.`) |
| `FFBUILDS_REF` | commit/branch FFmpeg-Builds (default master) |
| `DEB_MAINTAINER` | campo Maintainer dei .deb |
