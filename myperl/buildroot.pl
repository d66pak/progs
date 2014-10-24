#!/usr/bin/perl

#buildroot.pl

use warnings;
use strict;

my $build_root = "build_root.txt";
my $modified_build_root = "modified_build_root.txt";

open(BR, $build_root) or die $!;
open(MBR, "> $modified_build_root") or die $!;

while (<BR>) {
  $_ =~ s/-([0-9a-zA-Z_]+(\.)?)+//g;
  print MBR "$_"; 
}

close BR;
close MBR;
