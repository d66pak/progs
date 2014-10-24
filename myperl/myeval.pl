#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

sub testarray($)
{
  my $arr = shift;
  print @$arr, "\n";

  my $i = 0;
  while ($i < @$arr) {
    print "@$arr[$i].--\n";
    #$i++;
  }
  continue {
    $i++;
  };
}

sub printSection($)
{
  my $section = shift;

  print "---- printSection ----\n";
  print "value: $section->{value}\n";
  print "pkgName: $section->{pkgName}\n";
  print "varName: $section->{varName}\n";
  print "-----------------------\n";
}


my @arry = qw(sun mon tue);
testarray(\@arry);

my $path = "/home/y/";
my $name = "config.xml";
my $fullPath = $path . $name;
my $fullcksum = $fullPath . ".cksum";

print "\n $fullPath \n";
print "\n $fullcksum \n";


my $fp = "config.conf";
my $content;

if (open(my $fh, "<", $fp)) {
  while (my $line = <$fh>) {
    $content .= $line;
  }
  close($fh);
}
else {
  die "Unable to open: $fp\n";
}

my $CONFIGSRV;
my $fallUidToUidl = undef;
eval $content;
if ($@) {
  die "Eval content failed\n";
}


my $cs = $CONFIGSRV;
print Dumper($cs), "\n";


my @p = @{$cs->{partners}};
#my @partners = @$p;
print $p[0], "\n";
print $cs->{partners}[0], "\n";
testarray($cs->{partners});

my $p1 = $p[0];
print "Partner 1: $p1\n";
my $frontier = $cs->{$p1};
my $udef = $cs->{somepartner};
unless (defined $udef) {

  print "--------- Nothing there ----------\n";
}
#my $frontier = $cs->{frontier};
my @yinstsets = @{$frontier->{yinstsets}};
printSection($yinstsets[0]);
print $yinstsets[0]{value}, "\n";
my $yinst_count = @yinstsets;
print "number of yinst set: $yinst_count\n";

$fallUidToUidl->{Sent}->{1} = '12345';
my $varref = \$fallUidToUidl;
$$varref->{Sentr}->{1} = '2345';
my $dump = Data::Dumper->Dump([$fallUidToUidl], [qw(fallUidToUidl)]);
#my $dump = Dumper($fallUidToUidl);
print $dump;

my $ts = time() . "_" . $$;
#my $fn = "/tmp/.info_dsync_" . $$ . "_" . $ts;
print "/tmp/.info_dsync_$ts\n";
