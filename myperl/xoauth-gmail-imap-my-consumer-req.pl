#!/home/y/bin/perl
use strict;
use warnings;
use Mail::IMAPClient;
use IO::Socket::SSL;
use Digest::MD5  qw(md5 md5_hex md5_base64);
use Net::OAuth;
use HTTP::Request::Common "GET";
use MIME::Base64;
use Data::Dumper;
use ConsumerRequest;

my $user = 'gmailuser21';
my $consumer_key = 'sso-test-test.sky.com';
my $requester = $user.'@'.$consumer_key;
my $requester_hdr = '?xoauth_requestor_id=' . $user . '%40' . $consumer_key;
my $consumer_secret = 'g2mvQ7z8wzCOB/O6eTB1CNic';
my $url = "https://mail.google.com/mail/b/" . $requester . '/imap/' . $requester_hdr;
print "URL ---- $url\n";
my $time = time;
my $nonce = md5_hex("nonce_key".$time);

my $request = Net::OAuth->request('consumer')->new(
  consumer_key => $consumer_key,
  consumer_secret => $consumer_secret,
  request_url => $url,
  signature_method => 'HMAC-SHA1',
  request_method => 'GET',
  timestamp => $time,
  nonce => $nonce,
  extra_params =>  {
    xoauth_requestor_id => $requester,
  },
);
$request->sign;

my $oauth_hdr = $request->to_authorization_header;
$oauth_hdr =~ s/^OAuth //;
my $xoauth_request = 'GET' . ' ' . $url . ' ' . $oauth_hdr;
print "xoauth string: " .  $xoauth_request . "\n";

my $xoauth_b64_encoded = encode_base64($xoauth_request, '');

# Build up a client attached to the SSL socket and login
my $client = Mail::IMAPClient->new(
  Server   => 'imap.gmail.com',
  Ssl      => 1,
  User     => 'gmailuser21@sso-test-test.sky.com',
  Port     => 993,
  Debug    => 1,
)
  or die "new(): $@";

#$client->State(Mail::IMAPClient::Connected());

$client->authenticate('XOAUTH', sub { $xoauth_b64_encoded })
  or die "Could not authenticate: " . $client->LastError;

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
