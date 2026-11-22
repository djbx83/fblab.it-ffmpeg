#!/bin/bash
# Fraunhofer MPEG-H 3D Audio decoder (licenza "Fraunhofer FDK MPEG-H Software", non libera).
# Solo il decoder: niente UI manager né demo (i demo scaricherebbero ilo/mmtisobmff via
# FetchContent durante la build). Il prefisso dei simboli (default ON) evita collisioni
# con libfdk-aac, linkata staticamente nello stesso binario.

SCRIPT_REPO="https://github.com/Fraunhofer-IIS/mpeghdec.git"
SCRIPT_COMMIT="4448b69738da2fa5f2f2f2b0ce29eea32509e046" # r4.0.1

ffbuild_enabled() {
    [[ $VARIANT == nonfree* ]] || return -1
    return 0
}

ffbuild_dockerbuild() {
    mkdir build-cmake && cd build-cmake

    cmake -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" -DBUILD_SHARED_LIBS=OFF \
        -Dmpeghdec_BUILD_DECODER=ON -Dmpeghdec_BUILD_UIMANAGER=OFF \
        -Dmpeghdec_BUILD_BINARIES=OFF -Dmpeghdec_BUILD_DOC=OFF \
        -Dmpeghdec_SYMBOL_PREFIX=ON \
        -DFETCHCONTENT_FULLY_DISCONNECTED=ON ..
    make -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" make install
}

ffbuild_cflags() {
    # mpeghexport.h: su Windows senza MPEGHDEC_STATIC dichiara le API __declspec(dllimport)
    # e il link con la libreria statica fallisce (__imp_mpeghdecoder_*); su Linux è ininfluente
    echo -DMPEGHDEC_STATIC
}

ffbuild_configure() {
    echo --enable-libmpeghdec
}

ffbuild_unconfigure() {
    echo --disable-libmpeghdec
}
