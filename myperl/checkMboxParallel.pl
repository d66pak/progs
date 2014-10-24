#!/home/y/bin/perl

use strict;
use warnings;
use DateTime;
use Getopt::Long;
use Sys::Hostname;
use ForkManager;
use ydbs;

use constant {

 SUCCESS             => 1,
 ERROR               => 0,
 HOSTANDFARMMISMATCH => -1,
 MBOXNOTFOUND        => -2,
 SIDKEYMISSING       => -3,
 DISANDDEL           => -4,
 DIS                 => -5,
 DEL                 => -6,
 SILOKEYMISSING      => -7,
 WRONGSILOKEY        => -8,
 UNKNOWN             => -100,
 UDBKEYS             => join( "\001", qw(sid ym_mail_sh) ),
};

my $help            = undef;
my @userList        = undef;
my $userListFile    = undef;
my $batchSize       = undef;
my $unlockMbox      = undef;
my $printsidsiloyid = undef;
my $skipFmbox       = undef;

sub usage {
 print
"Usage: sudo $0 [-u emilid1,emailid2] [-f user-list-file-name] [-batch number] [--unlock] [--skipfmbox]\n"
   . "--unlock : deletes YM_DO_NOT_REMOVE file from mailbox\n";
}

sub getDisDelKeys {

 my ($searchStr) = @_;

 my ( $dis, $del ) = ( 0, 0 );

 if ( $searchStr =~ m/del\cb1/ ) {

  $del = 1;
 }
 if ( $searchStr =~ m/dis\cb1/ ) {

  $dis = 1;
 }

 return ( $dis, $del );
}

sub getSilo {

 my ($searchStr) = @_;

 if ( $searchStr =~ m/silo\cb(\d+)/ ) {

  return $1;
 }
 return undef;
}

sub getFarmSidSilo {
 my ( $yid, $udbUser ) = @_;

 my @val  = split( /\cA/, $udbUser->get('sid') );
 my $farm = $val[0];
 my $sid  = $val[1];
 my $silo = undef;

 unless ( defined $sid && defined $farm ) {

  return ( $farm, $sid, $silo, SIDKEYMISSING );
 }

 my $ymMailSh = $udbUser->get('ym_mail_sh');

 # check if dis/del key is set
 my ( $dis, $del ) = getDisDelKeys($ymMailSh);

 if ( $del && $dis ) {

  return ( $farm, $sid, $silo, DISANDDEL );
 } elsif ($del) {

  return ( $farm, $sid, $silo, DEL );
 } elsif ($dis) {

  return ( $farm, $sid, $silo, DIS );
 }

 # At this point dis/del key is not set
 # Check if it has correct silo value
 $silo = getSilo($ymMailSh);
 unless ( defined $silo ) {

  return ( $farm, $sid, $silo, SILOKEYMISSING );
 }

 if ( $silo !~ m/$farm/ ) {

  return ( $farm, $sid, $silo, WRONGSILOKEY );
 }

 return ( $farm, $sid, $silo, SUCCESS );
}

sub currentHostNumber {

 my $host = hostname;

 if ( $host =~ m/web(\d+)\./ ) {

  return $1;
 } else {

  return undef;
 }
}

sub isMboxOnThisFarm {
 my ( $farm, $sid ) = @_;

 my $host = hostname;

 if ( $host =~ m/web$farm/ ) {

  if (defined $skipFmbox) {
   
   return SUCCESS;
  }
  
  my $cmd = "/home/y/bin/fmbox.sh $sid";
  my $ret = qx/$cmd/;
  chop($ret);

  if ($?) {

   return MBOXNOTFOUND;
  } else {

   if ( $ret =~ /account\s+not\s+found/ ) {

    return MBOXNOTFOUND;
   }
  }

  # Find mbox path
  if ( $ret =~ m/found\s+at\s+(\S+)/ ) {

   if ( defined $1 ) {

    my $ymdnrPath = $1 . '/' . 'YM_DO_NOT_REMOVE';
    if ( -e $ymdnrPath ) {

     if ( defined $unlockMbox ) {

      # Remove lock file
      unlink($ymdnrPath);

      #print "Deleting $ymdnrPath\n";
     }
    }
   }
  }
 } else {

  # current hostname and farm from udb key do not match
  return HOSTANDFARMMISMATCH;
 }

 return SUCCESS;
}

