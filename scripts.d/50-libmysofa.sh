#!/bin/bash

SCRIPT_REPO="https://github.com/hoene/libmysofa.git"
SCRIPT_COMMIT="6cc5b15a73e9bd97810d03767082edda7f315881" # v1.3.5

ffbuild_depends() {
    echo base
    echo zlib
}

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
    mkdir build-cmake && cd build-cmake

    cmake -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -DBUILD_TESTS=OFF ..
    make -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" make install
}

ffbuild_configure() {
    echo --enable-libmysofa
}

ffbuild_unconfigure() {
    echo --disable-libmysofa
}
