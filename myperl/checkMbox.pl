#!/home/y/bin/perl

use strict;
use warnings;
use DateTime;
use Getopt::Long;
use Sys::Hostname;

my $help         = 0;
my @userList     = undef;
my $userListFile = undef;
my $pFH;
my $fFH;
my $progressCount = 1;
my $unlockMbox    = 0;

sub usage {
 print
   "Usage: sudo $0 [-u emilid1,emailid2] [-f user-list-file-name] [--unlock]\n";
}

sub getFarmSid {
 my ($yid) = @_;

 my $cmd = "udb-test -Rk sid $yid 2>&1";

 my $ret = qx/$cmd/;
 chop($ret);
 chop($ret);

 if ($?) {

  return ( undef, undef );
 } else {

  if ( $ret =~ m/=sid=(\w{1,10})\ca(\w{1,32})/ ) {

   return ( $1, $2 );
  }
  return ( undef, undef );
 }
}

sub isMboxOnThisFarm {
 my ( $farm, $sid ) = @_;

 my $host = hostname;

 if ( $host =~ m/web$farm/ ) {

  my $cmd = "/home/y/bin/fmbox.sh $sid";
  my $ret = qx/$cmd/;
  chop($ret);

  if ($?) {

   return 0;
  } else {

   if ( $ret =~ /account\s+not\s+found/ ) {

    return 0;
   }
  }

  # Find mbox path
  if ( $ret =~ m/found\s+at\s+(\S+)/ ) {

   if ( defined $1 ) {

    my $ymdnrPath = $1 . '/' . 'YM_DO_NOT_REMOVE';
    if ( -e $ymdnrPath ) {

     if ($unlockMbox) {

      # Remove lock file
      unlink($ymdnrPath);
      #print "Deleting $ymdnrPath\n";
     }
    }
   }
  }
  return 1;
 }
 return 0;
}

sub checkMbox {
 my ($user) = @_;

 my @email = split( /@/, $user );

 my $yid = $email[0];

 my ( $farm, $sid ) = getFarmSid($yid);

 if ( defined $farm && defined $sid ) {

  if ( isMboxOnThisFarm( $farm, $sid ) ) {

   print $pFH "$yid\n";
  } else {

   print $fFH "=$yid=ERROR=Mbox not in this farm($farm)\n";
  }
 } else {

  print $fFH "=$yid=ERROR=Cannot find farm and sid\n";
 }

 ++$progressCount;
 if ( $progressCount % 50 ) {

  print STDERR ".";
 } else {

  print STDERR "$progressCount\n.";
 }
}

########## MAIN ############
#
#

die usage() if ( scalar(@ARGV) < 2 );

GetOptions(
            'help'   => \$help,
            'u:s'    => \@userList,
            'f:s'    => \$userListFile,
            'unlock' => \$unlockMbox,
  )
  or die usage();

if ($help) {

 usage();
 exit;
}

# Change the effective UID to nobody2
$> = 60001;

if ($!) {

 print "Unable to change the user ID to nobody2 .. Aborting ...\n";
 print "Details of errors: $!\n";
 die;
}

my $passFileName = '/tmp/pass-' . time();
my $failFileName = '/tmp/fail-' . time();

open( $pFH, '>', $passFileName ) or die "Error opening $passFileName: $!";
open( $fFH, '>', $failFileName ) or die "Error opening $failFileName: $!";

if ( defined $userListFile ) {

 open( my $iFH, '<', $userListFile )
   or die "ERROR Opening file: $userListFile : $!";

 while ( my $user = <$iFH> ) {

  chomp($user);
  checkMbox($user);
 }

 close($iFH);
} else {

 @userList = split( /,/, join( ',', @userList ) );
 foreach my $user (@userList) {

  chomp($user);
  checkMbox($user);
 }
}

close($pFH);
close($fFH);

print "\nFiles created:\n$passFileName\n$failFileName\n";
