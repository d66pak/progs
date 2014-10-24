#!/home/y/bin/perl

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
use URI;


sub execHTTPRequest($$$$)
{
  my ($lcmd, $luri, $lhdrs, $lcontent) = @_;

  my $req = HTTP::Request->new(
    $lcmd => $luri,
    $lhdrs,
    $lcontent,
  );

  print $req->as_string;

#=begin comment
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
#=end comment
#=cut
}

my $uri = URI->new("http://mrs01.mail.sp1.yahoo.com/lca/report");
my $cmd = 'GET';
#my @headers = ('Content-Type' => 'application/text', 'Content-Length' => 0);
my @headers;
my $content;
my $partner = 'sky';
my $moduleName = 'reggate';
my $rc = 1;
my $user = 'testskyuser@sky.com';
my $isSepLog = 'true';
my $msg = 'some log message';

$uri->query_form(uid => $user,
  app => $moduleName,
  partner => $partner,
  rc => ($rc == 0) ? 'S' : 'F',
  seplogfile => $isSepLog,
  fs => 'Sky ' . $msg);

print "URI == " . $uri->as_string . "\n";
#'&seplogfile=' . $isSepLog .
#my $queryString = 'partner=' . $partner . '&app=' . $moduleName . '&rc=' . $rc . '&uid=' . $user . '&fs=' . uri_escape($msg);
#$uri = $uri . '?' . $queryString;

#print "URI: $uri\n";

execHTTPRequest($cmd, $uri->as_string, undef, undef);
