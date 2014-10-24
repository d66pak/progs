#!/home/y/bin/perl

use warnings;
use strict;
use LWP::UserAgent;
use HTTP::Request::Common;
use URI;
use Net::OAuth;

sub consumer_key { 'sso-test-test.sky.com' }
sub consumer_secret { 'g2mvQ7z8wzCOB/O6eTB1CNic' }
sub username { 'gmailuser1' }
sub url { 'http://www.google.com/calendar/feeds/default/allcalendars/full'; }


my $oauth_request =
        Net::OAuth->request('consumer')->new(
          consumer_key => consumer_key(),
          consumer_secret => consumer_secret(),
          request_url => url(),
          request_method => 'GET',
          signature_method => 'HMAC-SHA1',
          timestamp => time,
          nonce => nonce(),
          extra_params => {
            'xoauth_requestor_id' => username() . '@' . consumer_key(),
          },
        );


$oauth_request->sign;

my $req = HTTP::Request->new(GET => url() . '?xoauth_requestor_id='
                            . username() . '@' . consumer_key());
$req->header('Content-type' => 'application/atom+xml');
$req->header('Authorization' => $oauth_request->to_authorization_header);

print $req->as_string;

my $ua = LWP::UserAgent->new;
my $oauth_response = $ua->simple_request($req);

print $oauth_response->as_string;

sub nonce {
  my @a = ('A'..'Z', 'a'..'z', 0..9);
  my $nonce = '';
  for(0..31) {
    $nonce .= $a[rand(scalar(@a))];
  }

  $nonce;
}
