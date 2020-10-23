# you can change cmd.sh depending on what type of queue you are using.
# If you have no queueing system and want to run on a local machine, you
# can change all instances 'queue.pl' to run.pl (but be careful and run
# commands one by one: most recipes will exhaust the memory on your
# machine).  queue.pl works with GridEngine (qsub).  slurm.pl works
# with slurm.  Different queues are configured differently, with different
# queue names and different ways of specifying things like memory;
# to account for these differences you can create and edit the file
# conf/queue.conf to match your queue's configuration.  Search for
# conf/queue.conf in http://kaldi-asr.org/doc/queue.html for more information,
# or search for the string 'default_config' in utils/queue.pl or utils/slurm.pl.

# export train_cmd="queue.pl --mem 2G"
# export decode_cmd="queue.pl --mem 4G"
# export mkgraph_cmd="queue.pl --mem 8G"

conf_opts=""
if [[ $(hostname) == lr01* ]] || [[ $(hostname) == lr02* ]]; then
  export mfcc_cmd="utils/slurm.pl --nodelist lr02"
  conf_opts="--config conf/slurm_tiro.conf"
else
  export mfcc_cmd="utils/slurm.pl"
fi
export online_decode_cmd="utils/slurm.pl $conf_opts"
export train_cmd="utils/slurm.pl --mem 1G $conf_opts"
export decode_cmd="utils/slurm.pl --mem 2G  $conf_opts"
export mkgraph_cmd="utils/slurm.pl --mem 4G $conf_opts"
export big_memory_cmd="utils/slurm.pl --mem 8G $conf_opts"
export cuda_cmd="utils/slurm.pl --gpu 1 $conf_opts"
export tdnn_train_cmd="utils/slurm.pl $conf_opts"
export egs_cmd="utils/slurm.pl --max-jobs-run 5 $conf_opts"
