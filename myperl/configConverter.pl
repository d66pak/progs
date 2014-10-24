#!/home/y/bin/perl

use strict;
use warnings;
use File::Basename;
use JSON;

use constant {

  #INTLDOMAINMAP       => '/etc/four11conf/intldomainmap',
  INTLDOMAINMAP       => 'intldomainmap',
  #PARTNERMAP          => '/etc/four11conf/partnermap',
  PARTNERMAP          => 'partnermap',
  #TMPDIR              => '/home/y/conf/reggate_web_app/',
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

  my $fileName = fileparse ($file, qr/\.[^.]*/);

  my $jsonStr = JSON->new->allow_nonref->pretty->encode( $hashRef );
  if ( open (my $J, ">", TMPDIR . $fileName . '.json_') ) {

    print $J $jsonStr;
    close $J;
  } else {

    return FAIL;
  }

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

