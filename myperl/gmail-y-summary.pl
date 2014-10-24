#!/home/y/bin/perl

use strict;
use warnings;

use Data::Dumper;
use MIME::Base64;
use Getopt::Long;

# Y! Mail modules
use YMRegister::MailMigrateUtil;

use Time::HiRes qw(gettimeofday tv_interval);

use File::Find ();
# for the convenience of &wanted calls, including -eval statements:
use vars qw/*name *dir *prune/;
*name   = *File::Find::name;
*dir    = *File::Find::dir;
*prune  = *File::Find::prune;

#select STDERR;

# Ignored folders
my @foldersIgnored = (
'[Gmail]/Important',
'[Gmail]/Starred',
'[Gmail]/Chats',
'[Gmail]/Bin',
'[Google Mail]/Important',
'[Google Mail]/Starred',
'[Google Mail]/Chats',
'[Google Mail]/Bin',
'[GoogleMail]/Important',
'[GoogleMail]/Starred',
'[GoogleMail]/Chats',
'[GoogleMail]/Bin'
);

my %folderMap = (
  'INBOX' => 'Inbox',
  '[Gmail]/Drafts'=> 'Draft',
  '[Gmail]/Sent Mail'=>  'Sent',
  '[Gmail]/Trash' =>  'Trash',
  '[Gmail]/Spam' =>  '@B@Bulk',
);

my %folderCharMap = (
  '[@#$%&*?\/;\'\":\[\]{}<>|\\\~]' => '-',
  '[\000]' => '-',
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

my $emailId;
my %gmailFolderHash;
my %yFolderHash;
my $FH;

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

sub getGmailFolderDetails
{
  my ($imap) = @_;
  #print "I am authenticated..\n" if $imap->IsAuthenticated();

  my $gafTime = [gettimeofday];
  print "Getting list of gmail folders...\n";
  my $folderAndSeps = getAllFolders ($imap);
  #print "getAllFolders -- " . tv_interval($gafTime) . "\n";
  #print "=================\n";
  #print Dumper($folderAndSeps);

  #my $numFolders = countFolders($folderAndSeps);
  #print "Number of folder: $numFolders\n";


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

    print $FH "\'$yFolder\',\n";

    # Map gmail folder to Y!
    $gmailFolderHash{$yFolder}->{y} = mapNameToYahoo($sep, $yFolder);

    my $count = $imap->message_count($folder);
    if (defined $count) {

      #print "Count: $count\n";
      $gmailFolderHash{$yFolder}->{count} = $count;
    }
    else {

      print "IMAP failed to find msg count\n";
      $gmailFolderHash{$yFolder}->{count} = 0;
    }
  }

  closeIMAPConnection($imap);
}

sub mapNameToYahoo
{
  my ($sep, $folderName) = @_;

  my $ySep = ".";

  if ((exists $folderMap{$folderName}) and
    (defined $folderMap{$folderName})) {

    $folderName = $folderMap{$folderName}
  }
  else {

    $folderName =~ s/$sep/$ySep/g;
  }

  if ((exists $folderMap{$folderName}) and
    (defined $folderMap{$folderName})) {

    $folderName = $folderMap{$folderName}
  }

  # We need to map some of the special characters, eg- " to -dq-
  # @ to -at-
  if ($folderName eq '@B@Bulk') {
    ### no character mapping on '@B@Bulk' folder
  } else {
    foreach my $char (keys %folderCharMap){
      my $mapValue = $folderCharMap{$char};
      $folderName =~ s/$char/$mapValue/g;
    }
  }

  return $folderName;
}

sub printFolderSummary
{
  print $FH "Folder Name,Gmail Count,Y! Count\n";

  foreach my $fld (keys %gmailFolderHash) {

    my $mappedYName = $gmailFolderHash{$fld}->{y};
    print $FH "$fld,";

    if (defined $yFolderHash{$mappedYName} && exists $yFolderHash{$mappedYName}) {

      # Gmail folder is present in Y!
      print $FH "$gmailFolderHash{$fld}->{count},$yFolderHash{$mappedYName}->{count}\n";
    }
    else {

      # Gmail folder is not present in Y!
      print $FH "$gmailFolderHash{$fld}->{count},Not Migrated\n";
    }
  }
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

  my $cmd = "./oauth.py $emailId $consumer_key $consumer_secret $url 2>&1";

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

sub findSidSilo($)
{
  my $user = shift;

  my ($sid, $silo);

  my $cmd = "udb-test -Rk sid,ym_mail_sh $user 2>&1";

  my $ret = qx/$cmd/;

  unless ($?) {

    if ($ret =~ /=sid=(\w{1,10})\ca(\w{1,32})/) {

      $sid = $2;
    }

    if ($ret =~ m/=ym_mail_sh=silo\cB(\d+)\cA/) {

      $silo = $1;
    }
  }

  return ($sid, $silo);
}

sub wanted
{
  my ($dev,$ino,$mode,$nlink,$uid,$gid);

  (($dev,$ino,$mode,$nlink,$uid,$gid) = lstat($_)) &&
  -f _ &&
  /^idx.*\..*\z/s;
  #print("$name\n");

  if ($name =~ m/idx\d{1,5}\.(.*)/) {

    my $yFolder = $1;

    # Find number of messages

    my $cmd = "grep Flags \"$name\" | grep -v X | wc -l 2>&1";
    my $ret = qx/$cmd/;
    $ret =~ s/^\s+//;
    $ret =~ s/\s+$//;
    $yFolderHash{$yFolder}->{count} = $ret;
  }
}

sub getYFolderDetailsFrmIdx
{

  my ($user) = @_;

  print "Getting list of Y! folders...\n";
  my ($sid, $silo) = findSidSilo($user);

  my $cmd = "fmbox.sh $sid 2>&1";
  my $ret = qx/$cmd/;

  chop($ret);
  unless ($?) {

    if ($ret =~ m/found\s+at\s+(.*)/) {

      # Traverse desired filesystems
      File::Find::find({wanted => \&wanted}, "$1\/");
    }
  }
}

sub getYFolderDetails
{
  my ($user) = @_;

  print "Getting list of Y! folders...\n";
  my ($sid, $silo) = findSidSilo($user);

  my $mailbox = Mailbox::new();
  my ($ret, $busy) = $mailbox->open($sid, 'yahoo', "ms$silo");

  if ($ret) {

    #print "calling listFolders...\n";

    my @folders = $mailbox->listFolders();

    foreach my $yFolder (@folders) {

      #print "calling getFolder $yFolder...\n";
      my $folder = $mailbox->getFolder($yFolder);

      unless (defined $folder) {

        print "Folder $yFolder does not exists in Y! Mbox";
        next;
      }   

      #print "creating new msglist...\n";

      my $msgList;
      eval {

        $msgList = MessageList::new();
        if (defined $msgList) {

          #print "populating msglist...\n";
          $ret = $folder->messages($msgList);
        }
        else {

          $ret = 0;
        }

      };

      if ($@) {

        #print "$@\n";
        print "Failed to get message list folder: $yFolder";
        $yFolderHash{$yFolder}->{count} = 0;
        next;
      }
      unless ($ret) {

        print "Failed to get message list folder: $yFolder";
        $yFolderHash{$yFolder}->{count} = 0;
        next;
      }   

      #print "getting size of msglist...\n";
      my $numberOfMsgs = $msgList->size();
      $yFolderHash{$yFolder}->{count} = $numberOfMsgs;

    } # foreach

    #print "closing mbox...\n";
    $mailbox->close();
  }
  else {

    print "Mailbox open failed, busy: $busy\n";
  }

}
########################################## MAIN ############################################

die "usage: $0 -u <user-name>\n" if (scalar @ARGV < 2);

GetOptions (
  'u=s' => \$emailId,
) or die "usage: $0 -u <user-name>\n";

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

chomp($emailId);

my ($name, $dom) = split('@', $emailId);
my $opfileName = "/tmp/$name.csv";

open ($FH, '>', $opfileName) or die "Cannot create $opfileName: $!";

print $FH "$emailId\n";

#######  GMAIL #############
my $b64Encoded = getXOAUTHToken($emailId);
unless (defined $b64Encoded) {

  die "ERROR generating XOAUTH token\n";

}

my $imap = openIMAPConnection($emailId, $passwd, $localServer, $imapLocal, $ssl, $peek, 'XOAUTH', sub{$b64Encoded});

if (defined $imap) {

  getGmailFolderDetails($imap);
}
else {

  print "IMAP Failed....\n";
}

############# Yahoo ##########

getYFolderDetailsFrmIdx($emailId);

printFolderSummary();

print "O/P stored at: $opfileName\n";

#print $FH Dumper(\%gmailFolderHash) . "\n";
#print $FH Dumper(\%yFolderHash) . "\n";
close ($FH);



