#!/home/y/bin/perl

use warnings;
use strict;


# Change the effective UID to nobody2
# This is required so that the mailbox is created with the owner as nobody2
print "The user ID of the process is - $>\n";
print "About to change the user ID to nobody2 ...\n";

$> = 60001;

if ( $! ) {
    print "Unable to change the user ID to nobody2 .. Aborting ...\n";
    print "Details of errors: $!\n";

    exit 1;
}

print "The new user ID of the process is - $>\n";

my $cmd = 'ulimit -a';

my $ret = qx/$cmd/;

if ($?) {

  print "Failed: $ret\n";
}
else {

  print $ret;
}

sleep (30);

print "Exiting........\n";
