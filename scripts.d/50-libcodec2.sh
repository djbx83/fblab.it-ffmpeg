#!/bin/bash

SCRIPT_REPO="https://github.com/drowe67/codec2.git"
SCRIPT_COMMIT="06d4c11e699b0351765f10398abb4f663a984f36" # 1.2.0

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
    # In cross-compilazione codec2 compila generate_codebook nativo con un
    # ExternalProject che erediterebbe CC/CFLAGS del target: lo compiliamo
    # noi con il compilatore host e lo importiamo.
    env -u CC -u CFLAGS -u LDFLAGS -u CPPFLAGS gcc -O2 -o "$PWD/generate_codebook.host" src/generate_codebook.c -lm
    sed -i '/ExternalProject_Add(codec2_native/,/^    )/d' src/CMakeLists.txt
    sed -i '/add_dependencies(generate_codebook codec2_native)/d' src/CMakeLists.txt
    sed -i "s|IMPORTED_LOCATION \${CMAKE_CURRENT_BINARY_DIR}/generate_codebook|IMPORTED_LOCATION $PWD/generate_codebook.host|" src/CMakeLists.txt

    # Su Windows aggiunge uno script di packaging DLL (GetDependencies) che in
    # cross-compilazione fallisce: non serve per una libreria statica.
    sed -i '/install(SCRIPT ${CMAKE_BINARY_DIR}\/cmake\/GetDependencies.cmake)/d' CMakeLists.txt

    mkdir build && cd build

    cmake -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" -DBUILD_SHARED_LIBS=OFF \
        -DUNITTEST=OFF -DLPCNET=OFF ..
    make -j$(nproc) codec2
    DESTDIR="$FFBUILD_DESTDIR" cmake --install .
}

ffbuild_configure() {
    echo --enable-libcodec2
}

ffbuild_unconfigure() {
    echo --disable-libcodec2
}
