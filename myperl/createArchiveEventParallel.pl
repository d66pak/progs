#!/home/y/bin/perl

use strict;
use warnings;
use Getopt::Long;
use DateTime;
use Sys::Hostname;
use File::Path;
use ForkManager;
use Data::Dumper;

use constant {

 NEWQPATH  => '/home/rocket/ms1/external/accessMail/free_archive_mig/new/',
 DESTFARM  => 1953,
 BATCHSIZE => 500,
};

my $help         = 0;
my @userList     = undef;
my $userListFile = undef;
my $pFH;
my $fFH;

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

  print $fFH "=$yid=ERROR=Cannot find farm and sid, event file not created!\n";
  return (undef);
 }

 unless ( isMboxOnThisFarm( $farm, $sid ) ) {

  print $fFH
    "=$yid=ERROR=Mbox not in this farm($farm), event file not created!\n";
  return (undef);
 }

 mkpath( NEWQPATH, 0, 0777 ) unless ( ( -e NEWQPATH ) and ( -d NEWQPATH ) );
 return (undef) unless ( ( -e NEWQPATH ) and ( -d NEWQPATH ) );

 my @digits = split( //, $sid );
 my $dir1   = $digits[-1] . $digits[-2];

 my $fullPath = NEWQPATH . $dir1;
 eval {
  mkpath( $fullPath, 0, 0777 )
    unless ( ( -e $fullPath ) and ( -d $fullPath ) );
 };
 print $fFH "=$yid=ERROR=$@" if $@;
 return (undef) unless ( ( -e $fullPath ) and ( -d $fullPath ) );

 $fullPath .= '/' . $sid;
 eval {
  mkpath( $fullPath, 0, 0777 )
    unless ( ( -e $fullPath ) and ( -d $fullPath ) );
 };
 print $fFH "=$yid=ERROR=$@" if $@;
 return (undef) unless ( ( -e $fullPath ) and ( -d $fullPath ) );

 return ("$fullPath/EVENT");
}

sub createEventFile {
 my ( $user, $oFH ) = @_;

 my @email = split( /@/, $user );

 my $yid = $email[0];

 my $eventPath = getEventFilePath($yid);
 unless ( defined $eventPath ) {

  return;
 }

 my $login = getLogin($yid);

 #print "=login=$login\n";
 unless ( defined $login ) {

  print $oFH "=$yid=ERROR=Cannot find login, event file not created!\n";
  return;
 }

 my $silo = getSilo($yid);

 #print "=silo=$silo\n";
 unless ( defined $silo ) {

  print $oFH "=$yid=ERROR=Cannot find silo, event file not created!\n";
  return;
 }

 my $fh;
 unless ( open( $fh, '>', $eventPath ) ) {

  print $oFH "=$yid=ERROR=Opening evnet file: $!\n";
  return;
 }

 my $stime   = time();
 my $content = join( "\n", $login, 'ms' . $silo, $stime );

 print $fh $content;
 close($fh);
 print $oFH "=$yid=path=$eventPath\n";
}

sub getBatchSizes {

 my ($inputFile) = @_;

 my $accounts = `wc -l < $inputFile`;
 print "accounts to process: $accounts\n";

 my @batchSizes;

 if ( $accounts <= 0 ) {

  push( @batchSizes, 0 );
  return @batchSizes;
 }

 my $bSize     = int( $accounts / BATCHSIZE );
 my $remainder = $accounts % BATCHSIZE;

 if ( $bSize == 0 ) {

  push( @batchSizes, $accounts );
  return @batchSizes;
 } else {

  for ( my $i = 0 ; $i < BATCHSIZE ; ++$i ) {

   my $size = $bSize;
   if ( $remainder > 0 ) {

    --$remainder;
    ++$size;
   }
   push( @batchSizes, $size );
  }
 }

 return @batchSizes;
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

 my @batchSizes = getBatchSizes($userListFile);
 my @batchFiles;
 my $BF = undef;

 for ( my $batchNo = 0 ; $batchNo < scalar(@batchSizes) ; ++$batchNo ) {

  my $counter = 0;

  # Create new batch file
  my $batchFilePath = '/tmp/createArchiveEventP-' . $$ . '-batch-' . $batchNo;
  push( @batchFiles, $batchFilePath );
  open( $BF, '>', $batchFilePath ) or die "Error opening $batchFilePath: $!";
  while ( defined ( my $user = <$iFH> ) && $counter < $batchSizes[$batchNo] ) {

   chomp($user);
   print $BF "$user\n";
   ++$counter;
  }
  close($BF);
 }
 close($iFH);

 # Distribute the work
 my $pm = Parallel::ForkManager->new(25);

 foreach my $batchFile (@batchFiles) {

  $pm->start() and next;    # do the fork

  # child process
  open( my $iBFH, '<', $batchFile )
    or die "ERROR Opening file: $batchFile : $!";

  my $outputFilePath = $batchFile . '.out';
  open( my $oBFH, '>', $outputFilePath )
    or die "ERROR Opening file: $outputFilePath : $!";

  while ( my $user = <$iBFH> ) {

   chomp($user);
   createEventFile( $user, $oBFH );
  }

  close($iBFH);
  close($oBFH);

  #delete input file
  unlink($batchFile);

  $pm->finish();    # do the exit in the child process
 }

 print "Waiting for Children...\n";
 $pm->wait_all_children;
 print "Everybody is out of the pool!\n";

 # Combine the batch output files
 my $passFileName = '/tmp/archive-event-pass-' . time();
 my $failFileName = '/tmp/archive-event-fail-' . time();

 open( $pFH, '>', $passFileName ) or die "Error opening $passFileName: $!";
 open( $fFH, '>', $failFileName ) or die "Error opening $failFileName: $!";

 foreach my $batchFile (@batchFiles) {

  my $FH;
  if ( !open( $FH, '<', $batchFile . '.out' ) ) {

   print "Error opening $batchFile: $!\n";
   next;
  }

  while ( my $line = <$FH> ) {

   chomp($line);
   if ( $line =~ m/=ERROR=/ ) {

    print $fFH "$line\n";
   } else {

    print $pFH "$line\n";
   }
  }
  close($FH);

  # delete the output file
  unlink( $batchFile . '.out' );
 }
 close($pFH);
 close($fFH);

 print "\nFiles created:\n$passFileName\n$failFileName\n";
} else {

 @userList = split( /,/, join( ',', @userList ) );
 foreach my $user (@userList) {

  chomp($user);
  createEventFile($user);
 }
}

