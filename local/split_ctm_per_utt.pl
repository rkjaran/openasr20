#!/usr/bin/env perl
# Copyright 2010-2011 Microsoft Corporation

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
# WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
# MERCHANTABLITY OR NON-INFRINGEMENT.
# See the Apache 2 License for the specific language governing permissions and
# limitations under the License.

# converts a master ctm file to many ctms based on spk_id
# Takes input from the stdin or from a file argument;
# output goes to the standard out.
# Usable specifically for OpenASR20 challenge, no modularity anywhere!

if ( @ARGV > 2 ) {
    die "Usage: split_ctm_per_utt.pl ctm outdir";
}

%map = ('A', 'inLine', 'B','outLine'); 

open(my $fh, '<:encoding(utf8)', $ARGV[0]) or die "Could not open file '$ctm' $!";
while ( <$fh> ) {
  @A = split(' ', $_);
  $fid = join '_', $A[0], $map{$A[1]};

  if( !$seen_file{$fid} ) {
     $seen_file{$fid} = 1;     
     push @filelist, $fid;
  }
  $_ =~ s/ A / 1 /;
  $_ =~ s/ B / 2 /;
  push (@{$file_hash{$fid}}, "$_");
}
close $fh;


foreach $f (@filelist) {
    $l = join('',@{$file_hash{$f}});
#    $l =~ s/A$/1/;
#    $l =~ s/B$/2/;
    open(my $fh, '>:encoding(utf8)', $ARGV[1].'/'.$f.'.ctm' ) or die $!;
       print $fh "$l";
    close $fh;
}
