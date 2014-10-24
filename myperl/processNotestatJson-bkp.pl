#!/home/y/bin/perl

use strict;
use warnings;
use Text::Balanced qw(extract_bracketed);
use Getopt::Long;
use JSON;
use Data::Dumper;


my $MAIL_MODULE = 'SkyMailResync';
my $TS = 'TS';
my $HOSTNAME = 'HOSTNAME';
my $HOSTIP = 'HOSTIP';
my $STATUS = 'STATUS';
my $FAULTSTR = 'FAULTSTR';
my $PARTNER = 'PARTNER';
my $SUCCESS = 'S';
my $FAIL = 'F';
my $RETRY = 'R';

my $TIME = time();
my $SUCCESS_LIST = "module_success_list_" . $time;
my $RETRY_LIST = "module_retry_list_" . $time;
my $FAIL_LIST = "module_fail_list_" . $time;
my $SUCCESSLIST;
my $RETRYLIST;
my $FAILLIST;

my $TOTAL_USERS = 0;
my $SUCCESS_COUNT = 0;
my $FAIL_COUNT = 0;
my $RETRY_COUNT = 0;


sub usage
{
  print "Usage: $0 -json <notestat-op-in-json-format>\n";
}

sub initModuleStats
{
  my @modules = @_;

  foreach my $module (@modules) {

    #print "Init module: $module\n";
    $MODULE_STATS->{$module}->{successCount} = 0;
    my $moduleRef = $MODULE_STATS->{$module};
    $moduleRef->{retryCount} = 0;
    $moduleRef->{failCount} = 0;

    $moduleRef->{successFileName} = $module . '_success_list_' . $TIME;
    $moduleRef->{retryFileName} = $module . '_retry_list_' . $TIME;
    $moduleRef->{failFileName} = $module . '_fail_list_' . $TIME;

    $moduleRef->{successFH} = undef;
    $moduleRef->{retryFH} = undef;
    $moduleRef->{failFH} = undef;
  }
}

sub appendSuccessFile
{
  my ($module) = @_;

  if (exists $MODULE_STATS->{$module}->{successFH} && defined ($MODULE_STATS->{$module}->{successFH})) {
  }
}

sub processUser($$)
{
  my ($user, $jsonTxt) = @_;

  my $root = from_json($jsonTxt);

  #print Dumper($root) . "\n";

  if (exists $root->{$MAIL_MODULE} && defined $root->{$MAIL_MODULE}) {

    my $mailLatest = $root->{$MAIL_MODULE}[0];
    if (defined $mailLatest) {

      if ($mailLatest->{$STATUS} eq $SUCCESS) {

        # Mail success
        print $SUCCESSLIST "$user\n";
        ++$SUCCESS_COUNT;
      }
      elsif ($mailLatest->{$STATUS} eq $RETRY) {

        ++$RETRY_COUNT;
        print $RETRYLIST "$user\t$mailLatest->{$FAULTSTR}\t$mailLatest->{$HOSTNAME}\n";
      }
      elsif ($mailLatest->{$STATUS} eq $FAIL) {

        ++$FAIL_COUNT;
        print $FAILLIST "$user\t$mailLatest->{$FAULTSTR}\t$mailLatest->{$HOSTNAME}\n";
      }
    }
  }
  
}

########## MAIN ##############

die usage unless @ARGV == 2;

my $jsonFileName;
GetOptions (
  'json=s' => \$jsonFileName,
) or die usage;

open (my $JSONFH, '<', $jsonFileName) or die "Error opening $jsonFileName: $!";

open ($SUCCESSLIST, ">$SUCCESS_LIST") or die "Error opening $SUCCESS_LIST: $!";
open ($RETRYLIST, ">$RETRY_LIST") or die "Error opening $RETRY_LIST: $!";
open ($FAILLIST, ">$FAIL_LIST") or die "Error opening $FAIL_LIST: $!";

my $jsonObjStr;
my $user;

while (my $line = <$JSONFH>) {

  chomp($line);
  #print "$line\n";

  if ($line =~ m/\"(.*?@.*?\..*?)\"\s*:/) {

    $user = $1;
    chomp($user);
    #print "Processing User: $user\n";
    ++$TOTAL_USERS;
    next;
  }


  # Check if user is found
  if (defined $user) {

    # Accumulate lines until complete json object is found

    # Trim white spaces
    $line =~ s/^\s+|\s+$//;
    $jsonObjStr .= $line;
    #print "json -- $jsonObjStr\n";
    
    # Check if complete json obj is found
    my $text = extract_bracketed($jsonObjStr, '{}');

    if (defined $text) {

      #print "Found: $text\n";
      #print "Found: $jsonObjStr\n";
      $jsonObjStr = undef;

      # process json obj from text
      processUser($user, $text);
      $user = undef;
    }
    else {

      next;
    }
  }
}

close ($RETRYLIST);
close ($FAILLIST);
close ($SUCCESSLIST);
close ($JSONFH);

unless ($SUCCESS_COUNT) {

  unlink($SUCCESS_LIST);
  $SUCCESS_LIST = '';
}
unless ($RETRY_COUNT) {

  unlink($RETRY_LIST);
  $RETRY_LIST = '';
}
unless ($FAIL_COUNT) {

  unlink($FAIL_LIST);
  $FAIL_LIST = '';
}

format STDOUT =
----------------------------------------------------------------------------------------------------------
Total Users: @<<<<<<<<<
$TOTAL_USERS

Files Generated:
----------------
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< -- Successful: @<<<<<<<<<
$SUCCESS_LIST, $SUCCESS_COUNT
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< -- Retry: @<<<<<<<<<
$RETRY_LIST, $RETRY_COUNT
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< -- Failed: @<<<<<<<<<
$FAIL_LIST, $FAIL_COUNT
----------------------------------------------------------------------------------------------------------
.

write;


