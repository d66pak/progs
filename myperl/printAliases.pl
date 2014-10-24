#!/home/y/bin/perl

use strict;
use warnings;

sub usage {
 print "Usage: $0 user-list-file-name\n";
}

sub printAlias {
 my ($yid) = @_;

 my $cmd = "udb-test -Rk aliases $yid 2>&1";

 my $ret = qx/$cmd/;
 chop($ret);
 chop($ret);

 my $alias = "";
 unless ($?) {
  
  if ( $ret =~ m/=aliases=.*?\cD(.*?)\cC/ ) {
   
   $alias  = $1;
  }  
 }
 print "=$yid=alias=" . ($alias eq "") ? $yid : $alias . "=\n";
}

########## MAIN ############
#
#
while ( my $user = <> ) {

 chomp($user);
 printAlias($user);
}