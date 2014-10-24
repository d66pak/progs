#!/home/y/bin/perl

#
# Script to connect to a POP3 server
# using SASL authentication mechanism.
#

use strict;
use warnings;
use Data::Dumper;
use Net::POP3;
use Authen::SASL;

#
# Global variables
#

my $ADMIN_PASS = "AW3b4Pp0aJVcEX4x";
#my $POP_SERVER = 'z-lab.vip.frontiernet.net';
#my $POP_PORT = 110;
my $POP_SERVER = 'localhost';
my $POP_PORT = 30995;
my $AUTH_MECHANISM = 'PLAIN';
my $TIMEOUT = 5*60;
my $USER = $ARGV[0];
chomp($USER);
my $ADMIN_UID = 'api_ymig@frontier.com';


#
# Main
#

if (scalar(@ARGV) < 1) {

  die "Usage: $0 user_name\n";
}

print "Creating SASL object with params:\nmechanism => $AUTH_MECHANISM\nauthname => $USER\nuser => $ADMIN_UID\npass => ADMIN_PASS\n";

# Create SASL obj
my $sasl = Authen::SASL->new(
  mechanism => $AUTH_MECHANISM,
  debug => 0,
  callback => {
     authname => $USER,
     user => $ADMIN_UID,
     pass => $ADMIN_PASS,
  }
) || die "Cannot create SASL object\n";


print "Creating POP object with params:\nHost => $POP_SERVER\nPort => $POP_PORT\nTimeout => $TIMEOUT\n";
my $pop = Net::POP3->new(
  Host => $POP_SERVER,
  Port => $POP_PORT,
  Timeout => $TIMEOUT,
  Debug => 0,
) || die "Cannot connet to $POP_SERVER:$POP_PORT\n";

my $capa = $pop->capa() || die '$pop->capa() failed', "\n";

print "Capabilities:\n", Dumper($capa);

unless (scalar keys %$capa && exists $capa->{SASL}) {

   die "SASL mechanism not supported\n";
}

if (scalar keys %$capa && exists $capa->{SASL}) {

  print "Attempting with SASL auth...\n";

  unless ($pop->auth($sasl)) {
    die '$pop->auth($sasl) error: ', $pop->message();
  }

  print "Successfully logged into $POP_SERVER:$POP_PORT\n";

  my $listop = $pop->list() || die "list\n";

  print "List of messages in Inbox:\n", Dumper($listop);

  my $totalMsgs = $pop->_get_mailbox_count();
  print "Total msgs: $totalMsgs\n";

  my %msgidUidlHash;
  for (my $msgnum = 1; $msgnum <= $totalMsgs; $msgnum++) {

    my $uidl = $pop->uidl($msgnum) || die "uidl()\n";
    if (defined $uidl && $uidl ne '') {

      print "Msgnum: $msgnum => UIDL: $uidl\n";
    }

    my $hdrAref = $pop->top($msgnum) || die "top\n";

    my $msgid;
    foreach my $line (@$hdrAref) {

       if ($line =~ /^(Message-ID):\s+(<.*?>)/i) {

         $msgid = $2;
       }
    }

    if (defined $msgid && $msgid ne '') {

      $msgidUidlHash{$msgid} = $uidl;
    }
  }

  print "Msgid => UIDL Hash:\n", Dumper(\%msgidUidlHash);

  my $uidlHref = $pop->uidl() || die "uidl\n";

  print "List of uidls in Inbox:\n", Dumper($uidlHref);

#  foreach my $msgnum (keys %$uidlHref) {

#     my $hdrAref = $pop->top($msgnum) || die "top\n";

#     my $msgId;
#     foreach my $line (@$hdrAref) {

#        if ($line =~ /^(Message-ID):\s+(<.*?>)/i) {

#          $msgId = $2;
#        }
#     }

#  print "MsgNum: $msgnum Message-ID: $msgId\n";
#  }
}
else {

  print "$POP_SERVER:$POP_PORT does not support SASL auth\n";
}

$pop->quit();

