
#! /bin/bash

# Requires ctm generation and local/NIST_norm_trans.sh to be done
# Split best ctm, based on scoring/best_wer it into per-utterance *.ctm
# Verifies formatting against reference in NIST_data/$lang/{dev|eval}/transcription_norm
# We assume a Python has pandas and numpy installed
# Expected to be run from a directory with ./parse_options.sh
# We expect openasr_toolkit_v_0.1.1 folder is in PATH or in PWD

# Begin configuration section.
cmd=run.pl
# End configuration section.


echo "$0 $@"  # Print the command line for logging
[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;

if [ $# -ne 6 ] ; then
   echo "Usage: $0 [options] <data_dir> <lang_dir|graph_dir> <decode_dir> <NIST_dir> <lang> <subset>";
   echo "e.g.: $0 data/openasr20_amharic_dev data/lang_openasr20_amharic_2g exp/tri3/decode_2g_dev ../NIST_data openasr20_amhraic dev"
   exit 1;
fi

data_dir=$1
lang_dir=$2
decode_dir=$3
NIST_dir=$4
lang=$5
dset=$6

if [ ! -d $decode_dir/NIST ]; then
   mkdir -p $decode_dir/NIST
else
   rm $decode_dir/NIST/*
fi

echo "Preping $decode_dir for submission. Currently verified on dev set."

# Generate master ctm
lmwt=$(cat $decode_dir/scoring_kaldi/wer_details/lmwt)
steps/get_ctm.sh --cmd $cmd --use-segments true --min-lmwt $lmwt \
     --max-lmwt $lmwt $data_dir $lang_dir $decode_dir

# Split into per-utt ctm
local/split_ctm_per_utt.pl $decode_dir/score_$lmwt/${lang}_$dset.ctm $decode_dir/NIST

# Verify solution and createa *.tgz
python3 openasr_toolkit_v_0.1.1/OpenASR_validate_submission.py validate \
 -ref $NIST_dir/$lang/$dset/trans_stm/ -s $decode_dir/NIST \
 -l $(echo $lang | sed 's|*._||')

cd $decode_dir/NIST && tar -zcf $lang.tgz * || exit 1
mv $lang.tgz ../ || exit 1
echo "Success, a submission ready tarball created in $decode_dir/$lang.tgz"
