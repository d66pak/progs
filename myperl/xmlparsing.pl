#!/usr/bin/perl
# xmlparsing.pl

use warnings;
use strict;
use XML::LibXML;
use XML::Simple;
#use XML::Simple::DTDReader;


my $dtd_file = "/Users/dtelkar/Deepak/Yahoo/progs/perl/test_xml/registration.dtd";
my $configfile = "/Users/dtelkar/Deepak/Yahoo/progs/perl/test_xml/registration.xml";


my $parser = XML::LibXML->new();
#$parser->validation(0);
#$parser->line_numbers(1);

eval {
  if (open (my $conf_fh, "<", $configfile) ) {
    my $doc = $parser->parse_fh($conf_fh);
    open (my $dtd_fh, "<", $dtd_file) or die "Error opening DTD file! \n";
    local $/ = undef;
    my $dtd_str = <$dtd_fh>;
    my $dtd = XML::LibXML::Dtd->parse_string($dtd_str);
    $doc->validate($dtd);
    close($dtd_fh);
    close($conf_fh);


    #my $dtdRdr = XML::Simple::DTDReader->new;
    #$dtdRdr->XMLin($configfile);
  }
  else {
    print "Error opening config file \n";
  }
};

if ($@) {
  print "Parsing failed with error: \n";
  print $@;
}
else {
  print "Parsing success! \n";
}
