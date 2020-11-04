#! /bin/bash

# Normalize transcription using NIST script from openasr_toolkit_v_0.1.1
# Produced *.stm and *.ctm files, *.stm are for training and *.ctm for evaluation/submission
# We assume a Python has pandas and numpy installed
# We expect openasr_toolkit_v_0.1.1 folder is in PATH or in PWD
# Run this before local/data_prep_norm.sh
# Output goes into same NIST_data_dir/lang/subset/transcription_norm


echo "$0 $@"  # Print the command line for logging

if [ $# -ne 3 ] ; then
   echo "Usage: $0 <NIST_data_dir> <lang> <subset>";
   echo "e.g.: $0 ../NIST_data openasr20_amharic build"
   exit 1;
fi

srcdir=$1
lang=$2
subset=$3

if ! [ -d $srcdir/$lang/$subset/transcription ]; then
   echo "Error: Folder $srcdir/$lang/$subset/transcription not found"
   exit 1
fi
if ! [ -d $srcdir/$lang/$subset/trans_stm ]; then
   mkdir -p $srcdir/$lang/$subset/trans_stm
fi

for trans in $srcdir/$lang/$subset/transcription/*.txt; do
   python3 openasr_toolkit_v_0.1.1/scripts/OpenASR_convert_reference_transcript.py \
    -f $trans -o $srcdir/$lang/$subset/trans_stm
done

#for stm in $srcdir/$lang/$subset/trans_stm/*.stm; do
#   python3 openasr_toolkit_v_0.1.1/scripts/OpenASR_generate_ctm_file.py \
#     -f $stm -o $srcdir/$lang/$subset/trans_ctm
#done
