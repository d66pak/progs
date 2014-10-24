#!/home/y/bin/perl

use strict;
use warnings;

use Data::Dumper;
use MIME::Base64;
use Getopt::Long;

# Y! Mail modules
use YMRegister::MailMigrateUtil;

use Time::HiRes qw(gettimeofday tv_interval);

#select STDERR;

# Ignored folders
my @foldersIgnored = (
'[Gmail]/All Mail',
'[Gmail]/Important',
'[Gmail]/Starred',
'[Gmail]/Chats',
'[Gmail]/Bin',
'[Google Mail]/All Mail',
'[Google Mail]/Important',
'[Google Mail]/Starred',
'[Google Mail]/Chats',
'[Google Mail]/Bin',
'[GoogleMail]/All Mail',
'[GoogleMail]/Important',
'[GoogleMail]/Starred',
'[GoogleMail]/Chats',
'[GoogleMail]/Bin'
);

my $userListFileName;
my $localServer = 'localhost';
my $imapLocal = 31009;
my $popLocal = 31010;
my $imapServer = 'imap.gmail.com';
my $port = 993;
my $ssl = 0;
my $peek = 1;
my $popServer = 'pop.gmail.com';
my $popport = 995;
my $passwd = '';

# Retrieve all folders and its delimiters.
sub getAllFolders {
    my ($imap) = @_;

    my $listRef = $imap->list(undef, undef); # what if it returns undef?
    print "IMAP list returned undef\n" unless defined $listRef;
    return undef unless defined $listRef;
    my @list = @$listRef;

    #print Dumper($listRef);
    my @folders ;
    my $m;

    for ($m = 0; $m < scalar(@list); $m++ ) {
        if ($list[$m] && $list[$m]  !~ /\x0d\x0a$/ ) {
            $list[$m] .= $list[$m+1] ;
            $list[$m+1] = "";
            $list[$m] .= "\x0d\x0a" unless $list[$m] =~ /\x0d\x0a$/;
        }
        my $massageFolder = 0;

        if ($list[$m] =~
                /       ^\*\s+LIST               # * LIST
                        \s+\([^\)]*\)\s+         # (Flags)
                        (?:"[^"]*"|NIL)\s+       # "delimiter" or NIL
		      #bug 392802
                      #(?:"([^"]*)"|(.*))\x0d\x0a$  # Name or "Folder name"
                        (?:(.*))\x0d\x0a$  # Name
                /ix)
        {
            my $fdr = ($1||$2);
            my $tmpFdr = $1;
            # Remove duplicate forward slashes from LIST output
            $fdr =~ s/\\\\/\\/g;
            $massageFolder = 1 if $tmpFdr  and !$imap->exists($fdr) ;
            my $s = (split(/\s+/,$list[$m]))[3];
            my $sep = "NIL";
#print "folder= $fdr\n";
#print "s= $s\n";
            if (defined($s) && length($s) >= 3) {
                $sep =  ($s eq 'NIL' ? 'NIL' : substr($s, 1, length($s)-2) );
#print "sep= $sep\n\n";
            }
	    if ($massageFolder) {
              # print("skip $fdr\n");
	    }
	    else {
	      push @folders, $sep . " " . $fdr;
	    }

        }
    }

    # for my $f (@folders) { $f =~ s/^\\FOLDER LITERAL:://;}
    my @clean = (); my %memory = ();
    foreach my $f (@folders) { push @clean, $f unless $memory{$f}++ }

    return \@clean;
}

sub countFolders($) {
  my $folderAndSeps = shift;
  my $numFold = 0;
  my $sep = undef;
  my $folder = undef;

  foreach my $fs (@$folderAndSeps) {
    $fs =~  /(.*?)\s(.*)/;
    $sep = $1;
    $folder = $2;

    if (defined $sep && defined $folder) {
      ++$numFold;
    }
  }
  # subtract the number of folders we will not be migrating
  #$numFold = $numFold - scalar(@folderIgnore); 
  return $numFold;
}

