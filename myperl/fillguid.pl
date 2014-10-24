#!/home/y/bin/perl

use strict;
use warnings;

# findGuid() #
##############

sub findGuid($)
{
  my $user = shift;

  my $cmd = "udb-test -Rk mbr_guid $user";

  my $ret = qx/$cmd/;

  if ($?) {

    return undef;
  }
  else {

    if ($ret =~ /GUID\cb(\w{1,32})/) {

      return $1;
    }
    else {

      return undef;
    }
  }
  return undef;
}

if (open(my $userFile, "<", $ARGV[0])) {

  # Try opening output file
  my $op;
  unless (open($op, ">", "ulist.guid")) {

   die "Error! not able to open ulist.guid\n";
  }

  while (my $line = <$userFile>) {

    chomp($line);
    my $guid = findGuid($line);
    if (defined $guid) {

      print $op "$line $guid\n";
    }
    else {

      print $op "$line No GUID found\n"
    }
  }

  close($op);
  close($userFile);
}


