#!/usr/bin/env bash
set -eu -o pipefail

use_roman=false
stage=0

help_message="Usage $0 <corpus-dir> <lang> <dst-dir>
e.g. $0 /export/lr01/lr-backup/corpora/openasr2020 openasr20_amharic data/

Options:
        --use-roman <bool|$use_roman>  # Set to true to use the romanized lexicon
"
. ./path.sh
. utils/parse_options.sh

function message() {
  echo >&2
  echo $@ >&2
  echo >&2
}

if [ $# -ne 3 ]; then
  echo "Wrong #args (excepted 3, got $#)" >&2
  echo "$help_message" >&2
  exit 1
fi

corpus=$1
lang=$2
dst=$3

additonal_opts=
if $use_roman; then
  additonal_opts="$additonal_opts --use-roman"
fi

if [ $stage -le 0 ]; then
  message "Preparing langdir for $lang in $dst"
  local/prep_lang.py --corpus-dir $corpus --lang $lang --dst $dst $additonal_opts
fi

if [ $stage -le 1 ]; then
  message "Building bigram from transcripts for $lang"
  mkdir -p data/local/lm_$lang
  cut -d' ' -f2- $dst/${lang}_build/text \
    | lmplz -o2 | gzip -c > data/local/lm_$lang/build_2g.gz

  utils/format_lm.sh $dst/lang_${lang} \
                     data/local/lm_$lang/build_2g.gz \
                     $dst/local/dict_$lang/lexicon.txt \
                     $dst/lang_${lang}_2g
fi
