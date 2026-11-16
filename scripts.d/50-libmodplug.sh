#!/bin/bash

SCRIPT_REPO="https://github.com/Konstanty/libmodplug.git"
SCRIPT_COMMIT="a52647673746f5ba944bf3cc09be8ccb51cc9db5" # v0.8.9.2

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
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

ffbuild_cflags() {
    # su Windows modplug.h usa dllimport se non è definito MODPLUG_STATIC
    echo -DMODPLUG_STATIC
}

ffbuild_configure() {
    echo --enable-libmodplug
}

ffbuild_unconfigure() {
    echo --disable-libmodplug
}
