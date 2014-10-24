#!/home/y/bin/perl

use strict;
use warnings;
use MsgStore;
use Getopt::Long;

my $userListFile;

sub findSidSilo($)
{
  my $user = shift;

  my ($sid, $silo);

  my $cmd = "udb-test -Rk sid,ym_mail_sh $user 2>&1";

  my $ret = qx/$cmd/;

  unless ($?) {

    if ($ret =~ /=sid=(\w{1,10})\ca(\w{1,32})/) {

      $sid = $2;
    }

    if ($ret =~ m/=ym_mail_sh=silo\cB(\d+)\cA/) {

      $silo = $1;
    }
  }

  return ($sid, $silo);
}

sub folderSummary
{
  my ($user) = @_;

  my ($sid, $silo) = findSidSilo($user);

  my $mailbox = Mailbox::new();
  my ($ret, $busy) = $mailbox->open($sid, 'yahoo', "ms$silo");

  if ($ret) {

    my @folders = $mailbox->listFolders();

    foreach my $yFolder (@folders) {

      my $folder = $mailbox->getFolder($yFolder);

      unless (defined $folder) {

        print "Folder $yFolder does not exists in Y! Mbox";
        next;
      }   

      my $msgList = MessageList::new();
      unless ($folder->messages($msgList)) {

        print "Failed to get message list folder: $yFolder";
        next;
      }   

      my $numberOfMsgs = $msgList->size();
      print "$yFolder\t$numberOfMsgs msgs\n";

    } # foreach

    print "----------------------------------------\n";
    print "Total " . scalar(@folders) . " folders MBox size " . $mailbox->size() . " " . $mailbox->getSize() . " " . $mailbox->getPhysicalSize() . "\n";
    $mailbox->close();
  }
  else {

    print "Mailbox open failed, busy: $busy\n";
  }

}

sub usage
{
  print "sudo $0 -f <user-list-file>\n";
}

############# MAIN ###################
#

die usage if (scalar(@ARGV) < 2);

GetOptions (
  'f=s' => \$userListFile,
) or die usage;

# Change the effective UID to nobody2
# This is required so that the mailbox is created with the owner as nobody2
print "The user ID of the process is - $>\n";
print "About to change the user ID to nobody2 ...\n";

$> = 60001;

if ( $! ) {
    print "Unable to change the user ID to nobody2 .. Aborting ...\n";
    print "Details of errors: $!\n";

    exit 1;
}

open (my $fh, '<', $userListFile) or die "Error opening $userListFile: $!";

while (my $yid = <$fh>) {

  chomp($yid);

  print "----------------------------------------\n";
  print "$yid\n";

  folderSummary($yid);
}

