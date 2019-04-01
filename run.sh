#! /usr/bin/env bash
exec nix-shell -E "with import <nixpkgs> {}; callPackage ./learn-git.nix {}" -v
