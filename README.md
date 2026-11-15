# fblab.it packages

Build giornaliera di FFmpeg (git master, variante **nonfree**, statica) e publisher
generico per `packages.fblab.it`.

## Layout di packages.fblab.it

```
/                         → 301 https://fblab.it/ (solo la root)
/free/deb/                archivio APT pubblico
/free/win64/<pkg>/        pacchetti Windows pubblici
/non-redistributable/     Basic Auth
    deb/                  archivio APT protetto (ffmpeg-nonfree-static, suite stable)
    win64/ffmpeg/         zip datati (ultimi 7) + ffmpeg-latest-win64-nonfree.zip
/incoming/                negato via HTTP, solo SFTP
```

Entrambi gli archivi sono firmati con la stessa chiave; la chiave pubblica è in
`<archivio>/deb/fblab-archive-keyring.gpg`.

## Pubblicare un pacchetto (da qualunque CI o a mano)

Caricare via SFTP in:

```
incoming/<free|non-redistributable>/deb/<suite>/*.deb
incoming/<free|non-redistributable>/win64/<pkg>/*
```

La suite viene creata se non esiste. Il workflow `packages-publish` controlla
`incoming/` ogni ora (o a mano via *Run workflow*), pubblica e svuota `incoming/`.
Vengono tenute le ultime `KEEP_VERSIONS` (default 3) versioni per suite/pacchetto/arch.

## Workflow

| Workflow | Trigger | Cosa fa |
|---|---|---|
| `nightly.yml` | 02:37 UTC, manuale | build ffmpeg linux64/linuxarm64/win64 → `publish.yml` |
| `publish.yml` | ogni ora, manuale, chiamato | incoming + artifact → archivi APT firmati + win64 |
| `site.yml` | manuale | `.htaccess` e `.htpasswd`; opzionale wipe del vecchio test |

## Secrets

| Secret | |
|---|---|
| `ARTIFACT_KEY` | cifratura artifact tra job |
| `GPG_PRIVATE_KEY`, `GPG_KEY_ID` | firma archivi (`GPG_PASSPHRASE` solo se la chiave ne ha una) |
| `SFTP_HOST`, `SFTP_PORT`, `SFTP_USER`, `SFTP_PASSWORD`, `SFTP_KNOWN_HOSTS` | accesso SFTP |
| `REMOTE_DIR` | document root di packages.fblab.it sull'SFTP (`fblab.it/packages`) |
| `HTPASSWD_USER`, `HTPASSWD_PASSWORD` | credenziali Basic Auth di `non-redistributable` (hash bcrypt generato dal workflow) |

## Variables

| Variable | |
|---|---|
| `HTPASSWD_REMOTE` | percorso SFTP del file htpasswd (`.htpasswd`, negato via HTTP dall'.htaccess di root) |
| `HTPASSWD_PATH` | percorso assoluto per `AuthUserFile` (`/home/golivec/fblab.it/packages/.htpasswd`) |
| `KEEP_VERSIONS` | versioni da tenere (default 3) |
| `FFBUILDS_REF` | commit/branch FFmpeg-Builds (default master) |
| `DEB_MAINTAINER` | campo Maintainer dei .deb |

## Client

```
deb [signed-by=/usr/share/keyrings/fblab-archive-keyring.gpg] https://packages.fblab.it/free/deb <suite> main
deb [signed-by=/usr/share/keyrings/fblab-archive-keyring.gpg] https://packages.fblab.it/non-redistributable/deb stable main
```
Credenziali per `non-redistributable` in `/etc/apt/auth.conf.d/fblab.conf`:
```
machine packages.fblab.it/non-redistributable login <utente> password <password>
```