sub getUDBUser {

 my ($yid) = @_;

 my $u      = new ydbUser();
 my $acctid = new ydbsAccountID($yid);
 my $rc     = $u->open( $acctid, ydbUser::ro, UDBKEYS );
 if ( $rc != ydbReturn::UDB_SUCCESS ) {

  return ( undef, ydbEntity::getErrorString($rc) );
 }
 return ( $u, '' );
}

sub checkMbox {
 my ( $user, $FH ) = @_;

 #my @email = split( /@/, $user );

 #my $yid = $email[0];
 my $yid = $user;

 my ( $udbUser, $errMsg ) = getUDBUser($yid);

 unless ( defined $udbUser ) {

  print $FH "=$yid=ERROR=No UDB record exists $errMsg\n";
  return;
 }

 my ( $farm, $sid, $silo, $retval ) = getFarmSidSilo( $yid, $udbUser );

 if ( $retval == SIDKEYMISSING ) {
  print $FH "=$yid=ERROR=SID udb key missing, farm ($farm)\n";
 } elsif ( $retval == DISANDDEL ) {

  print $FH "=$yid=ERROR=MBox is disabled & deleted, farm ($farm)\n";
 } elsif ( $retval == DIS ) {

  print $FH "=$yid=ERROR=MBox disabled, farm ($farm)\n";
 } elsif ( $retval == DEL ) {

  print $FH "=$yid=ERROR=MBox deleted, farm ($farm)\n";
 } elsif ( $retval == SILOKEYMISSING ) {

  print $FH "=$yid=ERROR=SILO udb key missing, farm ($farm)\n";
 } elsif ( $retval == WRONGSILOKEY ) {

  print $FH "=$yid=ERROR=Wrong SILO udb key, farm ($farm)\n";
 } elsif ( $retval == UNKNOWN ) {

  print $FH "=$yid=ERROR=unknown error\n";
 } elsif ( defined $farm && defined $sid ) {

  my $ret = isMboxOnThisFarm( $farm, $sid );

  if ( $ret == SUCCESS ) {

   if ( defined $printsidsiloyid ) {

    print $FH "$sid:ms$silo:$yid\n";
   } else {

    print $FH "$yid\n";
   }
  } elsif ( $ret == HOSTANDFARMMISMATCH ) {

   print $FH "=$yid=ERROR=Mbox not in this farm ("
     . currentHostNumber()
     . ") but on farm ($farm)\n";

  } elsif ( $ret == MBOXNOTFOUND ) {

   print $FH "=$yid=ERROR=Mbox does not exist on this farm ("
     . currentHostNumber() . ")\n";
  }
 }
}

########## MAIN ############
#
#

die usage() if ( scalar(@ARGV) < 2 );

GetOptions(
            'help'        => \$help,
            'u:s'         => \@userList,
            'f:s'         => \$userListFile,
            'batch:i'     => \$batchSize,
            'unlock'      => \$unlockMbox,
            'crawlformat' => \$printsidsiloyid,
            'skipfmbox'   => \$skipFmbox,
  )
  or die usage();

if ( defined $help ) {

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

$batchSize = ( defined $batchSize ) ? $batchSize : 20;

if ( defined $userListFile ) {

 open( my $iFH, '<', $userListFile )
   or die "ERROR Opening file: $userListFile : $!";

 my @batchFiles;
 my $counter = 0;
 my $BF      = undef;

 while ( my $user = <$iFH> ) {

  if ( $counter % $batchSize == 0 ) {

   # Create new batch file
   my $batchFilePath = '/tmp/checkMbox-' . $$ . '-batch-' . $counter;
   push( @batchFiles, $batchFilePath );
   close($BF) if defined $BF;
   open( $BF, '>', $batchFilePath ) or die "Error opening $batchFilePath: $!";
  }

  chomp($user);
  print $BF "$user\n";
  ++$counter;
 }
 close($BF) if defined $BF;
 close($iFH);

 # Distribute the work
 my $pm = Parallel::ForkManager->new(1000);

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
   checkMbox( $user, $oBFH );
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
 my $passFileName = '/tmp/checkMbox-pass-' . time();
 my $failFileName = '/tmp/checkMbox-fail-' . time();

 open( my $pFH, '>', $passFileName ) or die "Error opening $passFileName: $!";
 open( my $fFH, '>', $failFileName ) or die "Error opening $failFileName: $!";

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
  checkMbox($user);
 }
}

