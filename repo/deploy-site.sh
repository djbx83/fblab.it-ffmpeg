#!/usr/bin/env bash
# Pubblica la configurazione Apache (.htaccess) e il file .htpasswd.
#
# Uso: deploy-site.sh
#
# Variabili (oltre a quelle di repo/lib.sh):
#   HTPASSWD_USER / HTPASSWD_PASSWORD  credenziali Basic Auth (hash bcrypt
#                     generato qui con htpasswd -B), oppure
#   HTPASSWD          contenuto già pronto del file htpasswd (righe user:hash)
#   HTPASSWD_REMOTE   percorso SFTP dove salvarlo, FUORI dalla document root
#                     (es. .htpasswd-packages nella home)
#   HTPASSWD_PATH     percorso ASSOLUTO dello stesso file sul filesystem del
#                     server, usato da Apache in AuthUserFile
#                     (es. /homez.123/utente/.htpasswd-packages)
#   WIPE_LEGACY       se "yes" cancella deb/ keys/ repo/ del primo test
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=repo/lib.sh
source "$HERE/lib.sh"
SITE="$HERE/../site"

: "${HTPASSWD_REMOTE:?}" "${HTPASSWD_PATH:?}"
if [[ -z "${HTPASSWD:-}" ]]; then
    : "${HTPASSWD_USER:?HTPASSWD o HTPASSWD_USER/HTPASSWD_PASSWORD richiesti}" "${HTPASSWD_PASSWORD:?}"
    HTPASSWD="$(htpasswd -nbBC 12 "$HTPASSWD_USER" "$HTPASSWD_PASSWORD" | sed '/^$/d')"
fi

sftp_setup
R="$REMOTE_DIR"

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
printf '%s\n' "$HTPASSWD" > "$TMP/htpasswd"
sed "s|__HTPASSWD_PATH__|$HTPASSWD_PATH|" "$SITE/htaccess.non-redistributable" > "$TMP/htaccess.nr"

cmds=""
if [[ "${WIPE_LEGACY:-}" == "yes" ]]; then
    cmds+=" rm -r -f $R/deb; rm -r -f $R/keys; rm -r -f $R/repo;"
fi
# prima la protezione, poi tutto il resto
cmds+=" put $TMP/htpasswd -o $HTPASSWD_REMOTE;
        mkdir -p -f $R/non-redistributable $R/incoming/free $R/incoming/non-redistributable $R/free;
        put $TMP/htaccess.nr -o $R/non-redistributable/.htaccess;
        put $SITE/htaccess.incoming -o $R/incoming/.htaccess;
        put $SITE/htaccess.root -o $R/.htaccess;"
lf "$cmds"
echo "Configurazione sito pubblicata."
