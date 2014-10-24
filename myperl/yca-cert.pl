#!/home/y/bin/perl

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
use Yahoo::YCA::CertDB;

my $appId = 'yahoo.mail.farm.all.qa';
my $uri = 'http://hostname/extacct/v1/';

my $certDB = new Yahoo::YCA::CertDB;
my $cert = $certDB->get_cert($appId);

print "Cert: $cert\n";

#my $yahoo_app_auth_hdr = $certDB->append_cert($cert, $appId);

#print "Yahoo-App-Auth: $yahoo_app_auth_hdr\n";

my $cmd = 'POST';

my $req = HTTP::Request->new(
  $cmd => $uri,
  [ 'Yahoo-App-Auth' => $cert ],
  "some json content",
);

print $req->as_string;

print "Content: " . $req->content ."\n";

my $ua = LWP::UserAgent->new;

my $resp = $ua->request($req);
