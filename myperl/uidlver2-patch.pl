#!/home/y/bin/perl

use strict;
use warnings;
use MsgStore;
use Math::BigInt;

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

    my $uidl = $msgList->getUidlAt($i);

    # Check if this uidl needs to be rectified
    if ($uidl =~ m/\D/) {

      print "Uidl: $uidl not requires patch\n";
      next;
    }

    # Fetch the message
    my $msgId = MessageId::new();
    $msgList->getMessageIdAt($i, $msgId);
    my $msg = Message::new_from_messageId($msgId);
    unless ($folder->fetchMsg($msg)) {

      print "Unable to fetch message for : $uidl\n";
      next;
    }

    my $msgdump = $msg->getEntireMessage();
    open(my $fh, '>', '/tmp/msg' . $uidl . '.dump');
    print $fh $msgdump;
    close $fh;
    $msgdump = $msg->getBody();
    open($fh, '>', '/tmp/msgbody' . $uidl . '.dump');
    print $fh $msgdump;
    close $fh;
    $msgdump = $msg->getHeader();
    open($fh, '>', '/tmp/msghdr' . $uidl . '.dump');
    print $fh $msgdump;
    close $fh;

    # Flag updates
    my $msgInfo = MessageInfo::new();
    unless ($folder->getMsgInfo($msgId, $msgInfo)) {

      print "msginfo failed for : $uidl\n";
      next;
    }

    my $flags = Flags::new();
    $flags = $msgInfo->getFlags($flags);

    # Change uidl
    my $uidl2 = $uidl;
    $uidl2 = Math::BigInt->new("$uidl2")->as_hex;
    $uidl2 =~ s/^0x/GmailId/;

    my $newmsgid = MessageId::new();
    my $ret = $folder->appendMsgExtUIDL($msgdump, length($msgdump), $newmsgid, $uidl2);

    if ($ret) {

      print "Msg write success for $uidl -> $uidl2\n";
      unless ($flags && $folder->writeFlags($flags, $newmsgid)) {

        print "flag update failed\n";
      }
    }
    else {

      print "Msg write failed for $uidl -> $uidl2\n";
    }

    print "UIDL $i: " . $msgList->getUidlAt($i) . ' new  ' . $uidl2 . ' ' . $msgId->str() . "\n"; 
  }

  $mailbox->close();
}

###################### MAIN #########################

die "sudo $0 sid msSilo folder-name\n" if (scalar(@ARGV) < 3 );

my ($sid, $silo, $folder) = ($ARGV[0], $ARGV[1], $ARGV[2]);

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

print "The new user ID - $> process ID - $$\n";
print "Fetching UIDLs for $sid $silo $folder\n"; 

dumpUidls($sid, $silo, $folder);

