#!/home/y/bin/perl

# USAGE: findFarms.pl <user-file-name>

use strict;
use warnings;

sub findSledFarm($)
{
  my $user = shift;

  my $cmd = "udb-test -Rk sid $user 2>&1";

  my $ret = qx/$cmd/;

  if ($?) {

    return undef;
  }
  else {

    if ($ret =~ /=sid=(\w{1,10})\ca(\w{1,32})/) {

      # print "$1 $2\n";
      return ($1, $2);
    }
    else {

      return undef;
    }
  }
  return undef;
}

sub createEventPath($)
{
  my ($sled) = @_;

  my @digits = split(//, $sled);
  
  my $eventPath = '/rocket/ms1/external/accessMail/sky_mig/new/' . $digits[-1] . $digits[-2] . '/' . $digits[-3] . $digits[-4] . '/' . $sled;

  return $eventPath;
}
############ MAIN ###############
#
open (my $hostFile, '<', 'sky-hosts') or die "$!";
my @hosts = <$hostFile>;
close ($hostFile);

if (open(my $userFile, "<", $ARGV[0])) {

  while (my $line = <$userFile>) {

    chomp($line);
    my ($farm, $sled) = findSledFarm($line);
    print "$line\t";
    if (defined $farm && defined $sled) {

      my @host = grep(/web$farm/, @hosts);
      if (defined $host[0]) {

        my $h = $host[0];
        chomp($h);
        print "$h\t";
      }

      print createEventPath($sled) . "\n";
    }
    else {

      print "undef\n";
    }
  }

  close($userFile);
}


