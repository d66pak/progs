#!/home/y/bin/perl

use strict;
use warnings;
use MsgStore;


sub dumpUidls
{
  my ($sid, $silo, $yFolder) = @_;

  my $mailbox = Mailbox::new();
  my ($ret, $busy) = $mailbox->open($sid, "yahoo", $silo);
  unless ($ret) {

    print "Mailbox open failed, busy: $busy\n";
    return 1;
  }

  my $folder = $mailbox->getFolder($yFolder);
  unless (defined $folder) {

    print "Folder $yFolder does not exists in Y! Mbox\n";
    return 1;
  }

  my $msgList = MessageList::new();
  $ret = $folder->messages($msgList);
  unless ($ret) {

    print "Failed to get message list\n";
    return 1;
  }

  my $numberOfMsgs = $msgList->size();

  for (my $i = 0; $i < $numberOfMsgs; ++$i) {

    my $msgId = MessageId::new();
    $msgList->getMessageIdAt($i, $msgId);
    print "UIDL $i: " . $msgList->getUidlAt($i) . ' ' . $msgId->str() . "\n"; 
  }

  $mailbox->close();
}

die "sudo $0 sid msSilo folder-name\n" if (scalar(@ARGV) < 3 );

my ($sid, $silo, $folder) = ($ARGV[0], $ARGV[1], $ARGV[2]);

print "Fetching UIDLs for $sid $silo $folder\n"; 

dumpUidls($sid, $silo, $folder);


