#!/bin/bash

SCRIPT_REPO="https://github.com/alexmarsev/libbs2b.git"
SCRIPT_COMMIT="5ca2d59888df047f1e4b028e3a2fd5be8b5a7277" # 3.1.0 + fix upstream

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
    # libsndfile serve solo ai programmi bs2bconvert/bs2bstream: niente check e niente programmi
    sed -i '/^PKG_CHECK_EXISTS(\[sndfile\]/,/^\])/d' configure.ac
    sed -i '/^bin_PROGRAMS = /,/^$/d' src/Makefile.am

    autoreconf -fi

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --host="$FFBUILD_TOOLCHAIN"
        --disable-shared
        --enable-static
        --with-pic
    )

    ./configure "${myconf[@]}"
    make -j$(nproc)
    make install DESTDIR="$FFBUILD_DESTDIR"
}

ffbuild_configure() {
    echo --enable-libbs2b
}

ffbuild_unconfigure() {
    echo --disable-libbs2b
}
