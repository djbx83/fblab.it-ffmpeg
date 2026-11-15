#!/usr/bin/env python3
"""Retention del pool: per ogni (suite, pacchetto, architettura) tiene le
ultime KEEP versioni secondo l'ordinamento di dpkg e cancella le altre.

Uso: prune.py <pool_dir> <keep>
Layout atteso: <pool_dir>/<suite>/<component>/<prefix>/<package>/*.deb
"""
import functools
import pathlib
import subprocess
import sys
from collections import defaultdict


def field(deb: pathlib.Path, name: str) -> str:
    return subprocess.run(["dpkg-deb", "-f", str(deb), name],
                          check=True, capture_output=True, text=True).stdout.strip()


def vercmp(a: str, b: str) -> int:
    if a == b:
        return 0
    lt = subprocess.run(["dpkg", "--compare-versions", a, "lt", b]).returncode == 0
    return -1 if lt else 1


def main() -> int:
    pool = pathlib.Path(sys.argv[1])
    keep = int(sys.argv[2])
    groups = defaultdict(list)
    for deb in pool.glob("*/*/*/*/*.deb"):
        suite = deb.relative_to(pool).parts[0]
        key = (suite, field(deb, "Package"), field(deb, "Architecture"))
        groups[key].append((field(deb, "Version"), deb))

    for key, items in sorted(groups.items()):
        items.sort(key=functools.cmp_to_key(lambda x, y: vercmp(x[0], y[0])), reverse=True)
        for version, deb in items[keep:]:
            print(f"prune {key[0]}/{key[1]}/{key[2]} {version}: {deb.name}")
            deb.unlink()

    # directory vuote
    for d in sorted(pool.glob("**/"), key=lambda p: len(p.parts), reverse=True):
        if d != pool and d.is_dir() and not any(d.iterdir()):
            d.rmdir()
    return 0


if __name__ == "__main__":
    sys.exit(main())
