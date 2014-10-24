#!/home/y/bin/perl

use strict;
use warnings;
use Time::HiRes qw(gettimeofday tv_interval);

use MsgStore;

################## MAIN #####################
# Change the effective UID to nobody2
# This is required so that the mailbox is created with the owner as nobody2
my $totalTime = [gettimeofday];
print "The user ID of the process is - $>\n";
print "About to change the user ID to nobody2 ...\n";

$> = 60001;

if ($!) {

    print "Unable to change the user ID to nobody2 .. Aborting ...\n";
    print "Details of errors: $!\n";
    die;
}
print "The new user ID - $> process ID - $$\n";

# carolstraw@sky.com
my $sid = '13510804073684461';
my $silo = 'ms140315';
my $yFolder = 'PAYPAL';
my $mid = '3981_26789372_827_2393_542_0_457_1065_2488676010';

my $mailbox = Mailbox::new();
my ($ret, $busy) = $mailbox->open($sid, "yahoo", $silo);
unless ($ret) {

  print "Mailbox open failed, busy: $busy\n";
  die;
}

my $folder = $mailbox->getFolder($yFolder);

unless (defined $folder) {

  print "Folder $yFolder does not exists in Y! Mbox\n";
  die;
}

# Get a new unique message id.
my $msgId = MessageId::new();

unless (defined $msgId) {

  die "Cannot create new msgId";
}

$msgId->init($mid);

my $flags = Flags::new();

unless (defined $flags) {

  die "Cannot create flags";
}

$flags->unsetAll();

#$flags->setSeen();
$flags->setRecent();

$ret = $folder->writeFlags($flags, $msgId);

if ($ret) {

  print "Flag update pass: $ret\n";
}
else {

  print "Flag update fail: $ret\n";
}

$mailbox->setPIKFolderOutOfSync();

$mailbox->close();

