if [[ $(hostname) == lr01* ]] || [[ $(hostname) == lr02* ]]; then
  export KALDI_ROOT="/home/rkjaran/src/laeknaromur/x-romur/kaldi"
else
  export KALDI_ROOT="/opt/kaldi"
fi
. "$KALDI_ROOT/tools/config/common_path.sh"
. "$KALDI_ROOT/tools/env.sh"
export PATH=\
$KALDI_ROOT/tools/openfst/bin:\
$KALDI_ROOT/tools/pocolm/scripts:\
$PWD/utils:\
$PWD/steps:\
$KALDI_ROOT/tools/sph2pipe_v2.5:\
$PATH
if [[ $(hostname) == lr01* ]] || [[ $(hostname) == lr02* ]]; then
   export SCRATCH_ROOT=/export/lr02/fast/work/openasr20
else
   export SCRATCH_ROOT=/scratch/borsky/openasr20
export LC_ALL=C
