#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

sub somefunction($)
{
  my ($Href) = @_;

  print "somefunction: \n", Dumper($Href);

  print "Number of keys: ", scalar(keys(%$Href)), "\n";

  $Href->{23261} = 101;
  $Href->{101} = 202;

  foreach my $key (keys(%$Href)) {

    print "$key => $Href->{$key}\n";
  }

  my %testhash;
  return undef;
}

sub functionB($)
{
  my ($maprefref) = @_;
  print "functionB Before...\n";
  print Dumper($maprefref);
  $$maprefref->{23261} = '0000000100005add';
  print "functionB After...\n";
  print Dumper($maprefref);
}

sub functionA($)
{

  my ($maprefref) = @_;
  print "functionA Before...\n";
  print Dumper($maprefref);
  functionB($maprefref);
  print "functionA After...\n";
  print Dumper($maprefref);
}

my %UidToUidl = (
    23261 => '0000000100005add',
    24000 => '0000000100005dc0',
    23020 => '00000001000059ec',
    21044 => '0000000100005234',
    24600 => '0000000100006018',
    24800 => '00000001000060e0',
    23141 => '0000000100005a65',
    20220 => '0000000100004efc',
    22100 => '0000000100005654',
    23160 => '0000000100005a78',
    21042 => '0000000100005232'
);


$Data::Dumper::Indent = 3;

print "Uid = Uidl:\n";
print Dumper(\%UidToUidl);

my %fallUidToUidl = ();
my $folder = "Inbox";
$fallUidToUidl{$folder} = \%UidToUidl;

print "%fallUidToUidl:\n";
print Dumper(\%fallUidToUidl);

my $inboxUidToUidl = $fallUidToUidl{Inbox};
print "inboxUidToUidl\n";
print Dumper($inboxUidToUidl);


foreach my $uid (keys %$inboxUidToUidl) {

  print "Uid: $uid\n";

}

my $unknownUidl = $inboxUidToUidl->{1};

unless (defined $unknownUidl and $unknownUidl ne "") {

  print "Uidl: 1 not found\n";
}

$inboxUidToUidl->{10} = "1234";
$inboxUidToUidl->{22100} = "1234";

print "inboxUidToUidl\n";
print Dumper($inboxUidToUidl);

print "%fallUidToUidl:\n";
print Dumper(\%fallUidToUidl);

print "Uid = Uidl:\n";
print Dumper(\%UidToUidl);

my $uidlLine = '+OK 1 260.AaQHlgPJSblcDcr+HSCRTj86i48=
';

print "uidl line: $uidlLine";

$uidlLine =~ s/\r//g;
$uidlLine =~ s/\n//g;
my @fields = split /\s+/, $uidlLine;
my $uidl = $fields[2];

print "uild: $uidl\n";

my $testHref = somefunction(\%UidToUidl);
print "testHref is not empty\n" if (scalar keys %$testHref); 

print Dumper(\%UidToUidl);


my %tempMap01 = ();
print "tempMap01 is empty\n" unless (scalar keys %tempMap01);
my %tempMap02 = (24000 => '0000000100005dc0');
print "tempMap02 is empty\n" unless (scalar keys %tempMap02);
#my $tempMapRef = \%tempMap02;
my $tempMapRef = undef;
print "Before...\n";
print Dumper($tempMapRef);
functionA(\$tempMapRef);
print "After...\n";
print Dumper($tempMapRef);

print "tempMapRef is defined....\n" if (defined $tempMapRef) ;


my %updateFlagsMap = ();

$updateFlagsMap{Inbox} = \%UidToUidl;

print Dumper(\%updateFlagsMap);

print "23141 = " . $updateFlagsMap{Inbox}{23141} . "\n";
print "23141 exists\n" if (exists $updateFlagsMap{Inbox}{23141});
print "23 exists\n" if (exists $updateFlagsMap{Inbox}{23});
$updateFlagsMap{Inbox}{23} = '0000111222444';
print "23 exists\n" if (exists $updateFlagsMap{Inbox}{23});

$updateFlagsMap{Draft}{23} = '0000111222444';
print Dumper(\%updateFlagsMap);

foreach my $folder (keys %updateFlagsMap) {

  print "Folder Name: $folder\n";
  #print "Count: " . scalar(keys(%($updateFlagsMap{$folder}))) ."\n";
}

my $tempHash = $updateFlagsMap{Inbox};
print "Count: " . scalar(keys(%$tempHash)) . "\n";


