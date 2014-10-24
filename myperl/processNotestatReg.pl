#!/usr/bin/perl

# Processes the Notestat output.
# Output must me created by using following command
# notestat -h 20000 -u user_list.txt -g USER > notestat_op.txt
#
# To run the script:
# ./processNotestatReg.pl notestat_op.txt
#


use strict;
#use warnings;
#use Data::Dumper;

# Constants
my $REG = 'reggate';

my $S = "S";
my $F = "F";
my $R = "R";

# User map
my %userMap = ();

# Create module map
my $moduleRef = {
  REG => 0,
  REGFAIL => 0,
  REG_SUCC_ATTS => 0,
  REG_FAIL_ATTS => 0,
};

my $time = time();
my $SUCCESS_LIST = "reg_success_list_" . $time;
my $FAIL_LIST = "reg_fail_list_" . $time;
my $MULTI_ATTS_LIST = "reg_multi_atts_list_" . $time;

my $TOTAL_USERS = 0;
my $SUCCESS_COUNT = 0;
my $FAIL_COUNT = 0;
my $MULTI_REG_COUNT = 0;

my $prev_contact_udref;
my $prev_mail_udref;
my $prev_mailpref_udref;
#############

sub getUserDetail($)
{
  my ($userDetail) = @_;

  my @info = split (/\|/, $userDetail);

  my $userDetail_ref = {
    USER => $info[1],
    MODULE => $info[2],
    PARTNER => $info[3],
    STATUS => $info[4],
    MSG => $info[5],
    TIMESTAMP => $info[6],
    IPADDR => $info[7],
    HOSTNAME => $info[8]
  };

  #print Dumper($userDetail_ref) . "\n";

  return $userDetail_ref;
}

sub markAllModules($)
{
  my ($val) = @_;

  $moduleRef->{REG} = $val;
  $moduleRef->{REGFAIL} = $val;
  $moduleRef->{REG_SUCC_ATTS} = $val;
  $moduleRef->{REG_FAIL_ATTS} = $val;
}

sub markAllModulesPassed()
{
}

sub checkAllModules($)
{
  my ($val) = @_;
  return 0;
}

sub allPassed()
{
   return 0;
}

sub processUser($)
{
  my ($udRef) = @_;

  if ($udRef->{MODULE} eq $REG) {

    # Check if this module is already processed
    if ($moduleRef->{REG} == 0) { 

      $TOTAL_USERS++;

      if ($udRef->{STATUS} eq $S) {

        # Put the user into success list
        print SUCCESSLIST "$udRef->{USER}\n";
        $SUCCESS_COUNT++;

        $moduleRef->{REG} = 1;
        $moduleRef->{REG_SUCC_ATTS}++;
      }
      elsif ($udRef->{STATUS} eq $F) {

        # Put the user into success list
        print FAILLIST "$udRef->{USER}\n";
        $FAIL_COUNT++;

        $moduleRef->{REG} = 1;
        $moduleRef->{REGFAIL} = 1;
        $moduleRef->{REG_FAIL_ATTS}++;
      }
    }
    else {

      if ($udRef->{STATUS} eq $S) {

        $moduleRef->{REG_SUCC_ATTS}++;
      }
      elsif ($udRef->{STATUS} eq $F) {

        $moduleRef->{REG_FAIL_ATTS}++;
      }
    }
  }
}

sub writeUserStatus($)
{
      my ($user) = @_;

      if ($moduleRef->{REG_FAIL_ATTS} > 1 || $moduleRef->{REG_SUCC_ATTS} > 1) {

        $MULTI_REG_COUNT++;
        print MULTIATTSLIST "$user\tSuccess_attempts\t" . $moduleRef->{REG_SUCC_ATTS} . "\tFailed_attempts\t" . $moduleRef->{REG_FAIL_ATTS} . "\n";
      }
}
############## MAIN ##################

unless (defined $ARGV[0]) {

  die "Usage: ./processNotestatReg.pl notestat_op.txt\n";
}

open (NOTEOP, "<$ARGV[0]") or die "Error opening $ARGV[1]: $!";

open (SUCCESSLIST, ">$SUCCESS_LIST") or die "Error opening $SUCCESS_LIST: $!";
open (FAILLIST, ">$FAIL_LIST") or die "Error opening $FAIL_LIST: $!";
open (MULTIATTSLIST, ">$MULTI_ATTS_LIST") or die "Error opening $MULTI_ATTS_LIST: $!";

my $user = "";

# Start processing notestat o/p line by line
while (my $line = <NOTEOP>) {

  chomp ($line);

  # Get the user
  my $udRef = getUserDetail($line);

  if ($user eq "") {

    $user = $udRef->{USER};
  }

  # Check if user has changed 
  if ($user ne $udRef->{USER}) {

    # User has changed
    writeUserStatus($user);

    # Start processing the new user
    $user = $udRef->{USER};
    markAllModules(0);
  }

  # Process user
  processUser($udRef);
}

# For the last user
writeUserStatus($user);

close (MULTIATTSLIST);
close (FAILLIST);
close (SUCCESSLIST);
close (NOTEOP);

format STDOUT =
----------------------------------------------------------------------------------------------------------
Total Users: @<<<<<<<<<
$TOTAL_USERS

Files Generated:
----------------
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< -- Successful:     @<<<<<<<<<
$SUCCESS_LIST $SUCCESS_COUNT
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< -- Failed: @<<<<<<<<<
$FAIL_LIST $FAIL_COUNT
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< -- Attempted multiple times: @<<<<<<<<<
$MULTI_ATTS_LIST $MULTI_REG_COUNT
----------------------------------------------------------------------------------------------------------
.

write;

#print "Total Users: $TOTAL_USERS\n\n";
#print "Files generated:\n";
#print "$SUCCESS_LIST\t-- all: $SUCCESS_COUNT\n";
#print "$TODO_LIST\t-- contact: $TODO_CONTACT_COUNT\tmail: $TODO_MAIL_COUNT\tmail pref: $TODO_MAILPREF_COUNT\n";
#print "$MODULE_RETRY_LIST\t-- contact: $RETRY_CONTACT_COUNT\tmail: $RETRY_MAIL_COUNT\tmail pref: $RETRY_MAILPREF_COUNT\n";
#print "$MODULE_MISSING_LIST\t-- contact: $MISSING_CONTACT_COUNT\tmail: $MISSING_MAIL_COUNT\tmail pref: $MISSING_MAILPREF_COUNT\tall: $MISSING_ALL_COUNT\n";

######### END ###########

