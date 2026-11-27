#!/bin/bash
# rabbitmq-c: client AMQP 0-9-1 (protocollo amqp:// di ffmpeg). Senza SSL: il protocollo
# di ffmpeg usa solo socket TCP (amqp_tcp_socket_new), quindi OpenSSL non serve.

SCRIPT_REPO="https://github.com/alanxz/rabbitmq-c.git"
SCRIPT_COMMIT="dc22a7fa21522788310ec7f3f49bc3f028150b22" # v0.18.1

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
    mkdir build-cmake && cd build-cmake

    cmake -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -DINSTALL_STATIC_LIBS=ON \
        -DENABLE_SSL_SUPPORT=OFF -DBUILD_EXAMPLES=OFF -DBUILD_TOOLS=OFF \
        -DBUILD_API_DOCS=OFF -DBUILD_TESTING=OFF ..
    make -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" make install
}

ffbuild_cflags() {
    # amqp.h: su Windows senza AMQP_STATIC le API sono __declspec(dllimport)
    echo -DAMQP_STATIC
}

ffbuild_configure() {
    echo --enable-librabbitmq
}

ffbuild_unconfigure() {
    echo --disable-librabbitmq
}
