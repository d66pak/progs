#!/home/y/bin/perl

use strict;
use warnings;
use Getopt::Long;
use DateTime;
use Sys::Hostname;
use File::Path;
use File::Copy;

use constant {

 NEWQPATH   => '/home/rocket/ms1/external/accessMail/free_archive_mig/new/',
 DESTFARM   => 1953,
 CDONE      => 'CRAWL.DONE',
 CPROCESSED => 'CRAWL.DONE.PROCESSED',
 MDONE      => 'MIGRATION.DONE',
 MFAIL      => 'MIGRATION.FAILED',
 MPASS      => 'MIGRATION.PASS',
 MSTATS     => 'MIGRATION.STATS',
};

my $help         = 0;
my @userList     = undef;
my $userListFile = undef;
my $crawlDone    = undef;
my $migDone      = undef;
my $migFail      = undef;

sub usage {
 print "Usage: sudo $0 [-u emilid1,emailid2] [-f user-list-file-name]\n";
}

sub getLogin {
 my ($yid) = @_;

 my $cmd = "udb-test -Rk login $yid 2>&1";

 my $ret = qx/$cmd/;
 chop($ret);
 chop($ret);

 if ($?) {

  return undef;
 } else {

  if ( $ret =~ m/=login=(.*)/ ) {

   return $1;
  }
  return undef;
 }
}

sub getReg {
 my ($yid) = @_;

 my $cmd = "udb-test -Rk reg $yid 2>&1";

 my $ret = qx/$cmd/;
 chop($ret);
 chop($ret);

 if ($?) {

  return undef;
 } else {

  if ( $ret =~ m/=reg=(.*)/ ) {

   return $1;
  }
  return undef;
 }
}

sub getSilo {
 my $user = shift;

 my $silo = undef;

 my $cmd = "udb-test -Rk ym_mail_sh $user 2>&1";

 my $ret = qx/$cmd/;

 unless ($?) {

  if ( $ret =~ m/=ym_mail_sh=.*silo\cB(\d+)\cA/ ) {

   $silo = $1;
  }
 }

 return ($silo);
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
  return 1;
 }
 return 0;
}

sub getEventFilePath {
 my ($yid) = @_;

 my ( $farm, $sid ) = getFarmSid($yid);

 unless ( defined $farm && defined $sid ) {

  print "=$yid=ERROR=Cannot find farm and sid, event file not created!\n";
  return (undef);
 }

 unless ( isMboxOnThisFarm( $farm, $sid ) ) {

  print "=$yid=ERROR=Mbox not in this farm($farm), event file not created!\n";
  return (undef);
 }

 my @digits = split( //, $sid );
 my $dir1   = $digits[-1] . $digits[-2];

 my $fullPath = NEWQPATH . $dir1 . '/' . $sid;
 unless ( ( -e $fullPath ) and ( -d $fullPath ) ) {

  print "=$yid=ERROR=Path does not exists: $fullPath\n";
  return (undef);
 }

 return ($fullPath);
}

sub renameEventFiles {
 my ($user) = @_;

 my @email = split( /@/, $user );

 my $yid = $email[0];

 my $eventPath = getEventFilePath($yid);
 unless ( defined $eventPath ) {

  return;
 }

 my $time = time();

 my $crawlDonePath = $eventPath . '/' . CDONE;
 if ( -e $crawlDonePath ) {

  move( $crawlDonePath, $eventPath . '/C.D_' . $time );
 } else {

  my $crawlProcessedPath = $eventPath . '/' . CPROCESSED;
  if ( -e $crawlProcessedPath ) {

   move( $crawlProcessedPath, $eventPath . '/C.D.P_' . $time );
  } else {

   print "=$yid=ERROR=File not found: $crawlDonePath\n";
   print "=$yid=ERROR=File not found: $crawlProcessedPath\n";
  }
 }

 my $migDonePath = $eventPath . '/' . MDONE;
 if ( -e $migDonePath ) {

  move( $migDonePath, $eventPath . '/M.D_' . $time );
 } else {

  print "=$yid=ERROR=File not found: $migDonePath\n";
 }

 my $migFailPath = $eventPath . '/' . MFAIL;
 if ( -e $migFailPath ) {

  move( $migFailPath, $eventPath . '/M.F_' . $time );
 }
 
 my $migPassPath = $eventPath . '/' . MPASS;
 if ( -e $migPassPath ) {

  move( $migPassPath, $eventPath . '/M.P_' . $time );
 }
 
 my $migStatsPath = $eventPath . '/' . MSTATS;
 if ( -e $migStatsPath ) {

  move( $migStatsPath, $eventPath . '/M.S_' . $time );
 }

 print "=$yid=path=$eventPath\n";
}

########## MAIN ############
#
#

die usage() if ( scalar(@ARGV) < 2 );

GetOptions(
            'help'    => \$help,
            'cdone'   => \$crawlDone,
            'migdone' => \$migDone,
            'migfail' => \$migFail,
            'u:s'     => \@userList,
            'f:s'     => \$userListFile,
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

if ( defined $userListFile ) {

 open( my $iFH, '<', $userListFile )
   or die "ERROR Opening file: $userListFile : $!";

 while ( my $user = <$iFH> ) {

  chomp($user);
  renameEventFiles($user);
 }

 close($iFH);
} else {

 @userList = split( /,/, join( ',', @userList ) );
 foreach my $user (@userList) {

  next unless ( defined $user );
  chomp($user);
  renameEventFiles($user);
 }
}

