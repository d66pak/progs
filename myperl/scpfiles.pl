#!/home/y/bin/perl

use strict;
use warnings;
use Term::ReadPassword;
use Getopt::Long;
use Net::SCP::Expect;

my $hostfile;
my @files;

sub usage()
{
  print "Usage:\n";
  print "$0 -h hostfile -f file1,file2\n"
}

die usage() unless @ARGV == 4;
GetOptions('h=s' => \$hostfile, 'f=s' => \@files) or die usage();

@files = split(/,/, join(',', @files));


open (my $HF, "<", $hostfile) or die "Cannot open $hostfile:$!";

my $passwd = read_password('password: ');

my $scp = Net::SCP::Expect->new(
  user=>'dtelkar',
  password=>$passwd,
  auto_yes=>1,
  timeout_auto=>15
);

#$scp->login('dtelkar', $passwd);
$scp->auto_yes(1);

unless (defined $scp) {

  print "Net::SCP::Expect creation failed\n";
  die;
}

while (my $hostname = <$HF>) {

  chomp ($hostname);

  print "-----------------\n";
  print "Host: $hostname\n";

  $scp->host($hostname);

#  foreach my $file (@files) {

#    print "File: $file\n";
#    $scp->scp($file, '~/');
#  }

  my $fileList = join(' ', @files);
  print "Files: $fileList\n";
  $scp->scp($fileList, '~/');
}

close ($HF);
