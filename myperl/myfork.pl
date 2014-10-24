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

# Global data

my $key = 'abcdefgh';
my $someBool = 1;

sub someFunction($$)
{
  my ($arg1, $arg2) = @_;

  print "In someFunction\narg 1: $arg1 arg 2: $arg2\n";
  print "Global data: $key $someBool\n";
  sleep (20);
  return (1, 1234);
}

sub forkChild($$)
{

  my ($arg1, $arg2) = @_;

  defined (my $kid = fork) or die "Cannot fork: $!\n";

  if ($kid) {

    print "Parent process: $$\nChild pid: $kid\n";
    my $ret = waitpid($kid, 0);
    print "Process: $ret exited with status: $?\n";
  }
  else {

    print "Child process....\n";
    my ($ret1, $ret2) = someFunction($arg1, $arg2);
    print "ret 1: $ret1 ret 2: $ret2\n";
    print "Child exiting......\n";
    exit 0;
  }
  print "Parent exiting......\n";
}


############## MAIN ###############
forkChild('arg 1', 2);
#forkChild('arg 2', 3);

