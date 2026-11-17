#!/bin/bash
# NDI: solo gli header dell'SDK (MIT, ridistribuibili per i progetti open source),
# presi dalla copia mantenuta da DistroAV (ex obs-ndi). Il runtime NDI NON viene
# linkato: il device libndi_newtek (packaging/ffpatch) lo carica a run time.
# Il device stesso viene reinserito nei sorgenti ffmpeg da packaging/ffpatch/apply.sh.

SCRIPT_REPO="https://github.com/DistroAV/DistroAV.git"
SCRIPT_COMMIT="fa41b38f18f07acc3c041e382e091a196fc12db0" # header NDI SDK 6.3

ffbuild_enabled() {
    [[ $VARIANT == nonfree* ]] || return -1
    return 0
}

ffbuild_dockerdl() {
    default_dl .
    echo "rm -rf .git"
}

ffbuild_dockerbuild() {
    mkdir -p "$FFBUILD_DESTPREFIX"/include
    cp lib/ndi/Processing.NDI.*.h "$FFBUILD_DESTPREFIX"/include/
}

ffbuild_configure() {
    echo --enable-libndi_newtek
}

ffbuild_unconfigure() {
    echo --disable-libndi_newtek
}
