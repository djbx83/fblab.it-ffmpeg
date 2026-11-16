#!/bin/bash

SCRIPT_REPO="https://github.com/dlbeer/quirc.git"
SCRIPT_COMMIT="542848dd6b9b0eaa9587bbf25b9bc67bd8a71fca" # v1.2

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
    # Makefile semplice: compiliamo solo gli oggetti della libreria. SDL_CFLAGS vuoto:
    # il Makefile lo riempie con l'output (anche d'errore) di pkg-config sdl.
    # L'archivio lo creiamo con l'ar del toolchain (il Makefile usa ar/ranlib host).
    local objs=(lib/decode.o lib/identify.o lib/quirc.o lib/version_db.o)
    make -j$(nproc) "${objs[@]}" CC="$CC" CFLAGS="$CFLAGS -Wall" SDL_CFLAGS= OPENCV_CFLAGS=
    "$AR" rcs libquirc.a "${objs[@]}"

    install -d "$FFBUILD_DESTPREFIX"/lib "$FFBUILD_DESTPREFIX"/include
    install -m 644 libquirc.a "$FFBUILD_DESTPREFIX"/lib/
    install -m 644 lib/quirc.h "$FFBUILD_DESTPREFIX"/include/
}

ffbuild_configure() {
    echo --enable-libquirc
}

ffbuild_unconfigure() {
    echo --disable-libquirc
}
