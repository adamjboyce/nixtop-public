#!/usr/bin/env bash
# Run this once on a fresh machine, after: git clone <url> ~/.nix
# It places mirrored external files back into their real homes and
# wires ~/.bashrc to source ~/.nix/nix-shell.sh if not already.
set -eu
NIX_ROOT="$HOME/.nix"
exec "$NIX_ROOT/bin/nix-git" pull --restore-only
