#!/bin/bash

SCRIPT_REPO="https://github.com/mpeg5/xeve.git"
SCRIPT_COMMIT="fe229fec19e14907c60d65626ebd59f41517d9b3" # v0.7.1

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
    # Senza tag git (clone a commit singolo) la versione viene letta da version.txt
    mkdir build-cmake && cd build-cmake

    cmake -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" ..
    make -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" make install

    # Il progetto installa sempre anche la libreria dinamica in lib/ e la statica
    # in lib/xeve/: teniamo solo la statica, in lib/, per un link statico certo.
    cd "$FFBUILD_DESTPREFIX"
    rm -f lib/libxeve.so* lib/libxeve.dll.a bin/libxeve.dll bin/xeve.dll
    mv lib/xeve/libxeve.a lib/
    rmdir lib/xeve 2>/dev/null || true
}

ffbuild_configure() {
    echo --enable-libxeve
}

ffbuild_unconfigure() {
    echo --disable-libxeve
}
