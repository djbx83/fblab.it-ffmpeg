#!/bin/bash
# flite (Festvox): sintesi vocale, filtro sorgente "flite" di libavfilter.
# Solo le librerie; installazione manuale di header e .a ("make install" installa anche
# i programmi e su Windows fallisce: cerca ../bin/flite senza .exe).

SCRIPT_REPO="https://github.com/festvox/flite.git"
SCRIPT_COMMIT="6c9f20dc915b17f5619340069889db0aa007fcdc" # v2.2 + fix 2022

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
    ./configure --prefix="$FFBUILD_PREFIX" --host="$FFBUILD_TOOLCHAIN" \
        --disable-shared --with-audio=none
    # HOST_ONLY_DIRS= : niente tools/ e main/ (programmi). In main/ flite_voice_list.c è
    # generato come effetto collaterale della regola di bin/flite ma compare anche come
    # prerequisito di "all": con make -j è una race ("No rule to make target flite_voice_list.c")
    make -j$(nproc) HOST_ONLY_DIRS=
    install -d "$FFBUILD_DESTPREFIX"/include/flite "$FFBUILD_DESTPREFIX"/lib
    install -m 644 include/*.h "$FFBUILD_DESTPREFIX"/include/flite/
    install -m 644 build/*/lib/libflite*.a "$FFBUILD_DESTPREFIX"/lib/
    # le librerie richieste da ffmpeg (flite_extralibs in configure)
    local l
    for l in flite_cmu_time_awb flite_cmu_us_awb flite_cmu_us_kal flite_cmu_us_kal16 \
             flite_cmu_us_rms flite_cmu_us_slt flite_usenglish flite_cmulex flite; do
        [[ -f "$FFBUILD_DESTPREFIX"/lib/lib$l.a ]] || { echo "ERRORE: lib$l.a mancante"; return 1; }
    done
}

ffbuild_configure() {
    echo --enable-libflite
}

ffbuild_unconfigure() {
    echo --disable-libflite
}
