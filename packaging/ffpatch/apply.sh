#!/usr/bin/env bash
# Patch dei sorgenti ffmpeg (eseguito da build.sh di FFmpeg-Builds dentro il container,
# nella directory dei sorgenti ffmpeg, subito dopo il clone e prima di ./configure).
#
# NDI (libndi_newtek): device rimosso da FFmpeg nel 2019, reinserito qui con
# caricamento dinamico del runtime (nessuna dipendenza di link da libndi).
# Ogni inserimento cerca un'ancora che deve esistere una sola volta: se master
# cambia e l'ancora sparisce, la build si ferma qui con un errore esplicito.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { echo "ffpatch: $*" >&2; exit 1; }

# insert_after <file> <regex-ancora> <testo>   (testo su una o più righe)
insert_after() {
    local file="$1" anchor="$2" text="$3" n
    n="$(grep -cE -- "$anchor" "$file" || true)"
    [[ "$n" == 1 ]] || die "$file: ancora '$anchor' trovata $n volte (attesa 1)"
    ANCHOR="$anchor" TEXT="$text" awk '
        { print }
        !done && $0 ~ ENVIRON["ANCHOR"] { print ENVIRON["TEXT"]; done = 1 }
    ' "$file" > "$file.ffpatch" && mv "$file.ffpatch" "$file"
}

[[ -f configure && -f libavdevice/alldevices.c ]] || die "non sono nella directory dei sorgenti ffmpeg"

if grep -q 'libndi_newtek' configure; then
    die "configure contiene già libndi_newtek: patch già applicata o NDI tornato upstream, verificare"
fi

# --- NDI ---------------------------------------------------------------------
cp "$HERE"/ndi/libndi_newtek_common.h \
   "$HERE"/ndi/libndi_newtek_common.c \
   "$HERE"/ndi/libndi_newtek_dec.c \
   "$HERE"/ndi/libndi_newtek_enc.c \
   libavdevice/

insert_after configure '^  --enable-decklink ' \
'  --enable-libndi_newtek   enable NewTek NDI I/O support (runtime loaded dynamically) [no]'

insert_after configure '^EXTERNAL_LIBRARY_NONFREE_LIST="$' \
'    libndi_newtek'

insert_after configure '^decklink_outdev_extralibs=' \
'libndi_newtek_deps_any="libdl LoadLibrary"
libndi_newtek_indev_deps="libndi_newtek"
libndi_newtek_outdev_deps="libndi_newtek"'

insert_after configure '^enabled frei0r ' \
'enabled libndi_newtek     && require_headers Processing.NDI.Lib.h'

chmod +x configure   # awk + mv ricrea il file senza bit di esecuzione

insert_after libavdevice/Makefile '^OBJS-\$\(CONFIG_DECKLINK_INDEV\) ' \
'OBJS-$(CONFIG_LIBNDI_NEWTEK_OUTDEV)      += libndi_newtek_enc.o libndi_newtek_common.o
OBJS-$(CONFIG_LIBNDI_NEWTEK_INDEV)       += libndi_newtek_dec.o libndi_newtek_common.o'

insert_after libavdevice/Makefile '^SKIPHEADERS +\+= decklink_common\.h$' \
'SKIPHEADERS-$(CONFIG_LIBNDI_NEWTEK)      += libndi_newtek_common.h'

insert_after libavdevice/alldevices.c '^extern const FFOutputFormat ff_decklink_muxer;' \
'extern const FFInputFormat  ff_libndi_newtek_demuxer;
extern const FFOutputFormat ff_libndi_newtek_muxer;'

echo "ffpatch: NDI (libndi_newtek) applicato"
