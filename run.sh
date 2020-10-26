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
prep_lang_opts=

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
  local/prep_lang.sh $prep_lang_opts $data $lang data/
fi

if [ $stage -le 3 ]; then
echo ============================================================================
echo "          Train mono system                                               "
echo ============================================================================

  steps/train_mono.sh --nj $nj --cmd "$train_cmd" \
                      data/${lang}_build data/lang_$lang exp/$lang/mono || exit 1
  utils/mkgraph.sh data/lang_${lang}_2g exp/$lang/mono \
                   exp/$lang/mono/graph_2g || exit 1

  for dset in build dev; do
    steps/decode.sh --nj $nj --cmd "$decode_cmd" \
                    exp/$lang/mono/graph_2g data/${lang}_$dset \
                    exp/$lang/mono/decode_2g_$dset &
  done
fi

if [ $stage -le 4 ]; then
  echo ============================================================================
  echo "          Train tri delta+deltadelta system                               "
  echo ============================================================================
  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
                    data/${lang}_build data/lang_$lang \
                    exp/$lang/mono exp/$lang/mono_ali || exit 1
  steps/train_deltas.sh --nj $nj --cmd "$train_cmd" \
                        2000 20000 \
                        data/${lang}_build data/lang_$lang \
                        exp/$lang/mono_ali exp/$lang/tri1 || exit 1
fi

if [ $stage -le 5 ]; then
  echo ============================================================================
  echo "          Train tri LDA+MLLT system                                       "
  echo ============================================================================
  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
                    data/${lang}_build data/lang_$lang \
                    exp/$lang/tri1 exp/$lang/tri1_ali || exit 1
  steps/train_lda_mllt.sh --nj $nj --cmd "$train_cmd" \
                          --splice-opts "--left-context=5 --right-context=5" \
                          4000 50000 \
                          data/${lang}_build data/lang_$lang \
                          exp/$lang/tri1_ali exp/$lang/tri2 || exit 1

  utils/mkgraph.sh data/lang_${lang}_2g exp/$lang/tri2 \
                   exp/$lang/tri2/graph_2g || exit 1

  for dset in dev; do
    steps/decode.sh --nj $nj --cmd "$decode_cmd" \
                    exp/$lang/tri2/graph_2g data/${lang}_$dset \
                    exp/$lang/tri2/decode_2g_$dset &
  done
fi

wait
