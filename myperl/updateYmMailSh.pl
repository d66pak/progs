#!/home/y/bin/perl

use strict;
use warnings;
use Getopt::Long;
use DateTime;
use Sys::Hostname;
use File::Path;
use ForkManager;
use Data::Dumper;
use ydbs;
use ymailext;
use Config::General;
use Time::HiRes qw(gettimeofday tv_interval);

use constant {

 BATCHFILE  => 'ymMailShUpdate-',
 PASSFILE   => 'ymMailShUpdateSuccess',
 FAILFILE   => 'ymMailShUpdateFail',
 IGNOREFILE => 'ymMailShUpdateIgnored',
 UDBKEYS    => join( "\001", qw(ym ym_mail_sh ym_mail_hist) ),
 NOFP       => 5,
 MAXP       => 100,
};

my $help              = 0;
my $userListFile      = undef;
my $configFile        = undef;
my $numberOfProcesses = undef;
my $dryrun            = undef;
my %CONFIG;

sub usage {
 print <<"USAGE";
Usage
    $0 -f <file>
                          -conf <file>
                         [-nop <number>]
                         [--dryrun]
                         [--help]

-f
    User list filename

-conf
    Apache style config file with key = value pairs

-nop
    Number of sub-processes to spawn

--dryrun
    Do not modify any keys

--help
    To display this message

USAGE
}

sub getUDBUser {

 my ($yid) = @_;

 my $u      = new ydbUser();
 my $acctid = new ydbsAccountID($yid);
 my $rc     = $u->open( $acctid, ydbUser::ex, UDBKEYS );
 if ( $rc != ydbReturn::UDB_SUCCESS ) {

  return ( undef, ydbEntity::getErrorString($rc) );
 }
 return ( $u, '' );
}

sub getKey {

 my ( $udbUserRef, $key ) = @_;

 return $$udbUserRef->get($key);
}

sub setKey {

 my ( $udbUserRef, $key, $newKeyVal ) = @_;

 if ( $key eq 'ym_mail_hist' && $newKeyVal ne '' ) {

  my $oldValue = getKey( $udbUserRef, 'ym_mail_hist' );
  $newKeyVal = time() . "\002" . $newKeyVal . "\001" . $oldValue;
 }
 $$udbUserRef->set( $key, $newKeyVal );

 #print "$newKeyVal\n";
}

sub processRequest {
 my ( $yid, $oFH ) = @_;

 my $t0     = [gettimeofday];
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

    print $oFH "=$yid=ERROR=UDB open failed: $errMsg="
      . tv_interval($t0) . "\n";
    return;
   }
  }
 }

 if ( defined $newYid ) {

  # match the ym of newYid to the old one to check if its the same user
  my $ym = getKey( \$udbUser, 'ym' );
  if ( $ym ne $yid && $ym ne '' ) {

   print $oFH "=$yid=ERROR=Different UDB users $ym ne $yid="
     . tv_interval($t0) . "\n";
   return;
  }
 } else {

  # new yid is not required, make it same as yid
  $newYid = $yid;
 }

 # UDB is opened for the user

 # Go over the config values to be set
 foreach my $mainKey ( keys %CONFIG ) {

  my $mainValue = $CONFIG{$mainKey};
  if ( ref($mainValue) eq 'HASH' ) {

   my $yext = tie my %udbMainKey, 'ymailext', $udbUser, $mainKey;
   unless ( defined $yext ) {

   }

   foreach my $subKey ( keys %$mainValue ) {

    $udbMainKey{$subKey} = $mainValue->{$subKey};
    $yext->saveTo($udbUser);
   }
   #print Dumper( \%udbMainKey ) . "\n";
  } else {

   setKey( \$udbUser, $mainKey, $mainValue );
  }
 }

 if ( defined $dryrun ) {

  print $oFH "=$yid=DRYRUN==" . tv_interval($t0) . "\n";
 } else {

  $udbUser->save();
  print $oFH "=$yid=PASS=" . tv_interval($t0) . "\n";
 }
 $udbUser = undef;
}

