package ExecRemoteCmd;

use strict;
use warnings;
use Net::SSH::Expect;

our $VERSION = 1.00;

sub new
{
  my ($class, %arg) = @_;

  my $self = {
    _user => $arg{user} || $ENV{'USER'},
    _password => $arg{password},
    _host => $arg{host},
    _timeout => $arg{timeout} || 10,
    _logfh => $arg{logfilehandle},
  };

  bless ($self, $class);
}

sub runCommand
{
  my ($self, $cmd) = @_;

  # Making an ssh connection with user-password authentication
  my $ssh = Net::SSH::Expect->new (
    host => $self->{_host}, 
    password=> $self->{_password}, 
    user => $self->{_user}, 
    timeout => $self->{_timeout},
    raw_pty => 1,
    no_terminal => 1
  );

  # logon to the SSH server using those credentials
  my $login_output = $ssh->login(1);

  # test the login output to make sure we had success
  #if ($login_output !~ /Copyright/) {
  #  die "Login has failed. Login output was $login_output";
  #}

  # - now you know you're logged in - #

  # Run command using send
  $ssh->send($cmd);
  my $line;
  my $fh = $self->{_logfh};
  while ( defined ($line = $ssh->read_line()) ) {

    if (defined $fh) {

      print $fh $line . "\n";
    }
    else {

      print $line . "\n";
    }
  }

  # closes the ssh connection
  $ssh->close();
}

1;

