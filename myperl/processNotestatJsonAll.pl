#!/home/y/bin/perl

use strict;
use warnings;
use Text::Balanced qw(extract_bracketed);
use Getopt::Long;
use JSON;
use Data::Dumper;

my $MAIL_MODULE = 'SkyMailResync';
my $CONTACT_MODULE = 'SkyContact';
my $MAIL_PREF_MODULE = 'SkyMailPreferences';
my $CALENDAR_MODULE = 'SkyCalendar';
my $REG_MODULE = 'reggate';
my $TS = 'TS';
my $HOSTNAME = 'HOSTNAME';
my $HOSTIP = 'HOSTIP';
my $STATUS = 'STATUS';
my $FAULTSTR = 'FAULTSTR';
my $PARTNER = 'PARTNER';
my $SUCCESS = 'S';
my $FAIL = 'F';
my $RETRY = 'R';

# Add/Remove module to be processed
my @MODULES_TO_PROCESS;
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
  print "Usage: $0 -json <notestat-op-in-json-format> -module module1,module2\n";
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
  $~ = 'STDOUT';
  write();

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

# These are generic steps to process a module
# If you have different steps to process a module, write a new process function
#
sub processModule($$$)
{
  my ($rootRef, $user, $module) = @_;

  my $root = $$rootRef;

  if (exists $root->{$module} && defined $root->{$module}) {

    my $moduleLatest = $root->{$module}[0];
    if (defined $moduleLatest) {

      my $moduleStatRef = $MODULE_STATS->{$module};

      if ($moduleLatest->{$STATUS} eq $SUCCESS) {

        # success
        appendSuccessFile($module, $user);
        ++$moduleStatRef->{successCount};
      }
      elsif ($moduleLatest->{$STATUS} eq $RETRY) {

        # retry
        my $msg = "$user\t" . scalar(@{$root->{$module}}) . "\t$moduleLatest->{$HOSTNAME}\t$moduleLatest->{$FAULTSTR}";
        appendRetryFile($module, $msg);
        ++$moduleStatRef->{retryCount};
        ++$moduleStatRef->{errorTypes}->{$moduleLatest->{$FAULTSTR}};
      }
      elsif ($moduleLatest->{$STATUS} eq $FAIL) {

        # If module has failed then error msg of last but one attempt should be captured
        my $lastButOne = $root->{$module}[1];
        my $hostname = (defined $lastButOne) ? $lastButOne->{$HOSTNAME} : $moduleLatest->{$HOSTNAME};
        my $faultStr = (defined $lastButOne) ? $lastButOne->{$FAULTSTR} : $moduleLatest->{$FAULTSTR};

        my $msg = "$user\t" . scalar(@{$root->{$module}}) . "\t$hostname\t$faultStr";

        appendFailFile($module, $msg);
        ++$moduleStatRef->{failCount};
        ++$moduleStatRef->{errorTypes}->{$faultStr};
      }
    }
  }
}

sub processUser($$)
{
  my ($user, $jsonTxt) = @_;

  my $root = from_json($jsonTxt);

  #print Dumper($root) . "\n";
  foreach my $module (@MODULES_TO_PROCESS) {

    processModule(\$root, $user, $module);
  }

}

########## MAIN ##############

die usage unless @ARGV == 4;

my $jsonFileName;
GetOptions (
  'json=s' => \$jsonFileName,
  'module=s' => \@MODULES_TO_PROCESS,
) or die usage;

open (my $JSONFH, '<', $jsonFileName) or die "Error opening $jsonFileName: $!";

@MODULES_TO_PROCESS = split (/,/, join (',', @MODULES_TO_PROCESS));

# Initialize module stats
initModuleStats(@MODULES_TO_PROCESS);

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


printModuleStats(@MODULES_TO_PROCESS);

closeModuleStats(@MODULES_TO_PROCESS);

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


