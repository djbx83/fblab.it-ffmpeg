#!/bin/bash

SCRIPT_REPO="https://github.com/TimothyGu/libilbc.git"
SCRIPT_COMMIT="cd064edf2c6c104a4e1fd87b34fd24cfa6dbe401" # v3.0.4

ffbuild_enabled() {
    return 0
}

ffbuild_dockerdl() {
    default_dl .
    echo "git submodule update --init --recursive --depth=1"
}

ffbuild_dockerbuild() {
    mkdir build && cd build

    cmake -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" -DBUILD_SHARED_LIBS=OFF ..
    make -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" cmake --install .
}

ffbuild_configure() {
    echo --enable-libilbc
}

ffbuild_unconfigure() {
    echo --disable-libilbc
}

ffbuild_cflags() {
    echo -DILBC_STATIC_DEFINE
}

ffbuild_libs() {
    # libilbc contiene codice C++ (rtc_base): il check di ffmpeg linka in C
    echo -lstdc++
}
