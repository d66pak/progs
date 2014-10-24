#!/home/y/bin/perl

use strict;
use warnings;




####### MAIN ########

unless (defined $ARGV[0]) {

  die "Usage: $0 user_fail_list_file_name\n";
}

# Find guid for all the users
#my $fillGuidCmd = "sudo ./fillguid.pl $ARGV[0]";
#my $ret = qx/$fillGuidCmd/;
#print "Created ulist.guid file\n";

open(my $userFile, "<", $ARGV[0]) or die "Error: not able to open $ARGV[0]: $!";


while (my $line = <$userFile>) {

  chomp($line);

  my $userName;
  if ($line =~ /(\w+)@/) {

    $userName = $1;
  }
  else {

    die "Error: Invalid user- $line\n";
  }

  print "--------------- Processing: $line ---------------\n";

  print "Fetching GUID...\n";
  open (my $guidFh, ">", "$userName.guid") or die "Error creating $userName.guid file: $!";
  my $guidCmd = "udb-test -Rk mbr_guid $line";
  my $ret = qx/$guidCmd/;

  if ($?) {

    print "ERROR! fetching GUID for $line\n";
  }
  else {

    if ($ret =~ /GUID\cb(\w{1,32})/) {

      print $guidFh "$line $1\n";
      print "$line $1\n";
      print "Created: $userName.guid\n";
    }
    else {

      print "ERROR! fetching GUID for $line\n";
    }
  }

  close($guidFh);

  print "Fetching Frontier contacts...\n";

  my $fetchCmd = "sudo ./getContacts.php $line > $userName.xml";

  $ret = qx/$fetchCmd/;

  unless (-s "$userName.xml") {

    die "Error: Fetch failed for $line\n";
  }

  print "Created: $userName.xml\n";

  print "Running xlator...\n";

  my $xlatorCmd = "./xlator $userName.xml > $userName.tmp";

  $ret = qx/$xlatorCmd/;

  unless (-s "$userName.tmp") {

    die "Error: Xlator failed for $line\n";
  }

  print "Created: $userName.tmp\n";

  # Open tmp file
  open(my $tmpFile, "<", "$userName.tmp") or die "Error opening $userName.tmp: $!";
  my $data = do {local $/; <$tmpFile>};
  close($tmpFile);

  if ($data =~ /Total number of contacts: (\d+)/) {

    print "Total number of contacts: $1\n";
  }

  my $chunks = 0;

  if ($data =~ /Total number of request chunks: (\d+)/) {

    print "Total number of request chunks: $1\n";
    $chunks = $1;
  }

  # Find all the chunks and create separate json files

  my $count = 0;
  while ($count < $chunks) {

    if ($data =~ /\bCHUNK$count\b (.*)\n/) {

      open(my $jsonFile, ">", "$userName.json_$count") or die "Error opening $userName.json_$count: $!";
      print $jsonFile $1;
      close($jsonFile);

      print "Created: $userName.json_$count\n";

      # Check for non ascii characters
      if ($1 =~ /[^[:ascii:]]/) {

        print "WARNING!!! Found non ascii characters in $userName.json_$count\n";
      }
    }
    else {

      print "Error: Not able to find CHUNK$count\n";
    }
  }
  continue {$count++;};

}

close($userFile);
