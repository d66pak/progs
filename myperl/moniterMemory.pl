#!/home/y/bin/perl

use strict;
use warnings;

my $fileName = 'memDump_' . $ARGV[0] . '.log';
open (my $FH, '>', $fileName) or die $!;
print "Memory dump save in: $fileName\n";

my $prevVir = 0;
my $prevRes = 0;
#### Check Memory Usage
while (1) {
## Get current memory from shell
  my @mem = `ps aux | grep \"$ARGV[0]\"`;
  my($results) = grep !/grep|$$/, @mem;

  unless (defined $results) {

    close ($FH);
    die "pid $ARGV[0] not found!\n";
  }

## Parse Data from Shell
  chomp $results;
  $results =~ s/^\w*\s*\d*\s*\d*\.\d*\s*\d*\.\d*\s*//g; $results =~ s/pts.*//g;
  my ($vsz,$rss) = split(/\s+/,$results);

  if ($prevVir != $vsz || $prevRes != $rss) {
    print $FH "Current Memory Usage: Virt: $vsz  RES: $rss\n";
    $prevVir = $vsz;
    $prevRes = $rss;
  }
  sleep(1);
}

