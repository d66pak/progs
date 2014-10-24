#!/home/y/bin/perl

use warnings;
use strict;
use Getopt::Long;
use HTTP::Request::Common "GET";
use LWP::UserAgent;
use Digest::MD5  qw(md5 md5_hex md5_base64);
use Net::OAuth;
#require 5.6.0;

my $lwp_object = LWP::UserAgent->new;

my $user = 'gmailuser21';
my $consumer_key = 'sso-test-test.sky.com';
my $requester = $user.'@'.$consumer_key;
my $requester_hdr = '?xoauth_requestor_id='.$requester;
my $consumer_secret = 'g2mvQ7z8wzCOB/O6eTB1CNic';
my $url = "http://www.google.com/m8/feeds/contacts/default/full";
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
my $req = HTTP::Request->new(GET => $url . $requester_hdr);
$req->header('Content-type' => 'application/atom+xml');
$req->header('User-Agent' => 'fetchContacts/1.0 (gzip)');
$req->header('Accept-Encoding' => 'gzip');
$req->header('Authorization' => $request->to_authorization_header);
print $req->as_string();
my $response = $lwp_object->simple_request($req, "gmailuser1.resp");
#print $response->as_string; 
