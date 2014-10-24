#!/home/y/bin/perl


use strict;
use warnings;
use Mail::IMAPClient;
use MIME::Base64;

my $emailId = 'gmailuser21@sso-test-test.sky.com';
my $consumer_key = 'sso-test-test.sky.com';
my $consumer_secret = 'g2mvQ7z8wzCOB/O6eTB1CNic';

my ($user, $domain) = split('@', $emailId);
my $requester_hdr = '?xoauth_requestor_id=' . $user . '%40' . $consumer_key;
my $url = "https://mail.google.com/mail/b/" . $emailId . '/imap/' . $requester_hdr;
print "URL ---- $url\n";

my $cmd = "\./oauth.py $emailId $consumer_key $consumer_secret $url 2>&1";

my $ret = qx/$cmd/;

if ($?) {

  print "Failed: $cmd with $ret\n";
}
else {

  print "$ret";
}

$ret =~ m/'(.*?)'/;
my $hdrs = $1;

my @fields = split(/,\s+/, $hdrs);
@fields = sort(@fields);

foreach my $field (@fields) {
  print "$field\n";
}
my $oauth_hdr = join(',', @fields);
# Remove OAuth realm=""
$oauth_hdr =~ s/OAuth realm="",//;
print "-----$oauth_hdr\n";

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

$client->authenticate('XOAUTH', sub { $xoauth_b64_encoded })
  or die "Could not authenticate: " . $client->LastError;

# Do something just to see that it's all ok
print "I'm authenticated\n" if $client->IsAuthenticated();
my @folders = $client->folders();
print join("\n* ", 'Folders:', @folders), "\n";

# Say bye
$client->logout();
