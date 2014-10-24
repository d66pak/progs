#!/home/y/bin/perl

use strict;
use warnings;
use Text::Balanced qw(extract_bracketed);
use Getopt::Long;
use JSON;
use Data::Dumper;
use Term::ProgressBar;


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

my $printModuleName;
my $printSuccessFileName;
my $printSuccessCount;
my $printRetryFileName;
my $printRetryCount;
my $printFailFileName;
my $printFailCount;
my $printErrType;
my $printErrTypeCount;

my $TOTAL_USERS = 0;

my $MODULE_STATS = undef;

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

sub printModuleStats
{
  my @modules = @_;

  #print Dumper($MODULE_STATS) . "\n";

  foreach my $module (@modules) {

    if (defined $MODULE_STATS->{$module}) {

      my $moduleRef = $MODULE_STATS->{$module};
      $printModuleName = $module;
      $printSuccessFileName = (defined $moduleRef->{successFH}) ? $moduleRef->{successFileName} : '';
      $printRetryFileName = (defined $moduleRef->{retryFH}) ? $moduleRef->{retryFileName} : '';
      $printFailFileName = (defined $moduleRef->{failFH}) ? $moduleRef->{failFileName} : '';

      $printSuccessCount = $moduleRef->{successCount};
      $printRetryCount = $moduleRef->{retryCount};
      $printFailCount = $moduleRef->{failCount};

      write();
      $~ = 'STDOUT_MODULE';
      write();

      if (defined ($moduleRef->{errorTypes})) {

        my $errTypesRef = $moduleRef->{errorTypes};
        foreach my $err (keys %$errTypesRef) {

          #print "$err\n";
          $printErrType = $err;
          $printErrTypeCount = $errTypesRef->{$err};
          $~ = 'STDOUT_ERR_TYPES';
          write();
        }
      }

    }
  }

}

sub closeModuleStats
{
  my @modules = @_;

  foreach my $module (@modules) {

    if (defined $MODULE_STATS->{$module}) {

      my $moduleRef = $MODULE_STATS->{$module};

      close ($moduleRef->{successFH}) if (defined $moduleRef->{successFH});
      close ($moduleRef->{retryFH}) if (defined $moduleRef->{retryFH});
      close ($moduleRef->{failFH}) if (defined $moduleRef->{failFH});
    }
  }
}

sub appendSuccessFile
{
  my ($module, $msg) = @_;

  if (exists $MODULE_STATS->{$module} && defined $MODULE_STATS->{$module}) {

    my $moduleRef =  $MODULE_STATS->{$module};

    unless (defined $moduleRef->{successFH}) {

      open ($moduleRef->{successFH}, '>', $moduleRef->{successFileName}) or die "Error opening $moduleRef->{successFileName}: $!";
    }

    print {$moduleRef->{successFH}} "$msg\n";
  }
}

sub appendRetryFile
{
  my ($module, $msg) = @_;

  if (exists $MODULE_STATS->{$module} && defined( $MODULE_STATS->{$module})) {

    my $moduleRef =  $MODULE_STATS->{$module};

    unless (defined $moduleRef->{retryFH}) {

      open ($moduleRef->{retryFH}, '>', $moduleRef->{retryFileName}) or die "Error opening $moduleRef->{retryFileName}: $!";
    }

    print {$moduleRef->{retryFH}} "$msg\n";
  }
}

sub appendFailFile
{
  my ($module, $msg) = @_;

  if (exists $MODULE_STATS->{$module} && defined( $MODULE_STATS->{$module})) {

    my $moduleRef =  $MODULE_STATS->{$module};

    unless (defined $moduleRef->{failFH}) {

      open ($moduleRef->{failFH}, '>', $moduleRef->{failFileName}) or die "Error opening $moduleRef->{failFileName}: $!";
    }

    print {$moduleRef->{failFH}} "$msg\n";
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

      my $mailStatRef = $MODULE_STATS->{$MAIL_MODULE};

      if ($mailLatest->{$STATUS} eq $SUCCESS) {

        # Mail success
        appendSuccessFile($MAIL_MODULE, $user);
        ++$mailStatRef->{successCount};
      }
      elsif ($mailLatest->{$STATUS} eq $RETRY) {

        my $msg = "$user\t" . scalar(@{$root->{$MAIL_MODULE}}) . "\t$mailLatest->{$HOSTNAME}\t$mailLatest->{$FAULTSTR}";
        appendRetryFile($MAIL_MODULE, $msg);
        ++$mailStatRef->{retryCount};
        ++$mailStatRef->{errorTypes}->{$mailLatest->{$FAULTSTR}};
      }
      elsif ($mailLatest->{$STATUS} eq $FAIL) {

        # If module has failed then error msg of last but one attempt should be captured
        my $lastButOne = $root->{$MAIL_MODULE}[1];
        my $hostname = (defined $lastButOne) ? $lastButOne->{$HOSTNAME} : $mailLatest->{$HOSTNAME};
        my $faultStr = (defined $lastButOne) ? $lastButOne->{$FAULTSTR} : $mailLatest->{$FAULTSTR};

        my $msg = "$user\t" . scalar(@{$root->{$MAIL_MODULE}}) . "\t$hostname\t$faultStr";

        appendFailFile($MAIL_MODULE, $msg);
        ++$mailStatRef->{failCount};
        ++$mailStatRef->{errorTypes}->{$faultStr};
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

# Initialize module stats
initModuleStats($MAIL_MODULE);

my $jsonObjStr;
my $user;

my $max = `wc -l < $jsonFileName`;
my $progress = Term::ProgressBar->new({name => 'Processing Notestat O/P',
    count => $max,
    remove => 1,
    ETA => 'linear',}
);
$progress->minor(0);

while (my $line = <$JSONFH>) {

  chomp($line);
  #print "$line\n";

  $progress->update();

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


printModuleStats($MAIL_MODULE);

closeModuleStats($MAIL_MODULE);

close ($JSONFH);


format STDOUT =
---------------------------------------------------------------
Total Users: @<<<<<<<<<<
$TOTAL_USERS
.

format STDOUT_MODULE =
---------------------------------------------------------------
@<<<<<<<<<<<<<<<<<<<<
$printModuleName
----------------
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$printSuccessFileName
Successful: @<<<<<<<<<<
            $printSuccessCount
-----------------------------------------------
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$printRetryFileName
Retry:      @<<<<<<<<<<
            $printRetryCount
-----------------------------------------------
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$printFailFileName
Failed:     @<<<<<<<<<<
            $printFailCount
---------------------------------------------------------------
.

format STDOUT_ERR_TYPES =
^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ~~
$printErrType
Count: @<<<<<<<<<<
       $printErrTypeCount
---------------------------------------------------------------
.


