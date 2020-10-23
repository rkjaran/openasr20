#!/bin/bash
# RU 2020 MB

set -o errexit

function error_exit () {
  echo -e "$@" >&2; exit 1;
}

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <src-dir> <lang> <dst-dir>"
  echo "e.g.: $0 /home/staff/borsky/OpenASR2020/data openasr20_amharic data/"
  exit 1
fi

src=$1
lang=$2
dst=$3

function check_audio2trans {
   cat $1 | cut -d'_' -f5- | sed 's|\..*||' | cmp -s - <(cat $2 | cut -d'_' -f5- | sed 's|\..*||')
}

for subset in build dev; do
   echo "Processing $src/$lang/$subset"

   dst_sub=$dst/${lang}_${subset}
   mkdir -p $dst/${lang}_${subset} || exit 1;
   mkdir -p $dst/${lang}_${subset}/tmp || exit 1;
   [ ! -d $src/$lang/$subset ] && echo "$0: no such directory $src/$lang/$subset" && exit 1;

   # Some prep
   find $src/$lang/$subset/audio -type f | sort > $dst_sub/tmp/audio.lst
   find $src/$lang/$subset/transcription -type f | sort > $dst_sub/tmp/trans.lst

#   if ! check_audio2trans $dst_sub/tmp/audio.lst $dst_sub/tmp/trans.lst; then
#      echo "Error: $dst_sub/tmp/audio.lst do not match $dst_sub/tmp/trans.lst"
#      exit 1;
#   fi

   # wav.scp
   while IFS= read -r line; do
      utt=$(echo $line | cut -d'_' -f5- | sed 's|\..*||')
      if [[ $line =~ ".sph" ]]; then
         echo "$utt sph2pipe -f rif -p $line |"
      elif [[ $line =~ ".wav" ]]; then
         echo "$utt sox $line -t wav -e signed-integer -r 8000 -b 16 - |"
      fi
   done < $dst_sub/tmp/audio.lst > $dst_sub/wav.scp

   # Text segments
   while IFS= read -r file; do
      utt=$(echo $file | cut -d'_' -f5- | sed 's|\..*||')
      beg=$(head -n 1 $file | sed -e 's|\[\(.*\)\]|\1|')
      text="<no-speech>"
      idx=0
      while IFS= read -r line; do
         if [[ $line =~ "[" ]]; then
            end=$(echo $line| sed -e 's/\[\(.*\)\]/\1/')
            if  ! [[ $text == "<no-speech>" ]] && ! [[ $text == "(())" ]] ; then
                echo ${utt}_$(printf "%03d" $idx) $utt $beg $end $text
                let "idx+=1"
            fi
            beg=$end
         else
            text=$line
         fi
      done < $file
   done < $dst_sub/tmp/trans.lst > $dst_sub/tmp/text_segments

   # Segments, text, utt2spk, spk2utt
   cat $dst_sub/tmp/text_segments | cut -d' ' -f1-4 > $dst_sub/segments
   cat $dst_sub/tmp/text_segments | cut -d' ' -f1,5- > $dst_sub/text
   cat $dst_sub/tmp/text_segments | cut -d' ' -f1,2 > $dst_sub/utt2spk
   utils/utt2spk_to_spk2utt.pl < $dst_sub/utt2spk > $dst_sub/spk2utt

   utils/validate_data_dir.sh --no-feats $dst_sub || exit 1;
   echo "$0: successfully prepared data in $dst_sub"
done
