#!/home/y/bin/perl

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
use Yahoo::YCA::CertDB;
use JSON;

my $appId = 'yahoo.mail.reggate.app.beta';
#my $uri = 'http://hostname/extacct/v1/';
my $uri = 'http://jws100.mail.vip.ne1.yahoo.com/ws/extacct/v1/account/';

my $certDB = new Yahoo::YCA::CertDB;
my $cert = $certDB->get_cert($appId);

print "Cert: $cert\n";

#my $yahoo_app_auth_hdr = $certDB->append_cert($cert, $appId);

#print "Yahoo-App-Auth: $yahoo_app_auth_hdr\n";

  # Create the content to be sent
  my %extacct = (
    email => 'alpo_test01@exlab.corp.gq1.yahoo.com',
    type => 'imap',
#    port => '1101',
#    displayName => 'test',
#    server => 'imap.corp.yahoo.com',
#    ssl => 'true',
#    rootFolder => 'root',
  );

  my %contentHash = (
    yid => 'alpo_test01@exlab.corp.gq1.yahoo.com',
    extacct => \%extacct,
  );

  my $json = JSON->new->allow_nonref;
  my $json_content = $json->encode(\%contentHash);

print "Json content: " . $json_content . "\n";

my $cmd = 'POST';
my $req = HTTP::Request->new(
  $cmd => $uri,
  [ 'Yahoo-App-Auth' => $cert,
    'Content-Type' => 'application/json',
  ],
  $json_content,
);

print "Content: " . $req->content ."\n";
print $req->as_string;

my $ua = LWP::UserAgent->new;

my $resp = $ua->request($req);
print "------------CONTENT STR------------\n";
print $resp->as_string;
print "------------------------------------\n";
print "Contnet: " . $resp->content . "\n";

print "Status line: " . $resp->status_line . "\n";
print "Code: " . $resp->code . "\n";
print "Message: " . $resp->message . "\n";
if ($resp->is_success) {
  print "-----SUCCESS-----\n";
}
else {
  print "-----FAIL-----\n";
}
