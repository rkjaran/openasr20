#!/bin/bash
# Init of a run script

if [[ $(hostname) == lr* ]]; then
  data=/export/lr01/lr-backup/corpora/openasr2020
else
  data=/home/staff/borsky/OpenASR2020/data
fi
work_dir=/home/staff/borsky/OpenASR2020/s5

lang="openasr20_amharic"
stage=0
nj=1

. ./cmd.sh
. ./path.sh
. parse_options.sh || exit 1;
set -e

echo ============================================================================
echo "                		Data Prep			                "
echo ============================================================================

if [ $stage -le 0 ]; then
   local/data_prep.sh $data $lang data/
   echo "Data prep done!"
fi

if [ $stage -le 1 ]; then
   for x in build dev; do
     steps/make_mfcc.sh --cmd "$train_cmd" --nj $nj data/${lang}_${x} exp/log/make_mfcc exp/mfcc || exit 1;
     steps/compute_cmvn_stats.sh data/${lang}_${x} exp/log/make_mfcc exp/mfcc || exit 1;
   done
fi

if [ $stage -le 2 ]; then
  local/prep_lang.sh $data $lang data/
fi

