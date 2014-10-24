#!/home/y/bin/perl

use strict;
use warnings;
use Time::HiRes qw(gettimeofday tv_interval);
use Getopt::Long;
use File::Find;

my $eventCount = 0;
my $srcQ= '';
my $destQ= '';
my @eFiles;
my $TEMPF;
my $tempFile;

sub usage
{
  print "Usage: $0 -e <number-of-events-to-move> -s <src-queue-name> -d <dest-queue-name>\n";
}

sub wanted
{
  if (-f) {

    if ($eventCount > 0) {

      #print $File::Find::name . "\n";
      my $userName = getUserName($File::Find::name);
      if (defined $userName) {

        print $TEMPF "$userName\n";
        --$eventCount;
      }
    }
    else {

      die "reached-limit";
    }
  }
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

        print "$user\n";
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
# Change the effective UID to nobody2
# This is required so that the mailbox is created with the owner as nobody2
my $totalTime = [gettimeofday];
#print "The user ID of the process is - $>\n";
#print "About to change the user ID to nobody2 ...\n";

$> = 60001;

if ($!) {

    print "Unable to change the user ID to nobody2 .. Aborting ...\n";
    print "Details of errors: $!\n";
    die;
}
#print "The new user ID - $> process ID - $$\n";

die usage unless @ARGV == 4;
GetOptions (
  'e=i' => \$eventCount,
  's=s' => \$srcQ,
  #'d=s' => \$destQ,
) or die usage;

#print "e = $eventCount s = $srcQueue d = $destQueue\n";

# Open Temp file for writing
$tempFile = "/tmp/sky-users.tmp";
print "User List: $tempFile\n";

open ($TEMPF, '>', $tempFile) or die "Error opeining $tempFile: $!";

my $baseQPath = '/rocket/ms1/external/accessMail/sky_mig/';
my $srcQPath = $baseQPath . $srcQ . '/';
#my $destQPath = $baseQPath . $destQ . '/';

eval {
  find (\&wanted, $srcQPath);
  close ($TEMPF);
};

#print "$@\n";
#unlink($tempFile);
print "Exiting...\n";