sub openIMAPConnection {
  my ($imapId, $imapPasswd, $imapServer, $imapPort, $imapSSL, $imapPeek, $authScheme, $authCallBack) = @_;

  my @imapclient_options = (Uid => 1,
                            Timeout => 5*60,
                            User => $imapId,
                            Password => $imapPasswd,
                            Debug => 0,
                           );
  if (defined($imapPeek) && $imapPeek) {
         push @imapclient_options, ( Peek  => 1 );
  }

  if (!$imapSSL) {
    push @imapclient_options, ( Server => $imapServer,
                                Port => $imapPort);
  }

  # SASL authentication
  if (defined $authScheme && $authScheme eq 'PLAIN') {

          push @imapclient_options, ( Authmechanism => $authScheme,
                                      Authcallback  => $authCallBack);
  }

  my $imap = Mail::IMAPClient->new(@imapclient_options);
  if (!defined($imap)) {
         print( "failed to make new IMAPClient obj" );
         return undef;
  }

  if ($imapSSL) {
         my $where = "$imapServer:$imapPort";
         my $sock = new IO::Socket::SSL($where);
         if (!defined($sock)) {
                print( "failed to open SSL connection to $where" );
                return $imap;
         }

         $imap->Socket($sock);
         $imap->State(Mail::IMAPClient::Connected);

        # BFM: this is from some example code from Nick Burch by way of
        # Bill Tang.  Mail::IMAPClient needs to be coaxed into being logged
        # in if we pass it a socket, which we really want to do so it's
        # doing SSL.

        # Get the IMAP Server to the point of accepting a login prompt
        # Basically, we skip over the welcome messages until at the OK stage
         my ($code, $output) = ("","");
         until ( $code ) {
                $output = $imap->_read_line or return undef;
                for my $o (@$output) {
                  $imap->_debug("Connect: Received this from readline: ".
                                                         join("/", @$o)."\n");
                  $imap->_record($imap->Count,$o); # $o is a ref
                  next unless $o->[Mail::IMAPClient::TYPE] eq "OUTPUT";
                  ($code) = $o->[Mail::IMAPClient::DATA] =~ /^\*\s+(OK|BAD|NO)/i;
                }
         }
         # Did we get an OK welcome back?
         if ($code =~ /BYE|NO /) {
                print( "$code is BYE or NO" );
                $imap->State("Unconnected");
                return $imap;
         }

         # Now, have Mail::IMAPClient send the login for us
         unless ($imap->login) {
                print("login failed");
                return $imap;
         }
  }
  if (defined $authScheme && $authScheme eq 'XOAUTH') {

    unless ($imap->authenticate($authScheme, $authCallBack)) {

      print "failed to authenticate\n";
      return undef;
    }
  }
  return $imap;
}

# Close the IMAP connection gracefully.
sub closeIMAPConnection($) {
    my ($imap) = @_;
    my $ret = $imap->logout(); ## Mail::IMAPClient::logout closes socket
#     $logger->logInfo("IMAP connection closed");
    return $ret;
}

sub isFolderIgnored
{
  my ($folder) = @_;

  foreach my $f (@foldersIgnored) {

    if ($f eq $folder) {

      return 1;
    }
  }
  return 0;
}

