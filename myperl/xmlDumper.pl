#!/home/y/bin/perl

use strict;
use warnings;
use XML::Dumper;
use File::Basename;
use JSON;

use constant {

  #INTLDOMAINMAP       => '/etc/four11conf/intldomainmap',
 INTLDOMAINMAP       => 'intldomainmap',
 #PARTNERMAP          => '/etc/four11conf/partnermap',
 PARTNERMAP          => 'partnermap',
 TMPDIR              => './',
 SUCCESS             => 0,
 FAIL                => 1,
 INTLDOMAINMAP_ERROR => 2,
 PARTNERMAP_ERROR    => 3,
};

sub convertMap {

 my ($file) = @_;

 my $hashRef;
 unless ( $hashRef = do $file ) {

  return FAIL;
 }
 
 my $fileName = fileparse($file, qr/\.[^.]*/);
 my $xmlDumper = new XML::Dumper;
 $xmlDumper->dtd( TMPDIR . $fileName . ".dtd" );
 $xmlDumper->pl2xml( $hashRef, TMPDIR . $fileName . ".xml" );
 undef $xmlDumper;

 #my $json = JSON->new->allow_nonref;
 my $json = JSON->new;
 my $jsonStr = $json->encode( $hashRef );
 #my $jsonStr = $json->pretty->encode( $hashRef );
 open (my $J, ">", TMPDIR . $fileName . ".json");
 print $J $jsonStr;
 close $J;
 return SUCCESS;
}

########### MAIN ###############

my $ret;
$ret = convertMap(PARTNERMAP);
if ($ret) {

  return PARTNERMAP_ERROR;
}

$ret = convertMap(INTLDOMAINMAP);
if ($ret) {

 return INTLDOMAINMAP_ERROR;
}

