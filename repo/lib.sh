# shellcheck shell=bash
# Funzioni comuni SFTP (lftp). Da includere con: source repo/lib.sh
#
# Variabili richieste:
#   SFTP_HOST SFTP_USER SFTP_PASSWORD SFTP_KNOWN_HOSTS REMOTE_DIR
# Opzionali:
#   SFTP_PORT (default 22)

sftp_setup() {
    : "${SFTP_HOST:?}" "${SFTP_USER:?}" "${SFTP_PASSWORD:?}" "${SFTP_KNOWN_HOSTS:?}" "${REMOTE_DIR:?}"
    SFTP_PORT="${SFTP_PORT:-22}"
    REMOTE_DIR="${REMOTE_DIR%/}"
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    printf '%s\n' "$SFTP_KNOWN_HOSTS" > "$HOME/.ssh/known_hosts"
    chmod 600 "$HOME/.ssh/known_hosts"
    export LFTP_PASSWORD="$SFTP_PASSWORD"
    LFTP_PRE="set cmd:fail-exit yes; set net:max-retries 3; set net:reconnect-interval-base 10;
set sftp:connect-program 'ssh -a -x -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$HOME/.ssh/known_hosts';
open --env-password -u '$SFTP_USER' sftp://$SFTP_HOST:$SFTP_PORT;"
}

# Esegue una sequenza di comandi lftp in un'unica sessione
lf() {
    lftp -c "$LFTP_PRE $*"
}

# Come lf ma non fallisce (per listing di directory che potrebbero non esistere)
lf_try() {
    lftp -c "set cmd:fail-exit no; $LFTP_PRE $*" 2>/dev/null || true
}
