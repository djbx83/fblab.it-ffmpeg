#!/bin/bash

SCRIPT_REPO="https://github.com/mpeg5/xevd.git"
SCRIPT_COMMIT="8fa744e865e9bdb94a5d5da6a4ab18268cdc4bb4" # v0.8.0

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
    # in lib/xevd/: teniamo solo la statica, in lib/, per un link statico certo.
    cd "$FFBUILD_DESTPREFIX"
    rm -f lib/libxevd.so* lib/libxevd.dll.a bin/libxevd.dll bin/xevd.dll
    mv lib/xevd/libxevd.a lib/
    rmdir lib/xevd 2>/dev/null || true
}

ffbuild_configure() {
    echo --enable-libxevd
}

ffbuild_unconfigure() {
    echo --disable-libxevd
}
