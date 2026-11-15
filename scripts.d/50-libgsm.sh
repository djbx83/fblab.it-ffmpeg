#!/bin/bash

# Nessun repository git upstream: tarball ufficiale (mirror Ubuntu, sha256 fisso)
GSM_URL="http://archive.ubuntu.com/ubuntu/pool/universe/libg/libgsm/libgsm_1.0.24.orig.tar.gz"
GSM_SHA256="a3c40c6471928383f4abfcb2e8f24012a1f562be2f17b8d672145d5986681a92"

ffbuild_enabled() {
    return 0
}

ffbuild_dockerdl() {
    echo "retry-tool sh -c \"curl -fsSL '$GSM_URL' -o /tmp/gsm.tgz\" && echo '$GSM_SHA256  /tmp/gsm.tgz' | sha256sum -c - && tar xzf /tmp/gsm.tgz --strip-components=1 && rm /tmp/gsm.tgz"
}

ffbuild_dockerbuild() {
    make -j$(nproc) lib/libgsm.a \
        CC="$CC" AR="$AR" RANLIB="$RANLIB" \
        CCFLAGS="-c $CFLAGS -DNeedFunctionPrototypes=1 -w"

    install -d "$FFBUILD_DESTPREFIX"/lib "$FFBUILD_DESTPREFIX"/include/gsm
    install -m 644 lib/libgsm.a "$FFBUILD_DESTPREFIX"/lib/
    install -m 644 inc/gsm.h "$FFBUILD_DESTPREFIX"/include/gsm/
}

ffbuild_configure() {
    echo --enable-libgsm
}

ffbuild_unconfigure() {
    echo --disable-libgsm
}
