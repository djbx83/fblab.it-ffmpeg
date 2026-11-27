#!/bin/bash
# libcaca: output video in ASCII-art (device di uscita "caca"). Solo la libreria C, niente
# binding né X11/GL. Driver di visualizzazione: Linux ncursesw (compilata qui in statico,
# terminfo di sistema a run time), Windows console win32.

SCRIPT_REPO="https://github.com/cacalabs/libcaca.git"
SCRIPT_COMMIT="373c88b9890e67bde91e6acb8f1c442e847d1203" # v0.99.beta20

NCURSES_REPO="https://github.com/ThomasDickey/ncurses-snapshots.git"
NCURSES_COMMIT="e12a453fc23c5ac586d72af46465e8ba92adb707" # v6_5

ffbuild_enabled() {
    return 0
}

ffbuild_depends() {
    echo base
    echo zlib
}

ffbuild_dockerdl() {
    default_dl .
    echo "git-mini-clone \"$NCURSES_REPO\" \"$NCURSES_COMMIT\" ncurses"
}

ffbuild_dockerbuild() {
    local drivers=( --disable-win32 --disable-ncurses )

    if [[ $TARGET != win* ]]; then
        (
            cd ncurses
            ./configure --prefix="$FFBUILD_PREFIX" --host="$FFBUILD_TOOLCHAIN" \
                --without-shared --with-normal --enable-widec --enable-pc-files \
                --with-pkg-config-libdir="$FFBUILD_PREFIX"/lib/pkgconfig \
                --without-cxx --without-cxx-binding --without-ada --without-progs \
                --without-tests --without-manpages --without-debug --disable-db-install \
                --with-default-terminfo-dir=/usr/share/terminfo \
                --with-terminfo-dirs=/etc/terminfo:/lib/terminfo:/usr/share/terminfo
            make -j$(nproc)
            make install DESTDIR="$FFBUILD_DESTDIR"
            # anche nel prefisso, per il configure di libcaca qui sotto
            make install
        )
        drivers=( --disable-win32 --enable-ncurses )
    else
        drivers=( --enable-win32 --disable-ncurses )
    fi

    ./bootstrap

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --host="$FFBUILD_TOOLCHAIN"
        --disable-shared --enable-static --with-pic
        --disable-doc --disable-cxx --disable-java --disable-csharp
        --disable-python --disable-ruby --disable-cocoa --disable-x11
        --disable-gl --disable-network --disable-vga --disable-imlib2
        --disable-slang --disable-conio
        "${drivers[@]}"
    )

    ./configure "${myconf[@]}"
    # SUBDIRS= : niente test (caca/t), che su Windows non linkano con la libreria statica
    make -j$(nproc) -C caca SUBDIRS=
    make -C caca SUBDIRS= install DESTDIR="$FFBUILD_DESTDIR"
    install -Dm644 caca/caca.pc "$FFBUILD_DESTPREFIX"/lib/pkgconfig/caca.pc
    # caca.pc.in mette in Libs.private solo zlib, non le librerie dei driver (CACA_LIBS):
    # per il link statico di ffmpeg serve anche ncursesw
    if [[ $TARGET != win* ]]; then
        sed -i 's/^Libs.private:.*/& -lncursesw/' "$FFBUILD_DESTPREFIX"/lib/pkgconfig/caca.pc
        grep -q '^Libs.private:.*-lncursesw' "$FFBUILD_DESTPREFIX"/lib/pkgconfig/caca.pc
    fi
}

ffbuild_cflags() {
    # caca.h: su Windows senza CACA_STATIC le API sono __declspec(dllimport)
    echo -DCACA_STATIC
}

ffbuild_configure() {
    echo --enable-libcaca
}

ffbuild_unconfigure() {
    echo --disable-libcaca
}
