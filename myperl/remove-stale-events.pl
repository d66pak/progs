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

sub cleanupUser($$$)
{
  my ($sid, $silo, $eventPath) = @_;

  my ($cmd, $res, $log);

  # Remove event files
  $cmd = 'yinst ssh -h ' . $HOST . ' "sudo rm ' . $eventPath;

  # Remove lock files from mbox
  my @d = split(//, $sid);
  my $mboxPath = BASEMBOXPATH . $silo . '/' . $d[-1] . $d[-2] . '/' . $d[-3] . $d[-4] . '/' . $sid . '/';

  $cmd .= ';sudo rm ' . $mboxPath . DELFILE01 .';sudo rm ' . $mboxPath . DELFILE02 . '"';
  #print "$cmd\n";
  #$res = qx/$cmd/;
  return "$cmd\n";
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
    my ($cmd1, $cmd, $res, $hostname, $colo, $newEvPath);

    $log = $user;

    if ($line =~ m/silo-mismatch (\d+) \!\= (\d+)/) {

      $newSilo = $1;
      $oldSilo = $2;
    }

    if ($line =~ m/sid-mismatch (\d+) \!\= (\d+)/) {

      $newSid = $1;
      $oldSid = $2;
    }

    if ($line =~ m/path-mismatch (.*?) \!\= (.*?)/) {

      $newLevel = $1;
      $oldLevel = $2;
    }
    # Check if event exists on new farm
    my $eventPath = BASEQPATH . '*' . $newLevel . $newSid;

    if ($newSilo !~ m/^17\d+/) {

      $colo = BF1;
    }
    else {

      $colo = IR2;
    }

    $hostname = 'web' . substr($newSilo, 0, 4) . '03' . $colo;

    $cmd1 = 'yinst ssh -h ' . $hostname;
    $cmd = $cmd1 . ' "ls ' . $eventPath . '"';

    $res = qx/$cmd/;
    chop($res); chop($res);

    if ($res !~ m/$newSid/) {

      $log .= '|ERROR-SSH-FAILED ' . $hostname;
    }
    elsif ($res !~ m/No such file or directory/i) {

      $log .= '|success-new-event-file-found';

      $newEvPath = $res;

      $cmd = $cmd1 . ' "cat ' . $newEvPath . '"';

      $res = qx/$cmd/;

      if ($res =~ m/^(.*?)\cA/) {

        if ($1 ne $user) {

          $log .= '|' . $1 . ' != ' . $user;
        }
        else {

          $cmd = $cmd1 . ' "fmbox.sh ' . $newSid . '"';

          $res = qx/$cmd/;
          chop($res); chop($res);

          if ($res =~ m/\/ms(\d+)\//) {

            if ($newSilo eq $1) {

              $log .= '|success-new-mbox-found';
              my @flds = split(/\|/, $line);
              print $CMDFH cleanupUser($oldSid, $oldSilo, $flds[-1]);
              ++$CLEANCOUNT;
            }
            else {

              $log .= '|ERROR-NEW-MBOX-NOT-FOUND';
            }
          }
          else {

            $log .= '|ERROR-NO-MBOX-FOUND';
          }
        }
      }
      else {

        $log .= '|ERROR-USER-NOT-FOUND-IN-NEW-EVENT-FILE';
      }
    }
    else {

      $log .= '|ERROR-NEW-EVENT-FILE-NOT-FOUND';
    }
  }
  if (
    ($line !~ m/silo-mismatch/) &&
    ($line !~ m/sid-mismatch/) && 
    ($line =~ m/path-mismatch/)
  ) {

    $log .= '|WARNING-ONLY-PATH-MISMATCH-NOT-HANDLED';
  }

  print $OPFH "$log\n" if (defined $log);
  #print "$log\n" if (defined $log);
}


close ($IPFH);
close ($OPFH);
close ($CMDFH);

print tv_interval($t0) . " secs Users to clean: $CLEANCOUNT log file: " . RESULTFILE . " cmd file: " . CMDFILE . "\n";


