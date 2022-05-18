#!/bin/sh

set -x

USER=$(whoami)
STORE="s3://iog-clockworks-bitte/infra/binary-cache/?region=eu-central-1&profile=clockworks"
KEY="/run/keys/clockworks-nix-private"

HUB_CI="/home/runner"

if [ -f "$HUB_CI/.nix" ]; then
  NIX="$(cat $HUB_CI/.nix)"

  # only needed in CI
  export AWS_SHARED_CREDENTIALS_FILE="$HUB_CI/.awscreds"
  export TMPDIR="$HUB_CI/.logs"
  KEY="$HUB_CI/.nix-key"

  mkdir -p "$TMPDIR"
else
  NIX="nix"
fi

export NIX

[ "$DIRENV_IN_ENVRC" = 1 ] && exit
[ "$NO_CACHE_UPLOAD" = 1 ] && exit

# nix post-build-hook can't inherit env atm
[ -d "/$USER/.aws" ] ||
  [ -d "/home/$USER/.aws" ] ||
  [ -f "$HUB_CI/.awscreds" ] ||
  exit 0

set -eu
set -f # disable globbing
export IFS=' '

if [ -f $KEY ]; then
  if [ -n "$OUT_PATHS" ]; then
    export STORE KEY OUT_PATHS NIX
    setsid /bin/sh -c '
      printf "%s\n" "Uploading paths:" $OUT_PATHS

      "$NIX" store sign -r -k "$KEY" $OUT_PATHS

      ts="$NIX shell github:nixos/nixpkgs/nixos-unstable#taskspooler -c ts"
      cores="$($NIX shell github:nixos/nixpkgs/nixos-unstable#coreutils -c nproc)"

      $ts -S "$cores"
      $ts -- "$NIX" copy --to "$STORE" $OUT_PATHS
    ' &
  else
    # this can happen if we are just using `nix build --rebuild` to check a package
    echo "Nothing to upload"
  fi

else
  echo "No signing key"
fi