sub getBatchSizes {

 my ($inputFile) = @_;

 my $accounts = `wc -l < $inputFile`;
 chomp($accounts);
 $accounts =~ s/^\s+//g;
 $accounts =~ s/\s+$//g;
 print "accounts to process: $accounts\n";

 my @batchSizes;

 if ( $accounts <= 0 ) {

  push( @batchSizes, 0 );
  return @batchSizes;
 }

 my $bSize            = int( $accounts / $numberOfProcesses );
 my $remainder        = $accounts % $numberOfProcesses;
 my $verificationSize = 0;

 for ( my $i = 0 ; $i < $numberOfProcesses ; ++$i ) {

  my $size = $bSize;
  if ( $remainder > 0 ) {

   --$remainder;
   ++$size;
  }
  push( @batchSizes, $size );
  $verificationSize += $size;
  last if ( $verificationSize == $accounts );
 }

 # verify if the batch sizes are correctly found
 unless ( $verificationSize == $accounts ) {

  die "Batch sizes were wrongly calculated: " . Dumper( \@batchSizes );
 }

 return @batchSizes;
}

sub checkCommandLineArgs {

 unless (    defined $numberOfProcesses
          && $numberOfProcesses < MAXP
          && $numberOfProcesses > 0 )
 {

  $numberOfProcesses = NOFP;
 }

}
########## MAIN ############
#
#
my $argc = scalar(@ARGV);

GetOptions(
            'f=s'    => \$userListFile,
            'conf=s' => \$configFile,
            'nop:i'  => \$numberOfProcesses,
            'help'   => \$help,
            'dryrun' => \$dryrun,
  )
  or die usage();

if ($help) {

 usage();
 exit;
}

die usage() if ( $argc < 4 );

my $t0 = [gettimeofday];

# check the correctness of arguments
checkCommandLineArgs();

# Open user list file
open( my $iFH, '<', $userListFile )
  or die "ERROR Opening file: $userListFile : $!";

# Read the config file
my $conf = Config::General->new($configFile);
unless ( defined $conf ) {

 die "ERROR reading config file: $configFile\n";
}
%CONFIG = $conf->getall;
#print Dumper( \%CONFIG ) . "\n";

my @batchSizes = getBatchSizes($userListFile);
my @batchFiles;

for ( my $batchNo = 0 ; $batchNo < scalar(@batchSizes) ; ++$batchNo ) {

 my $currentBSize = $batchSizes[$batchNo];
 if ( $currentBSize <= 0 ) {

  print "Zero batch size found!\n";
  next;
 }

 # Create new batch file
 my $counter       = 0;
 my $batchFilePath = BATCHFILE . $$ . '-batch-' . $batchNo;
 push( @batchFiles, $batchFilePath );
 open( my $BF, '>', $batchFilePath )
   or die "Error opening $batchFilePath: $!";

 while ( $counter < $batchSizes[$batchNo] && defined( my $user = <$iFH> ) ) {

  chomp($user);
  print $BF "$user\n";
  ++$counter;
 }
 close($BF);
}
close($iFH);

# Distribute the work
my $pm = Parallel::ForkManager->new(MAXP);

# Setup a callback for when a child finishes up so we can
# get it's exit code
$pm->run_on_finish(
 sub {
  my ( $pid, $exit_code, $ident ) = @_;
  print "** $ident completed by process "
    . "with PID $pid and exit code: $exit_code\n";
 }
);

foreach my $batchFile (@batchFiles) {

 $pm->start($batchFile) and next;    # do the fork

 # child process
 open( my $iBFH, '<', $batchFile )
   or die "ERROR Opening file: $batchFile : $!";

 my $outputFilePath = $batchFile . '.out';
 open( my $oBFH, '>', $outputFilePath )
   or die "ERROR Opening file: $outputFilePath : $!";

 while ( my $user = <$iBFH> ) {

  chomp($user);
  processRequest( $user, $oBFH );
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
my $passFileName   = PASSFILE . '-' . time();
my $failFileName   = FAILFILE . '-' . time();
my $ignoreFileName = IGNOREFILE . '-' . time();

open( my $pFH, '>', $passFileName ) or die "Error opening $passFileName: $!";
open( my $fFH, '>', $failFileName ) or die "Error opening $failFileName: $!";
open( my $igFH, '>', $ignoreFileName )
  or die "Error opening $ignoreFileName: $!";

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
  } elsif ( $line =~ m/=IGNORED=/ ) {

   print $igFH "$line\n";
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
close($igFH);

print "\nFiles created:\n$passFileName\n$failFileName\n$ignoreFileName\n";
print "Total process took " . tv_interval($t0) . " secs!\n";

