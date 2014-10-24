#!/home/y/bin/perl

use strict;
use warnings;
use Time::HiRes qw(gettimeofday tv_interval);
use Getopt::Long;
use File::Find;
#use Pod::Usage;
use ydbs;
#use Data::Dumper;
use DateTime;

use constant {

  USER => 'user',
  SILO => 'silo',
  MODULES => 'modules',
  STATE => 'state',
  TS => 'timestamp',
  RETRIES => 'retries',
  UNKNOWN => 0,
  DONE => 1,
  READY => 2,
  PROCESSING => 3,
  SLEEP => 4,
  WAIT => 5,
  RETRY => 6,
  ERROR => 7,
  RESULTFILE => '/tmp/analyze-events-' . time(),
  BASEQPATH => '/rocket/ms1/external/accessMail/sky_mig/',
};

my $eventCount = 0;
my $totalEvents = 0;
my @queueList;
my $destQ = '';
my $printUser = 0;
my $listEvent = 0;
my $checkGuid = 0;
my $checkSid = 0;
my $checkSilo = 0;
my $listModule = 0;
my $verbose = 0;
my $help = 0;
my @eFiles;
my $tempFile;
my $OP = undef;

sub usage
{
  print "Usage: sudo $0 -q <queue-name1>,<queue-name2> " .
  '[' .
  '-events <number-of-events> ' .
  '| --printuser ' .
  '| --listevent ' .
  '| --checkguid ' .
  '| --checksid ' .
  '| --checksilo ' .
  '| --listmodule ' .
  '| --verbose ' .
  '| --help ' .
  ']' .
  "\n";
}

sub wanted
{
  if (-f) {

    if (!$eventCount || $totalEvents < $eventCount) {

      #print $File::Find::name . "\n";
      processEvent($File::Find::name);
      unless ($verbose) {

        local $| = 1;
        print substr( "|/-\\", $totalEvents % 4, 1 ), "\b";
      }
      ++$totalEvents;
    }
    else {

      die "reached-limit";
    }
  }
}