my $flagsMap = {
  'Inbox' => {
    '118682' => [
    '()'
    ],
    '118660' => [
    '()'
    ],
    '118620' => [
    '\\Seen'
    ],
    '118680' => [
    '()'
    ],
    '118640' => [
    '()'
    ],
    '118681' => [
    '()'
    ],
    '118641' => [
    '()'
    ]
  },
  'Draft' => {
    '116300' => [
    '\\Draft',
    '\\Seen'
    ]
  },
};

print Dumper($flagsMap);

foreach my $fn (keys %$flagsMap) {

  my $idFlagsMap = $flagsMap->{$fn};
  foreach my $id (keys %$idFlagsMap) {

    my $flagsArray = $idFlagsMap->{$id};
    foreach my $f (@$flagsArray) {

      print "$f\n";
      print "blank\n" if ($f eq '()'); 
    }
  }
}

# Cleanup
#%$flagsMap = ();
#undef %$flagsMap;

#delete @$flagsMap{keys %$flagsMap};
#undef $flagsMap;

my $buf = 'asdfkjadslkjfajkldasfjaklfsklakkkkkkkkkkkkkkkkk
asdfakkkkkkkkkkkkkkkkkkkkkkkasdfkkkkkkkkkkkkkkkkkkkkkkkkkkl
asdfkhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhha
adfuqwheusdjkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkjaklsd
asdkjfhklasssssssssssssssssvklcmaslkjdlkjfldksjafkljadslkjf
asdfakkkkkkkkkkkkkkkkkkkkkkkasdfkkkkkkkkkkkkkkkkkkkkkkkkkkl
asdfkhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhha
adfuqwheusdjkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkjaklsd
asdkjfhklasssssssssssssssssvklcmaslkjdlkjfldksjafkljadslkjf
asdfakkkkkkkkkkkkkkkkkkkkkkkasdfkkkkkkkkkkkkkkkkkkkkkkkkkkl
asdfakkkkkkkkkkkkkkkkkkkkkkkasdfkkkkkkkkkkkkkkkkkkkkkkkkkkl
asdfakkkkkkkkkkkkkkkkkkkkkkkasdfkkkkkkkkkkkkkkkkkkkkkkkkkkl
asdfkhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhha
adfuqwheusdjkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkjaklsd
asdkjfhklasssssssssssssssssvklcmaslkjdlkjfldksjafkljadslkjf
asdfakkkkkkkkkkkkkkkkkkkkkkkasdfkkkkkkkkkkkkkkkkkkkkkkkkkkl
asdfkhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhha
adfuqwheusdjkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkjaklsd
asdkjfhklasssssssssssssssssvklcmaslkjdlkjfldksjafkljadslkjf
asdfkhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhha
adfuqwheusdjkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkjaklsd
asdkjfhklasssssssssssssssssvklcmaslkjdlkjfldksjafkljadslkjf
asdfakkkkkkkkkkkkkkkkkkkkkkkasdfkkkkkkkkkkkkkkkkkkkkkkkkkkl
asdfkhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhha
adfuqwheusdjkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkjaklsd
asdkjfhklasssssssssssssssssvklcmaslkjdlkjfldksjafkljadslkjf
asdfkhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhha
adfuqwheusdjkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkjaklsd
asdkjfhklasssssssssssssssssvklcmaslkjdlkjfldksjafkljadslkjf
asdfakkkkkkkkkkkkkkkkkkkkkkkasdfkkkkkkkkkkkkkkkkkkkkkkkkkkl
asdfkhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhha
adfuqwheusdjkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkjaklsd
asdkjfhklasssssssssssssssssvklcmaslkjdlkjfldksjafkljadslkjf';

#undef $buf;

my @buffArray = ();

for (my $i = 0; $i < 5; ++$i) {

  push (@buffArray, $buf);
}

my $buffArrayRef = \@buffArray;

my $tempBuf = $$buffArrayRef[0];

my %myFlagsMap = (
  Inbox => {
    1234 => 'avch',
    3457 => 'adkl',
  },
);
$myFlagsMap{Inbox}->{deletedFolder} = 1;
print Dumper(\%myFlagsMap);


my $arrRef = ();
my %someMap = map { $_ => 1 } @{$arrRef};
print Dumper(\%someMap);

#my $flagStr = "\\Seen \\Deleted   \\Draft";
my $flagStr = '   ';
#my @flagAr = split(' ', $flagStr);
my @flagAr = ();
print "flagAr defined\n" if (defined \@flagAr);
print Dumper(\@flagAr);

sleep(2);

my @smallArray = ('abc', 'def', 'gh');
my ($one, $two, $three, $four) = @smallArray;
print "$one $two $three $four\n";
@smallArray = undef;
