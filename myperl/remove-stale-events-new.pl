#!/home/y/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Time::HiRes qw(gettimeofday tv_interval);

use constant
{
  RESULTFILE => 'remove-stale-events-' . time(),
  CMDFILE => 'remove-stale-events-command-' . time(),
  BASEQPATH => '/rocket/ms1/external/accessMail/sky_mig/',
  BASEMBOXPATH => '/rocket/ms',
  IR2 => '.mail.ir2.yahoo.com',
  BF1 => '.mail.bf1.yahoo.com',
  DELFILE01 => 'norebuild.20131231',
  DELFILE02 => 'YM_DO_NOT_REMOVE',
  SUCCESS => 1,
  FAIL => 0,
  SSH_FAIL => -1,
  NOT_FOUND => -2,
};

my $IPFILENAME;
my $IPFH;
my $OPFH;
my $CMDFH;
my $HOST;
my $CLEANCOUNT = 0;

sub usage
{
  print "Usage: yinst-pw sudo $0 -f <analyze-events-op-file> -h <host-name>\n";
}

sub cleanupUser
{
  my ($sid, $silo, $eventPath) = @_;

  # Remove event files
  my $cmd = 'yinst ssh -h ' . $HOST . ' "sudo rm ' . $eventPath;

  # Remove lock files from mbox
  my @d = split(//, $sid);
  my $mboxPath = BASEMBOXPATH . $silo . '/' . $d[-1] . $d[-2] . '/' . $d[-3] . $d[-4] . '/' . $sid . '/';

  $cmd .= ';sudo rm ' . $mboxPath . DELFILE01 .';sudo rm ' . $mboxPath . DELFILE02 . '"';

  return "$cmd\n";
}

sub moveEvent 
{
  my ($oldEventPath, $newEventPath, $hostname) = @_;

  # Remove event files
  my $cmd = 'yinst ssh -h ' . $hostname . ' "sudo -u nobody2 mv ' . $oldEventPath . ' ' . $newEventPath . '"';

  return "$cmd\n";
}

sub removeEventOnHost
{
  my ($eventPath, $hostname) = @_;

  # Remove event file
  my $cmd = 'yinst ssh -h ' . $hostname . ' "sudo rm ' . $eventPath . '"';
  return "$cmd\n";
}

sub getHostName
{
  my ($silo) = @_;

  my $colo;
  if ($silo !~ m/^17\d+/) {

    $colo = BF1;
  }
  else {

    $colo = IR2;
  }

  my $hostname = 'web' . substr($silo, 0, 4) . '03' . $colo;
  return $hostname;
}

sub isEventFilePresent
{
  my ($sid, $silo, $level) = @_;

  # Check if event exists on new farm
  my $eventPath = BASEQPATH . '*' . $level . $sid;

  my $hostname = getHostName($silo);

  my $cmd = 'yinst ssh -h ' . $hostname . ' "ls ' . $eventPath . '"';

  my $res = qx/$cmd/;
  chop($res); chop($res);

  my $ret = FAIL;
  my $log = '';
  if ($res !~ m/$sid/) {

    $log .= '|ERROR-SSH-FAILED ' . $hostname;
    $ret = SSH_FAIL;
  }
  elsif ($res =~ m/No such file or directory/i) {

    $log .= '|ERROR-NEW-EVENT-FILE-NOT-FOUND';
    $ret = NOT_FOUND;
  }
  else {

    $log .= '|success-new-event-file-found';
    $ret = SUCCESS;
  }

  return ($ret, $log, $res);
}

sub isEventFilePresentOnHost
{
  my ($eventPath, $hostname) = @_;

  # Check if event exists on new farm
  my $cmd = 'yinst ssh -h ' . $hostname . ' "ls ' . $eventPath . '"';

  my $res = qx/$cmd/;
  chop($res); chop($res);

  my $ret = FAIL;
  my $log = '';
  my @flds = split(/\//, $eventPath);
  my $sid = $flds[-1];

  if ($res !~ m/$sid/) {

    $log .= '|ERROR-SSH-FAILED ' . $hostname;
    $ret = SSH_FAIL;
  }
  elsif ($res =~ m/No such file or directory/i) {

    $log .= '|ERROR-NEW-EVENT-FILE-NOT-FOUND';
    $ret = NOT_FOUND;
  }
  else {

    $log .= '|success-new-event-file-found';
    $ret = SUCCESS;
  }

  return ($ret, $log);
}

sub verifyEventFile
{

  my ($silo, $user, $eventPath, $hostname) = @_;

  unless (defined $hostname) {

    $hostname = getHostName($silo);
  }

  my $cmd = 'yinst ssh -h ' . $hostname . ' "cat ' . $eventPath . '"';

  my $res = qx/$cmd/;

  my $log = '';
  my $ret = SUCCESS;

  if ($res =~ m/^(.*?)\cA/) {

    if ($1 ne $user) {

      $log .= '|ERROR-USER-NAME-MIS-MATCH ' . $1 . ' != ' . $user;
      $ret = FAIL;
    }
  }
  else {

    $log .= '|ERROR-USER-NOT-FOUND-IN-NEW-EVENT-FILE';
    $ret = FAIL;
  }

  return ($ret, $log);
}

sub verifyEventFileOnHost
{

  my ($eventPath, $hostname, $user) = @_;

  my $cmd = 'yinst ssh -h ' . $hostname . ' "cat ' . $eventPath . '"';

  my $res = qx/$cmd/;

  my $log = '';
  my $ret = SUCCESS;

  if ($res =~ m/^(.*?)\cA/) {

    if ($1 ne $user) {

      $log .= '|ERROR-USER-NAME-MIS-MATCH ' . $1 . ' != ' . $user;
      $ret = FAIL;
    }
  }
  else {

    $log .= '|ERROR-USER-NOT-FOUND-IN-NEW-EVENT-FILE';
    $ret = FAIL;
  }

  return ($ret, $log);
}

sub verifyMBox
{
  my ($sid, $silo) = @_;

  my $hostname = getHostName($silo);

  my $cmd = 'yinst ssh -h ' . $hostname . ' "fmbox.sh ' . $sid . '"';

  my $res = qx/$cmd/;
  chop($res); chop($res);

  my $log = '';
  my $ret = SUCCESS;
  if ($res =~ m/\/ms(\d+)\//) {

    if ($silo eq $1) {

      $log .= '|success-new-mbox-found';
    }
    else {

      $log .= '|ERROR-NEW-MBOX-NOT-FOUND';
      $ret = FAIL;
    }
  }
  else {

    $log .= '|ERROR-NO-MBOX-FOUND';
    $ret = FAIL;
  }

  return ($ret, $log);
}

die usage if (scalar(@ARGV) < 4);

GetOptions (
  'f=s' => \$IPFILENAME,
  'h=s' => \$HOST,
) or die usage;

open ($IPFH, "<", $IPFILENAME) or die "Error opening $IPFILENAME: $!";
open ($OPFH, ">", RESULTFILE) or die "Error opening " . RESULTFILE . ": $!";
open ($CMDFH, ">", CMDFILE) or die "Error opening " . CMDFILE . ": $!";

my $t0 = [gettimeofday];

while (my $line = <$IPFH>) {

  chomp($line);
  my $log;
  my $user;

  if ($line =~ m/^(.*?)\|/) {

    $user = $1;
  }

  if (
    ($line =~ m/silo-mismatch/) &&
    ($line =~ m/sid-mismatch/) && 
    ($line =~ m/path-mismatch/)
  ) {

    my ($oldSilo, $oldSid, $newSilo, $newSid, $oldLevel, $newLevel);

    $log = $user;

    if ($line =~ m/silo-mismatch (\d+) \!\= (\d+)/) {

      $newSilo = $1;
      $oldSilo = $2;
    }

    if ($line =~ m/sid-mismatch (\d+) \!\= (\d+)/) {

      $newSid = $1;
      $oldSid = $2;
    }

    if ($line =~ m/path-mismatch (.*?) \!\= (.*?)\|/) {

      $newLevel = $1;
      $oldLevel = $2;
    }
    # Check if event exists on new farm
    my ($ret, $logRet, $newEventPath) = isEventFilePresent($newSid, $newSilo, $newLevel);
    $log .= $logRet;

    if ($ret == SUCCESS) {

      ($ret, $logRet) = verifyEventFile($newSilo, $user, $newEventPath);
      $log .= $logRet;

      if ($ret == SUCCESS) {

        ($ret, $logRet) = verifyMBox($newSid, $newSilo);
        $log .= $logRet;

        if ($ret == SUCCESS) {

          $log .= '|cleanup-user-required';
          my @flds = split(/\|/, $line);
          print $CMDFH cleanupUser($oldSid, $oldSilo, $flds[-1]);
          ++$CLEANCOUNT;
        }
      }
    }
  }
  elsif (
    ($line !~ m/silo-mismatch/) &&
    ($line !~ m/sid-mismatch/) && 
    ($line =~ m/silo-match/) && 
    ($line =~ m/path-mismatch/)
  ) {

    # Only path-mismatch

    $log = $user;

    my ($newLevel, $oldLevel);
    if ($line =~ m/path-mismatch (.*?) \!\= (.*?)\|/) {

      $newLevel = $1;
      $oldLevel = $2;
    }

    # Check if correct event already exists on new farm
    my @flds = split(/\|/, $line);
    my $newEventPath = $flds[-1];
    $newEventPath =~ s/$oldLevel/$newLevel/;

    my ($ret, $logRet) = isEventFilePresentOnHost($newEventPath, $HOST);
    #$log .= $logRet;

    # If correct event file is not present then move event
    if ($ret == NOT_FOUND) {

      $log .= '|move-event-required';
      print $CMDFH  moveEvent($flds[-1], $newEventPath, $HOST);
      ++$CLEANCOUNT;
    }
    elsif ($ret == SUCCESS) {

      # Correct event file is already present
      # remove stale event file
      ($ret, $logRet) = verifyEventFileOnHost($newEventPath, $HOST, $user);
      $log .= $logRet;

      if ($ret == SUCCESS) {

        $log .= '|remove-event-required';
        print $CMDFH  removeEventOnHost($flds[-1], $HOST);
        ++$CLEANCOUNT;
      }
    }
  }
  elsif (
    ($line !~ m/silo-mismatch/) &&
    ($line =~ m/silo-match/) && 
    ($line =~ m/sid-mismatch/) && 
    ($line =~ m/path-mismatch/)
  ) {

    # Only sid-mismatch & path-mismatch

    my ($oldSid, $newSid, $oldLevel, $newLevel, $silo);

    $log = $user;

    if ($line =~ m/sid-mismatch (\d+) \!\= (\d+)/) {

      $newSid = $1;
      $oldSid = $2;
    }

    if ($line =~ m/path-mismatch (.*?) \!\= (.*?)\|/) {

      $newLevel = $1;
      $oldLevel = $2;
    }
    if ($line =~ m/silo-match (\d+)/) {

      $silo = $1;
    }
    # Check if event exists on new farm
    my ($ret, $logRet, $newEventPath) = isEventFilePresent($newSid, $silo, $newLevel);
    $log .= $logRet;

    if ($ret == SUCCESS) {

      ($ret, $logRet) = verifyEventFile($silo, $user, $newEventPath);
      $log .= $logRet;

      if ($ret == SUCCESS) {

        ($ret, $logRet) = verifyMBox($newSid, $silo);
        $log .= $logRet;

        if ($ret == SUCCESS) {

          $log .= '|cleanup-user-required';
          my @flds = split(/\|/, $line);
          print $CMDFH cleanupUser($oldSid, $silo, $flds[-1]);
          ++$CLEANCOUNT;
        }
      }
    }
  }

  print $OPFH "$log\n" if (defined $log);
  #print "$log\n" if (defined $log);
}


close ($IPFH);
close ($OPFH);
close ($CMDFH);

print tv_interval($t0) . " secs Users to clean: $CLEANCOUNT log file: " . RESULTFILE . " cmd file: " . CMDFILE . "\n";