sub processEvent($)
{
  my ($ef) = @_;
  #my $userName = getUserName($File::Find::name);
  my $msg;
  my $userName = 'no-yid';
  my $ed = scanEventFile($ef);
  if (defined $ed) {

    #print Dumper($ed) . "\n";
    if (exists $ed->{USER} && defined $ed->{USER}) {

      $userName = $ed->{USER};
    }

    ########## --printuser ###########
    $msg .= $userName if $printUser;
  }
  else {

    $msg .= "event-file-empty";
  }

  ############# --checkguid, checksid, checksilo ################
  my @keys;
  push (@keys, 'mbr_guid') if $checkGuid;
  push (@keys, 'sid') if $checkSid;
  push (@keys, 'ym_mail_sh') if $checkSilo;

  if (scalar(@keys)) {

    my $udbUser = openUDBUser(\@keys, $userName);

    if (defined $udbUser) {

      $msg .= '|' . $udbUser->get('mbr_guid') if $checkGuid;

      if ($checkSilo) {

        my $ymMailSh = $udbUser->get('ym_mail_sh');
        if ($ymMailSh =~ m/silo\cB(\d*?)\cA/) {

          $msg .= '|silo-mismatch ' . $1 . ' != ' . $ed->{SILO} if ($1 ne $ed->{SILO});
          if ($1 eq $ed->{SILO}) {

            my $hostname = `hostname`;
            my @alist = split(/\./, $hostname);
            if ($alist[0] =~ m/web(\d{4})/) {

              if ($ed->{SILO} =~ m/$1/) {

                $msg .= '|silo-match ' . $ed->{SILO};
              }
              else{

                $msg .= '|silo-mismatch ' . $ed->{SILO} . ' != ' . $1;
              }
            }
          }
        }
        else {

          $msg .= '|no-silo-record';
        }
      }

      if ($checkSid) {

        my @pathList = split(/\//, $ef);
        my @val = split(/\cA/, $udbUser->get('sid'));
        my $sid = $val[-1];

        $msg .= '|sid-mismatch ' . $sid . ' != ' . $pathList[-1] if ($sid ne $pathList[-1]);

        my @digits = split(//, $sid);
        my $level1 = $digits[-1] . $digits[-2];
        my $level2 = $digits[-3] . $digits[-4];

        $msg .= '|path-mismatch ' . '/' . $level1 . '/' . $level2 . '/ != /'
        . $pathList[-3] . '/' . $pathList[-2] . '/' if (($level1 ne $pathList[-3]) || ($level2 ne $pathList[-2]));
      }
    }
    else {

      $msg .= '|no-udb-record';
    }
  }

  ############ --listmodule ################
  if ($listModule) {

    if (exists $ed->{MODULES} && defined $ed->{MODULES}) {

      $msg .= '|';
      my $moduleRef = $ed->{MODULES};
      foreach my $module (keys %$moduleRef) {

        $msg .= "$module:";
        if (defined $moduleRef->{$module}->{STATE}) {

          my $state = $moduleRef->{$module}->{STATE};
          $msg .= "S$state:";

          if ($state == PROCESSING) {

            my $cmd = "/home/y/bin/qls -C query -P $ef 2>&1";
            my $ret = qx/$cmd/;

            if ($ret =~ m/\w+/) {

                $msg .= 'locked:';
            }
          }
        }
        else {
 
          $msg .= 'no-state:';
        }

        $msg .= (defined $moduleRef->{$module}->{RETRIES}) ? "R$moduleRef->{$module}->{RETRIES}:" : 'no-retry:';

        if (defined $moduleRef->{$module}->{TS}) {

          my $ts = DateTime->from_epoch(epoch => $moduleRef->{$module}->{TS});
          my $now = DateTime->now;
          my $dur;
          if ($ts < $now) {

            $dur = $now - $ts;
            my ($hour, $min) = $dur->in_units('hours', 'minutes');
            $msg .= $hour . "hr-" . $min . "min ago:";
          }
          elsif ($ts > $now) {

            $dur = $ts - $now;
            my ($hour, $min) = $dur->in_units('hours', 'minutes');
            $msg .= $hour . "hr-" . $min . "min after:";
          }
          else{

            $msg .= "now:";
          }
        }
        else {

          $msg .= 'no-ts:';
        }
      }
    }
    else {

      $msg .= '|no-modules';
    }
  }

  ############ --listevnet #############
  $msg .= '|' . $ef if $listEvent;

  print $OP "$msg\n";
}

sub openUDBUser($$)
{
  my ($keyList, $yid) = @_;
  my $accId = new ydbsAccountID($yid);
  my $user = new ydbUser();
  my $rc = $user->open($accId, ydbUser::ro, join("\001", @$keyList));
  return ($rc) ? undef : $user;
}

sub getUDBKey($$)
{
  my ($key, $yid) = @_;
  my $accId = new ydbsAccountID($yid);
  my $user = new ydbUser();
  my $rc = $user->open($accId, ydbUser::ro, $key);
  if ($rc) {

    return "mbr_guid-fail";
  }
  my $val = $user->get($key);
  return $val;
}

sub scanEventFile($)
{
  my ($ef) = @_;

  my %eventData = ();

  if (open(my $EF, '<', $ef)) {

    my $line = <$EF>;
    chomp ($line);
    #print "$line\n";
    my @fields = split (/\ca/, $line);
    $eventData{USER} = $fields[0] if (defined $fields[0]);
    $eventData{SILO} = $fields[1] if (defined $fields[1]);

    while ($line = <$EF>) {

      chomp ($line);
      #print "$line\n";
      @fields = split (/,/, $line);
      if (defined $fields[0]) {

        $eventData{MODULES}{$fields[0]}{STATE} = $fields[1] if (defined $fields[1]);
        $eventData{MODULES}{$fields[0]}{TS} = $fields[2] if (defined $fields[2]);
        $eventData{MODULES}{$fields[0]}{RETRIES} = $fields[3] if (defined $fields[3]);
      }
    }
    close($EF);
  }
  else {

    print "Error opening $ef: $!\n";
  }
  return \%eventData;
}

sub getUserName($)
{
  my ($ef) = @_;

  if (open(my $EF, '<', $ef)) {

    my $line = <$EF>;
    close($EF);
    #print "$line\n";
    if ($line =~ /(^.*?)\ca/) {

      my $user = $1;
      unless ($user =~ /test/) {

        #print "$user\n";
        return $user;
      }
    }
    else {

      print "Error finding user name in $ef\n";
    }
  }
  else {

    print "Error opening $ef: $!\n";
  }
  return undef;
}

################## MAIN #####################

die usage if (scalar @ARGV < 2);

GetOptions (
  'events:i' => \$eventCount,
  'q=s' => \@queueList,
  'printuser' => \$printUser,
  'listevent' => \$listEvent,
  'checkguid' => \$checkGuid,
  'checksid' => \$checkSid,
  'checksilo' => \$checkSilo,
  'listmodule' => \$listModule,
  'verbose' => \$verbose,
  'help' => \$help,
  #'d=s' => \$destQ,
) or die usage;

if ($help) {

  usage();
  exit;
}

#print "The user ID of the process is - $>\n";
#print "About to change the user ID to nobody2 ...\n";

# Change the effective UID to nobody2
$> = 60001;

if ($!) {

    print "Unable to change the user ID to nobody2 .. Aborting ...\n";
    print "Details of errors: $!\n";
    die;
}
#print "The new user ID - $> process ID - $$\n";


# Open outstream for writing
if ($verbose) {

  $OP = *STDOUT;
}
else {

  open ($OP, '>', RESULTFILE) or die "Error opeining " . RESULTFILE . ": $!";
}

@queueList = split(/,/, join(',', @queueList));

foreach my $queue (@queueList) {

  my $totalTime = [gettimeofday];
  my $queuePath = BASEQPATH . $queue . '/';

  eval {
    find (\&wanted, $queuePath);
  };

  print "---- " . tv_interval($totalTime) . " $queue: $totalEvents " . ($verbose ? '' : RESULTFILE) . " ----\n";
  $totalEvents = 0;
}

__END__
