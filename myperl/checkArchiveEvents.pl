#!/home/y/bin/perl

use strict;
use warnings;
use DateTime;
use Sys::Hostname;
use File::Path;

use constant {

 NEWQPATH    => '/home/rocket/ms1/external/accessMail/free_archive_mig/new/',
 DESTFARM    => 1953,
 PARTNER     => 'free',
 TYPE        => 'none',
 CDONE       => 'CRAWL.DONE',
 CFAIL       => 'CRAWL.FAIL',
 CPROCESSING => 'CRAWL.DONE.PROCESSING',
 CPROCESSED  => 'CRAWL.DONE.PROCESSED',
 MDONE       => 'MIGRATION.DONE',
 MFAILED     => 'MIGRATION.FAILED',
 MSTATS      => 'MIGRATION.STATS',
 MPASS       => 'MIGRATION.PASS',
};

sub usage {
 print "Usage: $0 user-list-file-name\n";
}

sub getFarmSid {
 my ($yid) = @_;

 my $cmd = "udb-test -Rk sid $yid 2>&1";

 my $ret = qx/$cmd/;
 chop($ret);
 chop($ret);

 if ($?) {

  return ( undef, undef );
 } else {

  if ( $ret =~ m/=sid=(\w{1,10})\ca(\w{1,32})/ ) {

   return ( $1, $2 );
  }
  return ( undef, undef );
 }
}

sub isMboxOnThisFarm {
 my ( $farm, $sid ) = @_;

 my $host = hostname;

 if ( $host =~ m/web$farm/ ) {

#  my $cmd = "/home/y/bin/fmbox.sh $sid";
#  my $ret = qx/$cmd/;
#  chop($ret);
#
#  if ($?) {
#
#   return 0;
#  } else {
#
#   if ( $ret =~ /account\s+not\s+found/ ) {
#
#    return 0;
#   }
#  }
  return 1;
 }
 return 0;
}

sub checkArchiveEvent {
 my ($user) = @_;

 my @email = split( /@/, $user );

 my $yid = $email[0];

 my ( $farm, $sid ) = getFarmSid($yid);

 print "$user\t";

 unless ( defined $farm && defined $sid ) {

  print "ERROR Cannot find farm and sid!\n";
  return;
 }

 unless ( isMboxOnThisFarm( $farm, $sid ) ) {

  print "ERROR Mbox $farm not in this farm!\n";
  return;
 }
 
 my @digits = split( //, $sid );
 my $dir1   = $digits[-1] . $digits[-2];

 my $fullPath  = NEWQPATH . $dir1 . '/' . $sid . '/';
 my $eventPath = $fullPath . 'EVENT';
 if ( -e $eventPath ) {

  print "$fullPath\t";
  
  my ($crawlpass, $crawlfail, $processing, $processed, $migdone, $migfail, $migpass) = (0);
  # crawl successful
  $eventPath = $fullPath . CDONE;
  if ( -e $eventPath ) {

   #print "crawl-pass\t";
   $crawlpass = 1;
  }

  # crawl fail
  $eventPath = $fullPath . CFAIL;
  if ( -e $eventPath ) {

   #print "CRAWL-FAIL\t";
   $crawlfail = 1;
  }

  # archiver
  $eventPath = $fullPath . CPROCESSING;
  if ( -e $eventPath ) {

   #print "arch-processing\t";
   $processing = 1;
  }
  $eventPath = $fullPath . CPROCESSED;
  if ( -e $eventPath ) {

   #print "arch-processed\t";
   $processed = 1;
  }

  # migration
  $eventPath = $fullPath . MDONE;
  if ( -e $eventPath ) {

   #print "mig-done\t";
   $migdone = 1;
  }
  $eventPath = $fullPath . MFAILED;
  if ( -e $eventPath ) {

   #print "MIG_FAIL\t";
   $migfail = 1;
  }
  $eventPath = $fullPath . MPASS;
  if ( -e $eventPath ) {

   #print "MIG_PASS\t";
   $migpass = 1;
  }
  
  if ($crawlfail) {
   
   # crawl failed
   print "CRAWL-FAIL\t";
  }
  elsif ($processing) {
   
   # processing
   print "processing\t";
  }
  elsif ($crawlpass && $migpass) {
   
   # crawl passed and mig pass (when there are zero msgs to fetch)
   print "processed-pass-0-msgs\t";
  }
  elsif ($processed && $migpass) {
   
   # processed with all success
   print "processed-with-success\t";
  }
  elsif ($processed && $migdone && $migfail) {
   
   # crawl passed and processed but some errors
   print "processed-with-errors\t";
  }
  elsif ($processed && $migfail) {
   
   # crawl passed and processed but some errors
   print "processed-with-errors\t";
  }
  elsif ($crawlpass && !$migdone && !$migfail && !$migpass) {
   
   # yet to be processed
   print "yet-to-be-processed\t";
  }
  else {
   
   print "UNKNOWN\t";
  }

 } else {

  print "ERROR Archive event not present!\t";
 }


 # Stats
 my $fh;
 $eventPath = $fullPath . MSTATS;
 if ( open( $fh, '<', $eventPath ) ) {

  my ( $msgCount, $totalSize, $totalTime, $host );
  while ( my $line = <$fh> ) {

   chomp($line);

   if ( $line =~ m/Total successful mails: (\d+) Total size: (\d+)/ ) {

    $msgCount  = $1;
    $totalSize = $2;
   }
   if ( $line =~ m/Time to fetch messages: (\d+) ms/ ) {

    $totalTime = $1;
   }
   if ( $line =~ m/(web.+?yahoo\.com)/ ) {

    $host = $1;
   }
  }

  if (    defined $msgCount
       && defined $totalSize
       && defined $totalTime
       && defined $host )
  {

   # Convert to KB
   #$totalSize /= 1024;
   my $downloadRatePerSec =
     ( $totalSize > 0 ) ? ( $totalSize / ( $totalTime / 1000 ) ) : 0;
   printf(
"Downloaded msgs: %d; Downloaded size: %d KB; Time taken: %d ms; Download Rate: %.2f KB/sec; Host: %s",
    $msgCount, $totalSize, $totalTime, $downloadRatePerSec, $host );
  }
  close($fh);
 }

 print "\n";
}

########## MAIN ############
#
#

while ( my $user = <> ) {

 chomp($user);
 checkArchiveEvent($user);
}