sub getFolderDetails
{
  my ($imap) = @_;
  #print "I am authenticated..\n" if $imap->IsAuthenticated();

  my $gafTime = [gettimeofday];
  my $folderAndSeps = getAllFolders ($imap);
  print "getAllFolders -- " . tv_interval($gafTime) . "\n";
  #print "=================\n";
  #print Dumper($folderAndSeps);

  #my $numFolders = countFolders($folderAndSeps);
  #print "Number of folder: $numFolders\n";

  my %folderHash;

  foreach my $fs (@$folderAndSeps) {

    $fs =~  /(.*?)\s(.*)/;
    my $sep = $1;
    my $folder = $2;

    my $yFolder = undef;
    if ($folder =~ /^\"(.*?)\"/) {
      $yFolder = $1;
    } else {
      $yFolder = $folder;
    }

    if (isFolderIgnored($yFolder)) {

      # Skip ignored folders
      next;
    }

    print "\'$yFolder\',\n";

    my $count = $imap->message_count($folder);
    if (defined $count) {

      #print "Count: $count\n";
      $folderHash{$yFolder}->{count} = $count;
    }
    else {

      print "IMAP failed to find msg count\n";
    }

    my $selectTime = [gettimeofday];


    my $folderSelectOk = $imap->examine($folder);
    if (defined $folderSelectOk) {

      # Fetch sizes of each message
      $folderHash{$yFolder}->{size} = 0;
      my $hash = $imap->fetch_hash("RFC822.SIZE");
      foreach my $uid (keys %$hash) {

        $folderHash{$yFolder}->{size} += $hash->{$uid}->{'RFC822.SIZE'};
      }
      $hash = undef;
    }
    else {

      print "IMAP examine failed\n";
    }

    #print "-------------- Select time: " . tv_interval($selectTime) . "\n";
  }

  closeIMAPConnection($imap);


  print "\n";

  my $mboxSize = 0;
  my $mboxMsgs = 0;

  foreach my $fld (keys %folderHash) {

    my $size = 0;
    print "$fld\t" . $folderHash{$fld}->{count} . " msgs\t";
    if ($folderHash{$fld}->{size}) {

      $size = int($folderHash{$fld}->{size} / (1024 * 1024));
      if ($size) {

        print "$size MB\n";
      }
      else {

        $size = int($folderHash{$fld}->{size} / 1024);
        print "$size KB\n";
      }
    }
    else {

      $size = 0;
      print "$size MB\n";
    }
    $mboxSize += $folderHash{$fld}->{size};
    $mboxMsgs += $folderHash{$fld}->{count};
  }

  print "--------------------------------------\n";
  print "Total " . scalar(keys %folderHash) . " folders $mboxMsgs msgs, ";
  if ($mboxSize) {

    my $size = int($mboxSize / (1024 * 1024));
    if ($size) {

      print "$size MB to migrate\n";
    }
    else {

      $size = int($mboxSize / 1024);
      print "$size KB to migrate\n";
    }
  }
  else {

    print "$mboxSize MB to migrate\n";
  }

  #print Dumper(\%folderHash) . "\n";
}

sub getXOAUTHToken
{
  my ($emailId) = @_;
  #my $emailId = 'gmailuser21@sso-test-test.sky.com';
  #my $emailId = 'gmailuser8@sso-test-test.sky.com';
  #my $emailId = 'yahooadmin@sky.com';
  #my $emailId = 'gmailuser1@sso-test-test.sky.com';
  #my $consumer_key = 'sso-test-test.sky.com';
  #my $consumer_secret = 'g2mvQ7z8wzCOB/O6eTB1CNic';

  my $consumer_key = 'sky.com';
  my $consumer_secret = 'yajF3gQiidb1NZUmZqzWyvMy';

  my ($user, $domain) = split('@', $emailId);
  my $requester_hdr = '?xoauth_requestor_id=' . $user . '%40' . $consumer_key;
  my $url = "https://mail.google.com/mail/b/" . $emailId . '/imap/' . $requester_hdr;

  my $cmd = "/home/dtelkar/scripts/oauth.py $emailId $consumer_key $consumer_secret $url 2>&1";

  my $ret = qx/$cmd/;

  if ($?) {

    print "Failed: $cmd with $ret\n";
    return undef;
  }

  $ret =~ m/'(.*?)'/;
  my $hdrs = $1;

  my @fields = split(/,\s+/, $hdrs);
  @fields = sort(@fields);

  my $oauth_hdr = join(',', @fields);
  # Remove OAuth realm=""
  $oauth_hdr =~ s/OAuth realm="",//;

  my $xoauth_request = 'GET' . ' ' . $url . ' ' . $oauth_hdr;
  #print "xoauth string: " .  $xoauth_request . "\n";
  return encode_base64($xoauth_request, '');
}
########################################## MAIN ############################################

die "usage: $0 -f <user-list-file-name>\n" if (scalar @ARGV < 2);

GetOptions (
  'f=s' => \$userListFileName,
) or die "usage: $0 -f <user-list-file-name>\n";

open (my $fh, '<', $userListFileName) or die "Error opening $userListFileName: $!";

while (my $user = <$fh>) {

  chomp($user);

  print "--------------------------------------\n";
  print "$user\n\n";

  my $b64Encoded = getXOAUTHToken($user);
  unless (defined $b64Encoded) {

    print "ERROR generating XOAUTH token\n";
    next;
  }

  my $imap = openIMAPConnection($user, $passwd, $localServer, $imapLocal, $ssl, $peek, 'XOAUTH', sub{$b64Encoded});

  if (defined $imap) {

    getFolderDetails($imap);
  }
  else {

    print "IMAP Failed....\n";
    next;
  }
}




