# ffmpeg-nightly

Build giornaliera di FFmpeg (git master, variante **nonfree**, build statiche) basata su
[FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds):

| Target       | Output                                                   |
|--------------|----------------------------------------------------------|
| `linux64`    | `ffmpeg-nonfree-static_<ver>_amd64.deb` → repo APT       |
| `linuxarm64` | `ffmpeg-nonfree-static_<ver>_arm64.deb` → repo APT       |
| `win64`      | `ffmpeg-<data>-<ver>-win64-nonfree.zip` + `ffmpeg-latest-win64-nonfree.zip` |

> I binari nonfree **non sono ridistribuibili**. Il repo GitHub è pubblico solo per avere
> minuti Actions illimitati: i binari non vengono mai pubblicati su GitHub (artifact cifrati
> AES-256, retention 1 giorno) e finiscono solo sullo spazio web protetto da password.

## Flusso

```
base ──► build (linux64 | linuxarm64 | win64) ──► publish
 │         │ immagine target-base (GHCR, cache registry)
 │         │ immagine dipendenze <target>-nonfree (GHCR, cache registry)
 │         │ build ffmpeg ► .deb / .zip ► cifratura ► artifact
 │                                              │ decifratura
 │                                              │ apt-ftparchive + firma GPG
 └ immagine base + cache sorgenti                └ upload SFTP (lftp) + keepalive
```

Le immagini Docker su GHCR contengono solo le **dipendenze** (incluso fdk-aac come libreria),
non ffmpeg: ereditano la visibilità pubblica del repo e non consumano quota storage.

## Secrets (Settings → Secrets and variables → Actions)

| Secret              | Uso                                                        |
|---------------------|------------------------------------------------------------|
| `ARTIFACT_KEY`      | passphrase cifratura artifact tra i job (random, 48+ char) |
| `GPG_PRIVATE_KEY`   | chiave privata di firma, armored                           |
| `GPG_KEY_ID`        | fingerprint della chiave                                   |
| `GPG_PASSPHRASE`    | passphrase della chiave (vuoto se senza)                   |
| `SFTP_HOST`         | es. `ftp.clusterXXX.hosting.ovh.net`                       |
| `SFTP_PORT`         | default 22                                                 |
| `SFTP_USER`         | utente FTP/SFTP                                            |
| `SFTP_PASSWORD`     | password                                                   |
| `SFTP_KNOWN_HOSTS`  | output di `ssh-keyscan -p <porta> <host>`                  |
| `REMOTE_DIR`        | directory remota, es. `www/ffmpeg`                         |

I secret del job `publish` possono stare nell'environment `publish`
(Settings → Environments) per limitarne l'esposizione.

## Variables (opzionali)

| Variable          | Default        | Uso                                             |
|-------------------|----------------|-------------------------------------------------|
| `FFBUILDS_REF`    | `master`       | commit/branch FFmpeg-Builds (pin se upstream rompe) |
| `DEB_MAINTAINER`  | `ffmpeg-nightly <noreply@localhost>` | campo Maintainer del .deb |

## Layout remoto

```
<REMOTE_DIR>/apt/dists/ffmpeg/{InRelease,Release,Release.gpg,main/binary-{amd64,arm64}/Packages*}
<REMOTE_DIR>/apt/pool/main/f/ffmpeg-nonfree-static/*.deb
<REMOTE_DIR>/apt/ffmpeg-nightly-archive-keyring.gpg
<REMOTE_DIR>/win/ffmpeg-<YYYYMMDD>-<ver>-win64-nonfree.zip   (ultimi 7)
<REMOTE_DIR>/win/ffmpeg-latest-win64-nonfree.zip
```
