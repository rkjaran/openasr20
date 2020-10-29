#!/usr/bin/env bash
set -ue -o pipefail
help_message="Usage: $0

This script sets up symlinks to a scratch directories and common Kaldi scripts.
"

. ./path.sh

echo "Setting up symlinks" >&2

for l in utils steps; do
  if [ -e $l ]; then
    if [ -L $l ]; then
      echo "Location $l exists in working dir and is a symbolic link to $(readlink $l). " >&2
      echo "... assuming that's the correct directory."
    else
      echo "Location $l exists in working dir and is not a symbolic link." >&2
      exit 1
    fi
  else
    ln -s $KALDI_ROOT/egs/wsj/s5/steps steps
    ln -s $KALDI_ROOT/egs/wsj/s5/utils utils
  fi
done

for l in exp data; do
  if [ -e $l ]; then
    echo "Location $l exists in working dir. Move it or delete it." >&2
    exit 1
  fi
done

echo "Creating temporary scratch space"
scratch=$SCRATCH_ROOT/$(date +%s)
mkdir -p $scratch/{exp,data}

ln -s $scratch/exp exp
ln -s $scratch/data data

echo "Done"
exit 0
