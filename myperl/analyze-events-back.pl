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
};
my $eventCount = 0;
my $totalEvents = 0;
my $queue = '';
my $destQ = '';
my $printUser = 0;
my $listEvent = 0;
my $checkGuid = 0;
my $listModule = 0;
my $verbose = 0;
my $help = 0;
my @eFiles;
my $TEMPF;
my $tempFile;
my $OP = undef;

sub usage
{
  print "Usage: sudo $0 -q <queue-name> [-events <number-of-events> | --printuser | --listevent | --checkguid | --listmodule | --verbose | --help ]\n";
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
    $msg .= $userName if $printUser;
  }
  else {

    $msg .= "event-file-empty";
  }
  $msg .= '|' . getUDBKey('mbr_guid', $userName) if $checkGuid;

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
  $msg .= '|' . $ef if $listEvent;

  print $OP "$msg\n";
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
my $totalTime = [gettimeofday];

die usage if (scalar @ARGV < 2);

GetOptions (
  'events:i' => \$eventCount,
  'q=s' => \$queue,
  'printuser' => \$printUser,
  'listevent' => \$listEvent,
  'checkguid' => \$checkGuid,
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

my $baseQPath = '/rocket/ms1/external/accessMail/sky_mig/';
my $queuePath = $baseQPath . $queue . '/';

eval {
  find (\&wanted, $queuePath);
  close ($TEMPF);
};

print tv_interval($totalTime) . " $totalEvents " . ($verbose ? '' : RESULTFILE) . " Exiting...\n";

__END__
