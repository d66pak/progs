#!/home/y/bin/perl

use strict;
use warnings;
use ForkManager;

print "hello fork!\n";

my $pm = Parallel::ForkManager->new(30);

  foreach my $linkarray (1..4) {
    $pm->start and next; # do the fork


    print "executing process...\n";
    $pm->finish; # do the exit in the child process
  }
$pm->wait_all_children;
