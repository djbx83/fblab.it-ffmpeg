#!/bin/bash

SCRIPT_REPO="https://github.com/mstorsjo/vo-amrwbenc.git"
SCRIPT_COMMIT="080af7540562e4adfbd3312837fe5fc6771c4cd0" # v0.1.3

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
        --disable-example
    )

    ./configure "${myconf[@]}"
    make -j$(nproc)
    make install DESTDIR="$FFBUILD_DESTDIR"
}

ffbuild_configure() {
    echo --enable-libvo-amrwbenc
}

ffbuild_unconfigure() {
    echo --disable-libvo-amrwbenc
}
