#! /bin/sh

set -e

script_dir="$(cd "$(dirname "$0")" && echo "$(pwd -P)/")"
src_dir="${OPAMSWITCH_CREATE:-$(dirname "$script_dir")}"

. "$script_dir"/version.sh

if [ "$1" = "--dev" ]; then
    dev=yes
else
    dev=
fi

opam repository set-url tezos --dont-select $opam_repository || \
    opam repository add tezos --dont-select $opam_repository > /dev/null 2>&1

opam update --repositories --development

if [ ! -d "$src_dir/_opam" ] ; then
    opam switch create "$src_dir" --repositories=tezos ocaml-base-compiler.$ocaml_version
fi

if [ ! -d "$src_dir/_opam" ] ; then
    echo "Failed to create the opam switch"
    exit 1
fi

eval $(opam env --shell=sh --switch $src_dir --set-switch)

if [ -n "$dev" ]; then
    opam repository remove default > /dev/null 2>&1 || true
fi

if [ "$(ocaml -vnum)" != "$ocaml_version" ]; then
    opam install --unlock-base ocaml-base-compiler.$ocaml_version
fi

"$script_dir"/install_build_deps.raw.sh

if [ -n "$dev" ]; then
    opam repository add default --rank=-1 > /dev/null 2>&1 || true
    opam install merlin odoc bisect_ppx.1.4.2 --criteria="-changed,-removed"
fi
