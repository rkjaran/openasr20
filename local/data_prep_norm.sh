#!/bin/bash
# RU 2020 MB

set -o errexit

function error_exit () {
  echo -e "$@" >&2; exit 1;
}

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <src-dir> <lang> <subset> <dst-dir>"
  echo "e.g.: $0 ../NIST_data openasr20_amharic build data/"
  exit 1
fi

src=$1
lang=$2
subset=$3
dst=$4

echo "Processing $src/$lang/$subset"

dst_sub=$dst/${lang}_${subset}
mkdir -p $dst/${lang}_${subset} || exit 1;
mkdir -p $dst/${lang}_${subset}/tmp || exit 1;
[ ! -d $src/$lang/$subset/audio ] && echo \
   "$0: no such directory $src/$lang/$subset" && exit 1;
[ ! -d $src/$lang/$subset/trans_stm ] && echo \
   "$0: no such directory $src/$lang/$subset/trans_stm. Run local/NIST_norm_trans.sh" && exit 1;

# Some prep
find $src/$lang/$subset/audio -type f | sort > $dst_sub/tmp/audio.lst
find $src/$lang/$subset/trans_stm -name "*.stm" | sort > $dst_sub/tmp/trans.lst

# wav.scp
while IFS= read -r file; do
   utt_id=$(echo $file | sed 's|\/.*\/||' | cut -d'_' -f4-7 | sed 's|\..*||')
   if [[ $file =~ ".sph" ]]; then
      echo "$utt_id sph2pipe -f rif -p $file |"
   elif [[ $file =~ ".wav" ]]; then
      echo "$utt_id sox $file -t wav -e signed-integer -r 8000 -b 16 - |"
   fi
done < $dst_sub/tmp/audio.lst > $dst_sub/wav.scp

# Text segments
while IFS= read -r file; do
   idx=0
   utt_id=$(echo $file | sed 's|\/.*\/||' | cut -d'_' -f4-7 | sed 's|\..*||')
   while IFS= read -r line; do
      seg_id=${utt_id}_$(printf "%03d" $idx)
      echo $line | grep -v "interSeg" | cut -d' ' -f4- | sed -e "s|\r||g" |  sed "s|^|$seg_id $utt_id |"
      let "idx+=1"
   done < $file
done < $dst_sub/tmp/trans.lst > $dst_sub/tmp/text_segments

# reco2file_and_channel
# We use A/B to mark channels, this is obsolete but validate_data_dir needs it
# We will change it back in local/split_ctm_per_utt.pl
cat $dst_sub/wav.scp | cut -d' ' -f1 > $dst_sub/tmp/reco.lst
while IFS= read -r file; do
   head -n 1 $file | cut -f1,2 | tr -s '\t' ' ' | sed -e "s|\r||g" | sed 's|1$|A|' | sed 's|2$|B|'
done < $dst_sub/tmp/trans.lst > $dst_sub/tmp/file_and_channel.lst

paste -d' ' $dst_sub/tmp/reco.lst $dst_sub/tmp/file_and_channel.lst > $dst_sub/reco2file_and_channel

# segments, text, utt2spk, spk2utt
cat $dst_sub/tmp/text_segments | cut -d' ' -f1-4 > $dst_sub/segments
cat $dst_sub/tmp/text_segments | cut -d' ' -f1,5- > $dst_sub/text
cat $dst_sub/tmp/text_segments | cut -d' ' -f1,2 > $dst_sub/utt2spk
utils/utt2spk_to_spk2utt.pl < $dst_sub/utt2spk > $dst_sub/spk2utt

utils/validate_data_dir.sh --no-feats $dst_sub || exit 1;
echo "$0: successfully prepared data in $dst_sub"
