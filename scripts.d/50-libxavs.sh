#!/bin/bash
# xavs: encoder AVS1 (GB/T 20090.2 "Jizhun"), derivato da x264 del 2009, fermo dal 2013.
# Mirror git del repository SVN di xavs.sourceforge.net. Senza asm: l'assembly x86 del 2009
# non è manutenuto e su aarch64 non esiste. Solo la libreria, niente CLI.

SCRIPT_REPO="https://github.com/Distrotech/xavs.git"
SCRIPT_COMMIT="8300fbf4918bca2af1af2aee6a337815e90b51e1"

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
    # codice C89/C99 vecchio: GCC 16 (C23) lo rifiuterebbe
    export CFLAGS="$CFLAGS -std=gnu17 -fcommon"

    # config.sub/config.guess del 2009 non conoscono aarch64: quelli di automake sì
    cp "$(automake --print-libdir)"/config.{sub,guess} .

    ./configure --host="$FFBUILD_TOOLCHAIN" --cross-prefix="$FFBUILD_CROSS_PREFIX" \
        --disable-asm --enable-pic --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS"
    make -j$(nproc) libxavs.a
    install -Dm644 libxavs.a "$FFBUILD_DESTPREFIX"/lib/libxavs.a
    install -Dm644 xavs.h "$FFBUILD_DESTPREFIX"/include/xavs.h
}

ffbuild_configure() {
    echo --enable-libxavs
}

ffbuild_unconfigure() {
    echo --disable-libxavs
}
