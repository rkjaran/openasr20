#!/bin/bash
# Init of a run script

echo "$0 $@" >&2

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
use_pitch=true
do_decode=false

tdnn_stage=0

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
  make_mfcc_cmd=steps/make_mfcc.sh
  if $use_pitch; then
    make_mfcc_cmd=steps/make_mfcc_pitch.sh
  fi
  for x in build dev; do
    $make_mfcc_cmd --cmd "$train_cmd" --nj $nj data/${lang}_${x} exp/log/make_mfcc exp/mfcc || exit 1;
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
  if $do_decode; then
    utils/mkgraph.sh data/lang_${lang}_2g exp/$lang/mono \
                     exp/$lang/mono/graph_2g || exit 1

    for dset in dev; do
      steps/decode.sh --nj $nj --cmd "$decode_cmd" \
                      exp/$lang/mono/graph_2g data/${lang}_$dset \
                      exp/$lang/mono/decode_2g_$dset &
    done
  fi
fi

if [ $stage -le 4 ]; then
  echo ============================================================================
  echo "          Train tri delta+deltadelta system                               "
  echo ============================================================================
  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
                    data/${lang}_build data/lang_$lang \
                    exp/$lang/mono exp/$lang/mono_ali || exit 1
  steps/train_deltas.sh --cmd "$train_cmd" \
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
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
                          --splice-opts "--left-context=5 --right-context=5" \
                          4000 50000 \
                          data/${lang}_build data/lang_$lang \
                          exp/$lang/tri1_ali exp/$lang/tri2 || exit 1

  if $do_decode; then
    utils/mkgraph.sh data/lang_${lang}_2g exp/$lang/tri2 \
                     exp/$lang/tri2/graph_2g || exit 1

    for dset in dev; do
      steps/decode.sh --nj $nj --cmd "$decode_cmd" \
                    exp/$lang/tri2/graph_2g data/${lang}_$dset \
                    exp/$lang/tri2/decode_2g_$dset &
    done
  fi
fi

if [ $stage -le 6 ]; then
  echo ============================================================================
  echo "          Train tri3 LDA+MLLT+SAT system                                  "
  echo ============================================================================
  steps/align_fmllr.sh --cmd "$train_cmd" --nj $nj \
                       data/${lang}_build data/lang_$lang \
                       exp/$lang/tri2 exp/$lang/tri2_ali || exit 1;
  steps/train_sat.sh --cmd "$train_cmd" \
                     7000 90000 \
                     data/${lang}_build data/lang_$lang exp/$lang/tri2_ali \
                     exp/$lang/tri3 || exit 1;

  if $do_decode; then
    (
      utils/mkgraph.sh data/lang_${lang}_2g exp/$lang/tri3 \
                       exp/$lang/tri3/graph_2g || exit 1
      for dset in dev; do
        steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" \
                              exp/$lang/tri3/graph_2g data/${lang}_$dset \
                              exp/$lang/tri3/decode_2g_$dset || exit 1
      done
    ) &
  fi
fi

if [ $stage -le 7 ]; then
  # TODO(rkjaran): multilang egs
  nnet3_affix=$lang
  gmm=$lang/tri3
  train_set=${lang}_build
  test_sets=${lang}_dev
  langs="default"
  num_threads_ubm=32
  src_langdir=data/lang_$lang

  if [[ $(hostname) == lr0* ]]; then
    num_threads_ubm=4
  fi

  local/chain2/run_tdnn.sh \
    --stage $tdnn_stage \
    --nnet3-affix $nnet3_affix \
    --gmm $gmm \
    --train-set $train_set \
    --test-sets "$test_sets" \
    --langs "$langs" \
    --num-threads-ubm $num_threads_ubm \
    --use-pitch $use_pitch \
    --src-langdir $src_langdir || exit 1
fi

wait
