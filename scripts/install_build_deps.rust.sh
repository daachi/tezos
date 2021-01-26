#!/usr/bin/env bash

set -e

script_dir="$(cd "$(dirname "$0")" && pwd -P)"

#shellcheck source=version.sh
. "$script_dir"/version.sh

# This script verifies a Rust system with the correct version is setup on the
# machine. It assumes that cargo is installed in the system, use your package
# manager or https://rustup.rs by specifying the env var RUST_VERSION the user
# can decide to use a different version of rust (recommended_rust_version is a
# variable declared in scripts/version.sh)
rust_version=${RUST_VERSION:-$recommended_rust_version}

if [ "$recommended_rust_version" != "$rust_version" ]; then
  echo "\
WARNING: you selected a different version of rust. Tezos is tested only
with Rust $recommended_rust_version. Do this at your own peril."
  sleep 3
fi

if [ ! -x "$(command -v rustup)" ] && \
   [[ ! -x "$(command -v rustc)" || ! -x "$(command -v cargo)" ]]; then
    echo "The Rust compiler is not installed. Please install Rust $recommended_rust_version."
    echo "See instructions at: https://tezos.gitlab.io/introduction/howtoget.html#environment"
    exit 1
fi

if ! [[ "$(rustc --version | cut -d' ' -f2)" == *"$rust_version"* ]]; then
    echo "\
Wrong Rust version, run the following commands in your favorite shell:
$ rustup toolchain install $rust_version
$ rustup override set $rust_version
or force it by setting the variable RUST_VERSION to your installed version
if you know what you are doing"
    exit 1
fi
