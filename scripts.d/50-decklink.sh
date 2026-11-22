#!/bin/bash
# Blackmagic DeckLink: solo gli header del Desktop Video SDK (licenza Blackmagic
# permissiva, stile Boost) dalla copia mantenuta in OBS Studio. Il driver
# Desktop Video viene caricato a run time (Linux: dlopen libDeckLinkAPI.so,
# Windows: COM), quindi ffmpeg non ha dipendenze di link dal driver.
# Windows: l'SDK fornisce solo gli .idl -> DeckLinkAPI.h / DeckLinkAPI_i.c generati
# con widl del toolchain; gli .idl di sistema (unknwn.idl...) vengono da mingw-w64,
# perché il toolchain crosstool-ng installa solo gli header .h.

SCRIPT_REPO="https://github.com/obsproject/obs-studio.git"
SCRIPT_COMMIT="7e3aa99811798255bd1a13a6da7260ada76a4d95" # DeckLink SDK 12.0

MINGW_REPO="https://github.com/mingw-w64/mingw-w64.git"
MINGW_COMMIT="9b3dd0125792fe94d16cacdc596dbd42fca1b369" # v14.0.0

ffbuild_enabled() {
    [[ $VARIANT == nonfree* ]] || return -1
    return 0
}

sparse_dl() {   # sparse_dl <repo> <commit> <dir> <pattern>...
    local repo="$1" commit="$2" dir="$3"; shift 3
    echo "git init -q $dir"
    echo "git -C $dir remote add origin '$repo'"
    echo "git -C $dir sparse-checkout set --no-cone $*"
    echo "retry-tool git -C $dir fetch -q --depth=1 --filter=blob:none origin '$commit'"
    echo "git -C $dir -c advice.detachedHead=false checkout -q FETCH_HEAD"
    echo "rm -rf $dir/.git"
}

ffbuild_dockerdl() {
    sparse_dl "$SCRIPT_REPO" "$SCRIPT_COMMIT" obs \
        "'plugins/decklink/linux/decklink-sdk/*'" "'plugins/decklink/win/decklink-sdk/*'"
    sparse_dl "$MINGW_REPO" "$MINGW_COMMIT" mingw "'mingw-w64-headers/include/*.idl'"
}

ffbuild_dockerbuild() {
    local inc="$FFBUILD_DESTPREFIX"/include
    mkdir -p "$inc"

    if [[ $TARGET == win* ]]; then
        local widl="${FFBUILD_CROSS_PREFIX}widl"
        command -v "$widl" || { echo "ERRORE: $widl non trovato nel toolchain"; return 1; }
        local idlinc="$PWD/mingw/mingw-w64-headers/include"
        [[ -f $idlinc/unknwn.idl ]] || { echo "ERRORE: unknwn.idl non trovato"; return 1; }

        cd obs/plugins/decklink/win/decklink-sdk
        "$widl" -I"$idlinc" -I. -h -o "$inc"/DeckLinkAPI.h DeckLinkAPI.idl
        "$widl" -I"$idlinc" -I. -u -o "$inc"/DeckLinkAPI_i.c DeckLinkAPI.idl
        cp DeckLinkAPIVersion.h "$inc"/
        grep -q CLSID_CDeckLinkIterator "$inc"/DeckLinkAPI_i.c
    else
        cp obs/plugins/decklink/linux/decklink-sdk/*.h \
           obs/plugins/decklink/linux/decklink-sdk/*.cpp "$inc"/
    fi
}

ffbuild_configure() {
    echo --enable-decklink
}

ffbuild_unconfigure() {
    echo --disable-decklink
}
