#!/home/y/bin/perl

use strict;
use warnings;

# Sleep time
my $sleep = 10;

####### MAIN ########

unless (defined $ARGV[0]) {

  die "Usage: $0 user_fail_list_file_name\n";
}

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

  my $cmd = "ls -l $userName.json_* | wc -l";
  my $ret = qx/$cmd/;
  my $jsons = int($ret);
  print "Number of JSON file to write:$jsons\n";

  my $count = 0;
  while ($count < $jsons) {

    # Check for any Non Ascii char
    $cmd = "./checkNonAscii.pl $userName.json_$count";
    $ret = qx/$cmd/;
    if ($ret ne "") {

      print "$ret\n";
      last;
    }

    # Write contacts to Y!
    print "Writing $userName.json_$count...\n";
    $cmd = "sudo ./pcore_prod_putSyncObject $userName.guid -np $userName.json_$count";
    $ret = qx/$cmd/;

    open(my $respFh, ">>", "$userName.resp_$count") or die "Error: not able to open $userName.resp_$count: $!";
    print $respFh $ret;
    close($respFh);

    # Check the status
    open(my $rFh, "<", "$userName.resp_$count") or die "$!";
    my $statusLine;
    foreach my $ln (<$rFh>) {

      chomp($ln);

      if ($ln =~ /HTTP\/1\.1/) {

        $statusLine = $ln;
      }
    }
    close($rFh);

    my @status = split / /, $statusLine;
    print "Status: $status[1] $status[2]\n";

    if ($status[1] ne "200" && $status[1] ne "202") {

      print "Warning: Not writing rest of the jsons...\n";
      last;
    }

    # Sleep for some time
    my $sl = 0;
    print "Sleeping";
    while ($sl < $sleep) {
      sleep(1);
      local $| = 1;
      print '.';
    }
    continue {$sl++;};
    print "\n";

  } # End of processing jsons in while loop
  continue {$count++;};


}

close($userFile);

