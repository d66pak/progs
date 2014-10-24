#!/home/y/bin/perl

use strict;
use warnings;
use Getopt::Long;
use DateTime;
use Sys::Hostname;
use File::Path;

use constant {

 NEWQPATH => '/home/rocket/ms1/external/accessMail/free_mig/new/',
 DESTFARM => 1953,
 PARTNER  => 'free',
 TYPE     => 'none',
};

my $help         = 0;
my @userList     = undef;
my $userListFile = undef;

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

 mkpath( NEWQPATH, 0, 0777 ) unless ( ( -e NEWQPATH ) and ( -d NEWQPATH ) );
 return (undef) unless ( ( -e NEWQPATH ) and ( -d NEWQPATH ) );

 my @digits = split( //, $sid );
 my $dir1   = $digits[-1] . $digits[-2];

 my $fullPath = NEWQPATH . $dir1;
 mkpath( $fullPath, 0, 0777 ) unless ( ( -e $fullPath ) and ( -d $fullPath ) );
 return (undef) unless ( ( -e $fullPath ) and ( -d $fullPath ) );

 return ("$fullPath/$sid");
}

sub createEventFile {
 my ($user) = @_;

 my @email = split( /@/, $user );

 my $yid = $email[0];

 my $eventPath = getEventFilePath($yid);
 unless ( defined $eventPath ) {

  return;
 }

 my $login = getLogin($yid);

 #print "=login=$login\n";
 unless ( defined $login ) {

  print "=$yid=ERROR=Cannot find login, event file not created!\n";
  return;
 }

 my $reg = getReg($yid);

 #print "=reg=$reg\n";
 unless ( defined $reg ) {

  print "=$yid=ERROR=Cannot find reg, event file not created!\n";
  return;
 }

 my $fh;
 unless ( open( $fh, '>', $eventPath ) ) {

  print "=$yid=ERROR=Opening evnet file: $!\n";
  return;
 }

 my $stime   = time();
 my $content =
   join( "\cA", $login, $reg, $user, DESTFARM, PARTNER, TYPE, $stime );

 print $fh $content;
 close($fh);
 print "=$yid=path=$eventPath\n";
}

########## MAIN ############
#
#

die usage() if ( scalar(@ARGV) < 2 );

GetOptions(
            'help' => \$help,
            'u:s'  => \@userList,
            'f:s'  => \$userListFile,
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
  createEventFile($user);
 }

 close($iFH);
} else {

 @userList = split( /,/, join( ',', @userList ) );
 foreach my $user (@userList) {

  chomp($user);
  createEventFile($user);
 }
}

