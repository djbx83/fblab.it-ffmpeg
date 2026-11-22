#!/bin/bash
# libklvanc (Kernel Labs): VANC SMPTE (SCTE-104, EIA-708, AFD, timecode...) per l'uscita decklink.

SCRIPT_REPO="https://github.com/stoth68000/libklvanc.git"
SCRIPT_COMMIT="d6915e37067ef9680ef27bb8c12cb6bd743471d2"

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
    # tools/ e samples/ non servono (e non sono portabili su Windows): solo la libreria
    sed -i 's/^SUBDIRS = src tools$/SUBDIRS = src/' Makefile.am
    grep -qx 'SUBDIRS = src' Makefile.am

    # <sys/errno.h> non esiste in mingw-w64; <errno.h> è lo standard ed equivalente su glibc
    grep -rl '<sys/errno.h>' src | xargs sed -i 's|<sys/errno.h>|<errno.h>|'
    ! grep -rq '<sys/errno.h>' src

    autoreconf -fi

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --host="$FFBUILD_TOOLCHAIN"
        --disable-shared
        --enable-static
        --with-pic
    )

    ./configure "${myconf[@]}"
    make -j$(nproc)
    make install DESTDIR="$FFBUILD_DESTDIR"
}

ffbuild_libs() {
    # libklvanc usa pthread_mutex_*: il test di link di configure ("require ... -lklvanc")
    # su win64 (winpthreads statico) fallisce senza -lpthread; su glibc è innocuo
    echo -lpthread
}

ffbuild_configure() {
    echo --enable-libklvanc
}

ffbuild_unconfigure() {
    echo --disable-libklvanc
}
