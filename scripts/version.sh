#! /bin/sh

## `ocaml-version` should be in sync with `README.rst` and
## `lib.protocol-compiler/tezos-protocol-compiler.opam`

ocaml_version=4.09.1
opam_version=2.0
recommended_rust_version=1.44.0

## Please update `.gitlab-ci.yml` accordingly
## full_opam_repository is a commit hash of the public OPAM repository, i.e.
## https://github.com/ocaml/opam-repository
full_opam_repository_tag=5491aa2960fd7b103b4461772b7badb475061d70

## opam_repository is an additional, tezos-specific opam repository.
opam_repository_tag=78061e8b32e3d7c814950b9fd61f7ce4da42da1b
opam_repository_url=https://gitlab.com/nomadic-labs/opam-repository.git
opam_repository=$opam_repository_url\#$opam_repository_tag

## Other variables, used both in Makefile and scripts
COVERAGE_OUTPUT=_coverage_output
