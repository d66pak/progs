#!/home/y/bin/perl
use strict;
use warnings;
use Mail::IMAPClient;
use IO::Socket::SSL;
use Data::Dumper;

# Connect to the IMAP server via SSL and get rid of server greeting message
my $socket = IO::Socket::SSL->new(
   PeerAddr => 'imap.gmail.com',
   PeerPort => 993,
  )
  or die "socket(): $@";
my $greeting = <$socket>;
my ($id, $answer) = split /\s+/, $greeting;
die "problems logging in: $greeting" if $answer ne 'OK';

# Build up a client attached to the SSL socket and login
my $client = Mail::IMAPClient->new(
   Socket   => $socket,
   User     => 'gmailtestuser2@sky.com',
   Password => 'test1234',
  )
  or die "new(): $@";
$client->State(Mail::IMAPClient::Connected());
$client->login() or die 'login(): ' . $client->LastError();

# Do something just to see that it's all ok
print "I'm authenticated\n" if $client->IsAuthenticated();
my @folders = $client->folders();
print join("\n* ", 'Folders:', @folders), "\n";

$client->Uid(1);

my $msgInfoHash;
my $uidValidity;

$client->examine("INBOX") or die "Could not examine: $@\n";
$uidValidity = $client->uidvalidity('INBOX') or die "Could not uidvalidity: $@\n";
print "UID Validity: $uidValidity\n";
$msgInfoHash = $client->fetch_hash("UID", "FLAGS", "RFC822.SIZE", "BODY[HEADER.FIELDS (Subject)]");
print Dumper($msgInfoHash);
#$msgInfoHash = $client->flags(scalar($client->search("ALL")));
my @uids;
push @uids, (10, 11, 12, 5);
print Dumper(\@uids);
$msgInfoHash = $client->flags(\@uids);
print Dumper($msgInfoHash);

$client->examine("testfolder1") or die "Could not examine: $@\n";
$uidValidity = $client->uidvalidity('testfolder1') or die "Could not uidvalidity: $@\n";
print "UID Validity: $uidValidity\n";
$msgInfoHash = $client->fetch_hash("UID", "FLAGS", "RFC822.SIZE", "BODY[HEADER.FIELDS (Subject)]");
print Dumper($msgInfoHash);

# Say bye
$client->logout();
