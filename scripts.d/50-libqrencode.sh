#!/bin/bash

SCRIPT_REPO="https://github.com/fukuchi/libqrencode.git"
SCRIPT_COMMIT="715e29fd4cd71b6e452ae0f4e36d917b43122ce8" # v4.1.1

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
    mkdir build-cmake && cd build-cmake

    cmake -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF -DWITH_TOOLS=OFF -DWITH_TESTS=OFF -DWITHOUT_PNG=ON ..
    make -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" make install
}

ffbuild_configure() {
    echo --enable-libqrencode
}

ffbuild_unconfigure() {
    echo --disable-libqrencode
}
