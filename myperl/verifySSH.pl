#! /home/y/bin/perl

use strict;
use warnings;

sub runCmd {

 my ($cmdFile) = @_;

 my $cmd = "yinst-pw sh -x $cmdFile | tee $cmdFile\.out";

 qx/$cmd/;
}

############# MAIN ##############

my $tmpFileName = "/tmp/test-ssh-$$-cmd";

my @failedHosts;
while ( my $host = <> ) {

 chomp($host);
 push @failedHosts, $host;
}

while ( scalar(@failedHosts) > 0 ) {

 open( my $cmdFH, '>', $tmpFileName ) or die "Error opening $tmpFileName: $!";

 foreach my $host (@failedHosts) {

  my $sshTestCmd =
    "yinst ssh -print-hostname -continue_on_error -h $host \"date\"";
  print $cmdFH "$sshTestCmd\n";
 }
 
 # clear the failed hosts
 undef (@failedHosts);

 close($cmdFH);

 runCmd($tmpFileName);
 
 open( my $rFH, '<', "$tmpFileName\.out" )
   or die "Error opeinig $tmpFileName\.out: $!";

 while ( my $line = <$rFH> ) {

  chomp($line);

  if ( $line =~ m/Unable to ssh successfully to (web.*?\.yahoo\.com)/ ) {

   push @failedHosts, $1;
  }
 }
 
 close ($rFH);

}

