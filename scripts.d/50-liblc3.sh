#!/bin/bash

SCRIPT_REPO="https://github.com/google/liblc3.git"
SCRIPT_COMMIT="96a3af0beb5487aca3b98a4b992a539a1f6d80d1" # v1.1.3

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
    mkdir build && cd build

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --buildtype=release
        --default-library=static
        --cross-file=/cross.meson
        -Dtools=false
        -Dpython=false
    )

    meson setup "${myconf[@]}" ..
    ninja -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja install
}

ffbuild_configure() {
    echo --enable-liblc3
}

ffbuild_unconfigure() {
    echo --disable-liblc3
}
