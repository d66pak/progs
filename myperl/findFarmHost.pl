#!/home/y/bin/perl

use strict;
use warnings;
use ydbs;

sub getUDBUser {

 my ($yid) = @_;

 my $u      = new ydbUser();
 my $acctid = new ydbsAccountID($yid);
 my $rc = $u->open( $acctid, ydbUser::ro, join( "\001", qw(ym sid aliases) ) );
 if ( $rc != ydbReturn::UDB_SUCCESS ) {

  return ( undef, ydbEntity::getErrorString($rc) );
 }
 return ( $u, '' );
}

sub getFarmSid {
 my ( $yid, $udbUser ) = @_;

 my @val  = split( /\cA/, $udbUser->get('sid') );
 my $farm = $val[0];
 my $sid  = $val[1];

 return ( $farm, $sid );
}

sub findHost {
 my ($farm) = @_;
 chomp($farm);

 my $cmd = "host f$farm.mail.yahoo.com 2>&1";
 my $ret = qx/$cmd/;
 chop($ret);
 chop($ret);

 if ($?) {

  return ( 0, "Host for f$farm not found" );
 } else {

  if ( $ret =~ m/.+\.vip\.(.+)\.yahoo\.com.*/ ) {

   return ( 1, "web$farm" . "06.mail.$1.yahoo.com" );
  } else {

   return ( 0, "Host for f$farm not found" );
  }
 }
}

######### MAIN ###########

die "findFarmHost.pl <yid-file>" if ( scalar @ARGV < 1 );

while ( my $yid = <> ) {

 chomp($yid);

 my $newYid = undef;

 my ( $udbUser, $errMsg ) = getUDBUser($yid);

 unless ( defined $udbUser ) {

  # check if yid is email address
  # if yes then remove @ and try again

  if ( $yid =~ m/@/ ) {

   my @email = split( /@/, $yid );
   $newYid = $email[0];

   ( $udbUser, $errMsg ) = getUDBUser($newYid);
   unless ( defined $udbUser ) {

    print "$yid\tERROR:Farm/Sid not found $errMsg\n";
    $udbUser = undef;
    next;
   }
  }
 }

 if ( defined $newYid ) {

  # match the ym of newYid to the old one to check if its the same user
  my $ym = $udbUser->get('ym');
  if ( $ym ne $yid ) {

   print "$yid\tERROR:Farm/Sid not found $ym != $yid\n";
   $udbUser = undef;
   next;
  }
 } else {

  # new yid is not required, make it same as yid
  $newYid = $yid;
 }

 # build list of aliases
 my $aliases = $udbUser->get('aliases');
 my @list = split( /\cD/, $aliases );
 my @aliasList;
 foreach my $als (@list) {

  if ( $als =~ m/#index/ ) {

   # ignore
   next;
  }

  my @tempList = split( /\cC/, $als );
  push( @aliasList, $tempList[0] );
 }

 # check if yid is all numbers
 if ( $newYid !~ m/\D/ ) {

  # replace yid with aliase
  $newYid = $aliasList[0];
 }

 print "$newYid\t";
 my @val  = split( /\cA/, $udbUser->get('sid') );
 my $farm = $val[0];
 my $sid  = $val[1];
 unless ( defined $farm && defined $sid ) {

  print "ERROR:Farm/Sid not found\n";
  $udbUser = undef;
  next;
 }

 my ( $ret, $host ) = findHost($farm);
 if ($ret) {

  print "$host\n";
 } else {

  print "ERROR:$host\n";
 }
}
