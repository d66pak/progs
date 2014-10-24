###
### $Id: FetchEmail.pm,v 1.46 2008-12-17 01:05:47 sumav Exp $
###
package MyFetchEmail;

use YMCM::AccessTransaction;
use YMCM::Logger;
use Data::Dumper;
use Mail::IMAPClient;
use IO::Socket::SSL;
use Unicode::IMAPUtf7;
use Unicode::String;
use Net::POP3;
use Authen::SASL;
use strict;
use Carp;

# Y! Mail modules
use MyMailMigrateUtil;
use POSIX qw(floor);

use Fcntl qw(:flock);
use Time::HiRes qw(gettimeofday tv_interval);
use Digest::MD5 qw(md5_hex);
use Sys::Hostname;
use Math::BigInt;

local $SIG{__WARN__} = \&Carp::cluck;

my $transcoder = Unicode::IMAPUtf7->new();
my $logger = undef;
my %folderCharMap = ();
my @folderIgnore = ();
my $maxFolders = 512; # during TNZ migration
my $ignoreFoldersOverLimit = 0; # If set to 1, first 512 folders will be written
my $unique_id_msg = "Message-ID"; #during TNZ migration

sub setMsgUniqueIdField {
  my $unique_id = shift;
  $unique_id_msg = $unique_id;
}

sub setFolderCharMap($){
  my $ref = shift;
  if ( defined( $ref ) ) {
    %folderCharMap = %$ref;
  }
}
sub setFolderIgnore{
  my $ref = shift;
  @folderIgnore = @$ref;
}

sub fatalError($$$) {
  my ($tag, $subTag, $msg) = @_;
  my $partner = 'Rogers';
  $logger->logErr($msg);
  my $str = $tag;
  $str .= "-" . $subTag;
}

sub setMaxFolders($) {
  my $numFold = shift;
  $maxFolders = $numFold;
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
  $numFold = $numFold - scalar(@folderIgnore); 
  return $numFold;
}

sub openIMAPConnection {
  my ($imapId, $imapPasswd, $imapServer, $imapPort, $imapSSL, $imapPeek, $authScheme, $authCallBack) = @_;

  my @imapclient_options = (Uid => 1,
    Timeout => 5*60,
    User => $imapId,
    Password => $imapPasswd,
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
    $logger->logErr( "failed to make new IMAPClient obj" );
    return undef;
  }

  if ($imapSSL) {
    my $where = "$imapServer:$imapPort";
    my $sock = new IO::Socket::SSL($where);
    if (!defined($sock)) {
      $logger->logErr( "failed to open SSL connection to $where" );
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
      $logger->logDebug( "$code is BYE or NO" );
      $imap->State("Unconnected");
      return $imap;
    }

    # Now, have Mail::IMAPClient send the login for us
    unless ($imap->login) {
      $logger->logErr("login failed");
      return $imap;
    }
  }

  if (defined $authScheme && $authScheme eq 'XOAUTH') {

    unless ($imap->authenticate($authScheme, $authCallBack)) {

      $logger->logErr("Failed to authenticate");
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

# Reset IMAP connection
# Select the folder which was perviously selected
sub resetIMAPConnection($$$$$$$$$$$)
{
  my ($imap, $imapId, $imapPasswd, $imapServer, $imapPort, $imapSSL, $imapPeek, $authScheme, $authCallBack, $folder, $deleteMsg) = @_;

  closeIMAPConnection($imap);

  $imap = openIMAPConnection($imapId, $imapPasswd, $imapServer, $imapPort, $imapSSL, $imapPeek, $authScheme, $authCallBack);
  unless (defined $imap) {

    return undef;
  }

  $imap->Uid(1);

  my $folderSel = MyMailMigrateUtil::selectImapFolder ($imap, $folder, $deleteMsg);
  unless (defined $folderSel) {
    $logger->logErr("can't do a folder select for imap id: $imapId, folder: $folder");
    return undef;
  }

  return $imap;
}

# Open Net::POP3 connection
sub openNetPOP3Connection($)
{
  my ($popConfigHref) = @_;

  # Create Net::POP3 object
  my $pop = Net::POP3->new(
    Host => $popConfigHref->{popServer},
    Port => $popConfigHref->{popPort},
    Timeout => 5*60,
    Debug => 0,
  );

  unless (defined $pop) {

    $logger->logErr("Error connecting to POP3 server for $popConfigHref->{user}");
    return undef;
  }

  # Check the type of auth requested
  if ($popConfigHref->{authMech} eq 'PASS') {

    # Simple user/pass
    my $count = $pop->login($popConfigHref->{user}, $popConfigHref->{adminPass});
    unless (defined $count) {

      $logger->logErr("POP3 PASS AUTH failed for $popConfigHref->{user}");
      return undef;
    }
  }
  else {

    # Check for SASL support
    my $capa = $pop->capa();

    unless (scalar keys %$capa && exists $capa->{SASL}) {

      $logger->logErr("POP3 SASL AUTH mechanism not supported by server for $popConfigHref->{user}");
      return undef;
    }

    # Create SASL obj
    my $sasl = Authen::SASL->new(
      mechanism => $popConfigHref->{authMech},
      debug => 0,
      callback => {
        authname => $popConfigHref->{user},
        user => $popConfigHref->{adminUid},
        pass => $popConfigHref->{adminPass},
      }
    );

    unless (defined $sasl) {

      $logger->logErr("Error creating Authen::SASL object for $popConfigHref->{user}");
      return undef;
    }

    # Attempt SASL authentication
    unless ($pop->auth($sasl)) {

      $logger->logErr("POP3 SASL Auth failed for $popConfigHref->{user}: " . $pop->message());
      return undef;
    }

    $logger->logDebug("POP3 SASL Auth Success for: $popConfigHref->{user}");
  }

  return $pop;
}

# Close Net::POP3 connection
sub closeNetPOP3Connection($)
{
  my ($pop) = @_;
  $pop->quit();
}

# Return reference to Msgid => UIDL map using Net::POP3
sub getMsgidUIDLMap($$)
{
  my ($pop, $msgidUidlHref) = @_;

  $logger->logInfo("Attempting to build MsgID => UIDL map");

  # Build msgid => UIDL map
  my $totalMsgs = $pop->_get_mailbox_count();
  for (my $msgnum = 1; $msgnum <= $totalMsgs; $msgnum++) {

    my $msgid;
    # Fetch the header
    my $hdrAref = $pop->top($msgnum);
    foreach my $line (@$hdrAref) {

      if ($line =~ /^(Message-ID):\s+(<.*?>)/i) {

        $msgid = $2;
        last;
      }
    }

    if (defined $msgid && $msgid ne '') {

      # Fetch the UIDL
      my $uidl = $pop->uidl($msgnum);
      if (defined $uidl && $uidl ne '') {

        # Insert into map
        $msgidUidlHref->{$msgid} = $uidl;
      }
      else {

        $logger->logInfo("POP3 UIDL missing for msg: $msgnum");
      }
    }
    else {

      $logger->logInfo("POP3 Message-Id missing for msg: $msgnum");
    }
  }

  $logger->logInfo("Finished building MsgID => UIDL map");
}

sub getUIDLVer2
{
  my ($prefix, $uidl) = @_;

  my $uidlVer2 = Math::BigInt->new("$uidl")->as_hex;
  $uidlVer2 =~ s/^0x/$prefix/;
  return $uidlVer2;
}

sub FetchMailIMAP {
  my ($in_log, $login, $sid, $silo, $imapId, $imapPasswd, $imapServer, $imapPort,
    $dir, $deleteMsg, $isRetry, $lockTimeRef, $FolderMap, $imapSSL, $imapPeek,
    $skipDeleted, $authScheme, $authCallBack, $popConfigHref, $addiConfigHref) = @_;

  $logger = $in_log;
  unless (defined($login)){
    $logger->logErr("undefined login parameter");
    return (ACTIONFAILED, UNDEFINED_ARG, 0);
  }
  unless (defined($sid)){
    $logger->logErr("undefined sid parameter");
    return (ACTIONFAILED, UNDEFINED_ARG, 0);
  }
  unless (defined($silo)){
    $logger->logErr("undefined silo parameter");
    return (ACTIONFAILED, UNDEFINED_ARG, 0);
  }
  unless (defined($imapId)){
    $logger->logErr("undefined imapId parameter");
    return (ACTIONFAILED, UNDEFINED_ARG, 0);
  }
  unless (defined($imapPort)){
    $logger->logErr("undefined imapPort parameter");
    return (ACTIONFAILED, UNDEFINED_ARG, 0);
  }
  unless (defined($dir)){
    $logger->logErr("undefined dir parameter");
    return (ACTIONFAILED, UNDEFINED_ARG, 0);
  }
  unless (defined($deleteMsg)){
    $logger->logErr("undefined deleteMsg parameter");
    return (ACTIONFAILED, UNDEFINED_ARG, 0);
  }
  unless (defined($isRetry)){
    $logger->logErr("undefined isRetry parameter"); 
    return (ACTIONFAILED, UNDEFINED_ARG, 0);
  }
  unless (defined($lockTimeRef)){
    $logger->logErr("undefined lockTimeRef parameter");
    return (ACTIONFAILED, UNDEFINED_ARG, 0);
  }
  unless (defined($imapPasswd)){
    $logger->logErr("undefined imapPasswd parameter");
    return (ACTIONFAILED, UNDEFINED_ARG, 0);
  }
  unless (defined($imapPeek)) {
    $imapPeek = 0;
  }
  if (defined $authScheme) {

    unless (defined($authCallBack)) { 

      $logger->logErr("undefined authCallBack parameter for scheme $authScheme");
      return (ACTIONFAILED, UNDEFINED_ARG, 0);
    }
  }

  # Initialize additional config params
  my $isDSync = 0;
  my $authExpiryTime = undef;
  my $popUIDLField = undef;
  my $popUIDLPrefix = undef;
  if (defined $addiConfigHref && scalar keys %$addiConfigHref) {

    if (exists $addiConfigHref->{isDSync} &&
      defined $addiConfigHref->{isDSync}) {

      $isDSync = $addiConfigHref->{isDSync};
    }
    if (exists $addiConfigHref->{imapAuthExpiryTime} &&
      defined $addiConfigHref->{imapAuthExpiryTime}) {

      $authExpiryTime = $addiConfigHref->{imapAuthExpiryTime};
    }
    if (exists $addiConfigHref->{ignoreFoldersOverLimit} &&
      defined $addiConfigHref->{ignoreFoldersOverLimit}) {

      $ignoreFoldersOverLimit = $addiConfigHref->{ignoreFoldersOverLimit};
    }
    if (exists $addiConfigHref->{popUIDLField} &&
      defined $addiConfigHref->{popUIDLField}) {

      $popUIDLField = $addiConfigHref->{popUIDLField};
    }
    if (exists $addiConfigHref->{popUIDLPrefix} &&
      defined $addiConfigHref->{popUIDLPrefix}) {

      $popUIDLPrefix = $addiConfigHref->{popUIDLPrefix};
    }
  }

  # Login to IMAP server
  my $t0 = [gettimeofday];
  my $imap = openIMAPConnection($imapId, $imapPasswd, $imapServer, $imapPort, $imapSSL, $imapPeek, $authScheme, $authCallBack);
  my $t1 = tv_interval($t0);
  print "Time to open IMAP connection: $t1 secs\n";
  $logger->logInfo("Time to open IMAP connection: $t1 secs");

  unless ($imap) {

    $logger->logErr("cannot connect to IMAP server: $imapServer for user: $imapId port: $imapPort");
    $logger->logStat("IMAP", "IMAPCONNECTIONFAIL", $login, '', '', '');
    return (ACTIONFAILED, IMAPCONNFAILED, 0);

  }
  else {

    unless ($imap->IsConnected()) {
      $logger->logErr("cannot connect to IMAP server: $imapServer for user: $imapId port: $imapPort");
      $logger->logStat("IMAP", "IMAPCONNECTIONFAIL", $login, '', '', '');
      return (ACTIONFAILED, IMAPCONNFAILED, 0);
    }

    unless ($imap->IsAuthenticated()) {
      $logger->logErr("cannot login to IMAP server: $imapServer for user: $imapId port: $imapPort. Authentication failed.");
      $logger->logStat("IMAP", "IMAPAUTHFAIL", $login, '', '', '');
      return (ACTIONFAILED, IMAPLOGINFAILED, 0);
    }

  }

  # IMAP active time
  my $imapT0 = [gettimeofday];

  # Use unique ids.
  $imap->Uid(1);

  # For timing
  my $starttime = time();

  # Retrieve folders
  $t0 = [gettimeofday];
  my $folderAndSeps = getAllFolders ($imap);
  $t1 = tv_interval($t0);
  print "Time to get list of folders: $t1 secs\n";
  $logger->logInfo("Time to get list of folders: $t1 secs");

  unless (defined($folderAndSeps)){
    $logger->logErr( "Get all IMAP folders failed for user imapId: $imapId");
    $logger->logStat("IMAP", "IMAPFOLDERLISTFAIL", $login, '', '', '');
    closeIMAPConnection($imap);
    return (ACTIONFAILED, IMAPLISTFAILED, 0);
  }
  $logger->logDebug("IMAP Folders: " . Dumper($folderAndSeps));

  # do count of folders before copying them to temp location.
  # This will save lot of time in processing of user who have more than allowed folders
  my $numFolders = countFolders($folderAndSeps);
  if ($numFolders > $maxFolders) {

    # Check if fetching first 512 folders is allowed
    if ($ignoreFoldersOverLimit) {

      $logger->logInfo("User has $numFolders folders, only fetching first $maxFolders folders");
    }
    else {

      return (ACTIONFAILED, TOOMANYFOLDERS, 0);
    }
  }

  my @emptyFolders = ();
  my $foldersCopied = 0;

  my $status = ACTIONOK;
  my $folderOk = 1;
  my $failed = 0;
  my $downloaded = 0;
  my $mailboxOk = 1;

  # Create it if it doesn't exist.
  if (! -d $dir){
    if (!mkdir($dir, 0755)){
      $logger->logErr("can't mkdir $dir");
      closeIMAPConnection($imap);
      return(ACTIONFAILED, IMAPLISTFAILED, 0);
    }
  }
  # Set our base directory to be the sid
  $dir = "$dir/$sid";

  # Create it if it doesn't exist.
  if (! -d $dir){
    if (!mkdir($dir, 0755)){
      $logger->logErr("can't mkdir $dir");
      closeIMAPConnection($imap);
      return(ACTIONFAILED, IMAPLISTFAILED, 0); 
    }
  }

  # Read uidl => msgid map from file
  my $yMigUidlMsgId = undef;
  if ($isDSync) {

    if (open (UIDLMSGID, "$dir/.info_dsync")) {

      # Read into variable
      local $/ = undef;
      my $str = <UIDLMSGID>;
      eval $str;
      close(UIDLMSGID);
    }
    else {

      $logger->logInfo("open $dir/.info_dsync file for reading failed");
    }
  }

  # If POP support is enabled, read uidl => pop-uidl map from file
  my $uidlPopUidlMap = undef;
  if (scalar keys %$popConfigHref && $isDSync) {

    if (open (POPUIDL, "$dir/.info_popuidl")) {

      # Read into variable
      local $/ = undef;
      my $str = <POPUIDL>;
      eval $str;
      close(POPUIDL);
    }
    else {

      $logger->logErr("open $dir/.info_popuidl file for reading failed");
    }
  }

  # Loop through our folders and process them
  my %fallUidToUidl = ();
  my %fallUidToFlags = ();
  my %updateFlagsMap = ();
  my %deletedPartnerFolderMap = ();
  my @yahooFolders = (); ## check for unique
  foreach my $fs (@$folderAndSeps) {
    my %allUidToUidl = ();
    my %allUidToFlags = ();

    #print "\nprocessing folder: $fs\n";
    last if ($status == IMAPTIMEDOUT or $status == MSGSTOREMBOXERROR);

    # Yahoo account only support maximum of 256 folders.
    if ($foldersCopied >= $maxFolders) {
      $status = TOOMANYFOLDERS if ($status == ACTIONOK);
      last;
    }

    my $folder = undef;
    $fs =~ /(.*?)\s(.*)/;
    my $sep = $1;
    $folder = $2;

    unless (defined $folder and defined $sep) {
      $logger->logErr("can't get folder and delimiter from $fs");
      closeIMAPConnection($imap);
      return(ACTIONFAILED, IMAPLISTFAILED, 0);
    }

    #print "Total messages for folder $fs: $totalMsgs folder validity: $folderUidValidity\n";

    # We need to map some of folder name to Yahoo name,
    # such as 'INBOX' -> 'Inbox', and 'Spam' -> 'Bulk'.
    # For nested folder structure, Flat it by replacing
    # the delimiter with a well defined character
    # such as '.', which is provided by $ySep parameter.
    my $yahooFolder = undef;
    if ($folder =~ /^\"(.*?)\"/) {
      $yahooFolder = $1;
    } else {
      $yahooFolder = $folder;
    }
    #  Decode IMAP-UTF-7 encoded folder name
    #  Perl 5.6 decoder doesn't decode correctly if name has a plain ascii plus sign
    $yahooFolder = decodeIMAPUtf7FolderName($yahooFolder);

    if(isFolderIgnored($yahooFolder)) {

      $logger->logErr("Ignoring $yahooFolder. Not migrated.");
      next;
    }

    # First check if folder is mentioned in Folder map
    # If it is then there is no need to replace separators
    my $ySep = ".";
    if ( defined $FolderMap ) {

      if ((exists $FolderMap->{$yahooFolder}) and
        (defined $FolderMap->{$yahooFolder})) {

        $yahooFolder = $FolderMap->{$yahooFolder}
      }
      else {

        $yahooFolder =~ s/$sep/$ySep/g;
      }

      if ((exists $FolderMap->{$yahooFolder}) and
        (defined $FolderMap->{$yahooFolder})) {

        $yahooFolder = $FolderMap->{$yahooFolder}
      }
    }
    else {

      $yahooFolder =~ s/$sep/$ySep/g;
    }

    # We need to map some of the special characters, eg- " to -dq-
    # @ to -at-
    if ($yahooFolder eq '@B@Bulk') {
      ### no character mapping on '@B@Bulk' folder
    } else {
      foreach my $char (keys %folderCharMap){
        my $mapValue = $folderCharMap{$char};
        $yahooFolder =~ s/$char/$mapValue/g;
      }
    }
    ### check for uniqueness
    if (makeYahooFolderUnique(\@yahooFolders, $yahooFolder, 240, 0, 0) == 1) {
      $logger->logErr(" $yahooFolder cannot be made unique; it is skipped\n" );
      next;
    } else {
      $yahooFolder = $yahooFolders[$#yahooFolders];
    }

    $logger->logDebug("Calling IMAP SELECT on folder $folder");

    # select IMAP fodler
    ### In file dbconversion/scripts/MailMigrateUtil.pm
    ### selectImapFolder select 'inbox but examine on other folders
    ### maybe could be changed to examine on all folders (TODO: ask ryang)
    $t0 = [gettimeofday];
    my $folderSel = MyMailMigrateUtil::selectImapFolder (
      $imap, $folder, $deleteMsg);
    $t1 = tv_interval($t0);
    #print "Time to select folder $folder : $t1 secs\n";
    $logger->logInfo("Time to select folder $folder : $t1 secs");

    unless (defined $folderSel) {
      $logger->logErr("can't do a folder select for user $login, imap id: $imapId, folder: $folder");
      $logger->logStat("IMAP", "IMAPSELECTFOLDERERROR", $login, '', '', '');
      $status = IMAPFOLDERERROR if ($status == ACTIONOK);
      next;
    }

    my ($totalMsgs, $folderUidValidity) = @$folderSel;
    # Check the current uid validity with the previous one
    # It should not have changed
    if ($isDSync) {

      if (defined $yMigUidlMsgId && exists($yMigUidlMsgId->{$yahooFolder}->{uidvalidity})) {

        $logger->logInfo("Uid validity for $yahooFolder: Previous=>$yMigUidlMsgId->{$yahooFolder}->{uidvalidity} New=>$folderUidValidity");
      }
      else {

        # First time, store the uid validity
        $yMigUidlMsgId->{$yahooFolder}->{uidvalidity} = $folderUidValidity;
      }
    }

    $logger->logInfo("Y! folder to be processed: $yahooFolder");

    # Different flow for delta sync
    my ($msgInfoList, $uidToUidlHash, $uidlFlagsMap, $success, $status1) = (undef, undef, undef, 0, ACTIONFAILED);
    if ($isDSync) {

      my @pMsgInfoList = ();

      # Do imap fetch only if there are msgs
      if ($totalMsgs > 0) {

        $imap->Uid(0);

        # Check if POP UIDL can be fetched from IMAP
        my $hash;
        if (defined $popUIDLField && (lc($yahooFolder) eq 'inbox')) {

          $t0 = [gettimeofday];
          $hash = $imap->fetch_hash("UID", "FLAGS", "RFC822.SIZE", $popUIDLField);
          $t1 = tv_interval($t0);
          #print "Time to fetch_hashs : $t1 secs\n";
          $logger->logInfo("Time to fetch_hashs : $t1 secs");
        }

        unless (scalar keys %$hash) {

          $t0 = [gettimeofday];
          $hash = $imap->fetch_hash("UID", "FLAGS", "RFC822.SIZE");
          $t1 = tv_interval($t0);
          #print "Time to fetch_hash : $t1 secs\n";
          $logger->logInfo("Time to fetch_hash : $t1 secs");
        }
        $imap->Uid(1);

        foreach my $mid (keys %$hash) {
          my $uid  = $hash->{$mid}->{"UID"};
          my $flagStr = $hash->{$mid}->{"FLAGS"};
          unless (defined $flagStr) {

            $flagStr = '';
          }
          my @flagArr = split(' ', $flagStr);
          my $sz   = $hash->{$mid}->{"RFC822.SIZE"};
          if (defined $uid && defined $sz) {

            my @msgInfoElements = ($uid, \@flagArr, $sz);
            if (exists $hash->{$mid}->{$popUIDLField} &&
              defined $hash->{$mid}->{$popUIDLField}) {

              push @msgInfoElements, $hash->{$mid}->{$popUIDLField};
            }
            push @pMsgInfoList, \@msgInfoElements;
          }
        }
      }
      ($msgInfoList, $uidToUidlHash, $uidlFlagsMap, $success, $status1) =
      getDeltaSyncInfo($yahooFolder, $folderUidValidity, $sid, $silo,
        \@pMsgInfoList, $yMigUidlMsgId, $uidlPopUidlMap, \%deletedPartnerFolderMap, $popUIDLPrefix);

      # Dump
      $updateFlagsMap{$yahooFolder} = $uidlFlagsMap;

      # clean up
      $uidlFlagsMap = undef;
      @pMsgInfoList = undef;
    }
    else {

      # Put to empty folders queue if this folder doesn't
      # contains any messages.
      if($totalMsgs < 1) {
        push @emptyFolders, $yahooFolder;
        next;
      }
      $imap->Uid(0);
      my $hash = $imap->fetch_hash("UID", "RFC822.SIZE");
      $imap->Uid(1);
      my @uids;

      foreach my $mid (keys %$hash) {
        my $uid = $hash->{$mid}->{"UID"};
        my $sz  = $hash->{$mid}->{"RFC822.SIZE"};
        if (!defined($uid)) {
          next;
        }
        if (!defined($sz)) {
          next;
        }
        push @uids, $uid;
      }

      # If it's retry there are some messages had already been
      # copied to Y! account. We skip those messsages.
      ($msgInfoList, $uidToUidlHash, $success, $status1) =
      getMessageUids ($isRetry, $imap, $yahooFolder, $totalMsgs,
        $folderUidValidity, $sid, $silo, $skipDeleted, \@uids);
    }

    unless ($success) {

      if ($isDSync && $status1 == TOOMANYFOLDERS) {

        # skip this folder
        next;
      }

      $logger->logErr("failed to compare messages in folder $folder to those copied to Y! account (folder $yahooFolder)");
      $logger->logStat("IMAP", "IMAPCONNECTFAILED", $login, '', '');
      closeIMAPConnection($imap);
      return (ACTIONFAILED, $status1, 0);
    }

    if (scalar @$msgInfoList == 0) {
      $logger->logInfo("The msg info list is empty for $yahooFolder");
      push @emptyFolders, $yahooFolder;
      next;
    }

    ++$foldersCopied;

    # dump out our msg flag
    foreach my $minfo (@$msgInfoList){
      my ($muid, $mflags, $mSize) = @$minfo;
      $allUidToFlags{$muid} = $mflags;
    }
    $fallUidToFlags{$yahooFolder} = \%allUidToFlags;

    my $msgCount = scalar(@$msgInfoList); 

    for (my $msgnum = 1; $msgnum <= $msgCount;) {

      unless (MyMailMigrateUtil::verifyLockTime($lockTimeRef)) {
        $status = IMAPTIMEDOUT;
        last;
      }

      my @accMsgs = ();
      my @accUids = ();
      my @accMsgFlags = ();

      my ($timeTaken, $msgsRead, $accMsgSize, $skipped, $badMsgs, $vcardMsgs) =
      (0, 0, 0, 0, 0, 0,);

      # Check if there is any message whose size is over 40M
      my $msgInfo = $$msgInfoList[$msgnum - 1];
      my ($mUid, $mFlags, $mSize) = @$msgInfo;
      if ($mSize >= 40000000) {
        $msgsRead = 1;
        $badMsgs  = 1;
        $status = IMAPBIGMSGS if ($status == ACTIONOK);
        $logger->logErr( "Found a message in folder $folder whose size is $mSize. Skip it");
      }
      else {

        # Before reading from IMAP, check active time
        # If its within limit, allow IMAP requests
        # else reset IMAP connection
        my $imapT1 = tv_interval($imapT0);
        if (defined $authExpiryTime && $imapT1 >= $authExpiryTime) {

          $imap = resetIMAPConnection($imap, $imapId, $imapPasswd, $imapServer, $imapPort,
            $imapSSL, $imapPeek, $authScheme, $authCallBack, $folder, $deleteMsg);
          if (defined $imap) {

            unless ($imap->IsConnected()) {
              $logger->logErr("cannot connect to IMAP server: $imapServer for user: $imapId port: $imapPort");
              $logger->logStat("IMAP", "IMAPCONNECTIONFAIL", $login, '', '', '');
              return (ACTIONFAILED, IMAPCONNFAILED, 0);
            }

            unless ($imap->IsAuthenticated()) {
              $logger->logErr("cannot login to IMAP server: $imapServer for user: $imapId port: $imapPort. Authentication failed.");
              $logger->logStat("IMAP", "IMAPAUTHFAIL", $login, '', '', '');
              return (ACTIONFAILED, IMAPLOGINFAILED, 0);
            }

          }
          else {

            $logger->logErr("cannot connect to IMAP server: $imapServer for user: $imapId port: $imapPort");
            $logger->logStat("IMAP", "IMAPCONNECTIONFAIL", $login, '', '', '');
            return (ACTIONFAILED, IMAPCONNFAILED, 0);

          }
          $logger->logInfo("IMAP Connection reset at: $imapT1 secs");

          # Reset IMAP active time
          $imapT0 = [gettimeofday];
        }
        else {

          $logger->logInfo("IMAP Connection still active at: $imapT1 secs");
        }

        $logger->logInfo("Trying to fetch msgs form IMAP...");
        $t0 = [gettimeofday];
        ($timeTaken, $msgsRead, $accMsgSize, $skipped, $badMsgs, $vcardMsgs) =
        MyMailMigrateUtil::readMailFromImap(
          $imap, $msgnum, $msgCount, $msgInfoList, 
          $lockTimeRef,
          \@accMsgs, \@accMsgFlags, \@accUids);
        $t1 = tv_interval($t0);
        $logger->logInfo("Time to readMailFromImap " . scalar(@accMsgs) . " : $t1 secs");

        if($vcardMsgs > 0) {

          $logger->logErr("Folder $folder is a vcard folder. Skipped.");
          --$foldersCopied;
          last;
        }

        $logger->logInfo("Folder $folder: read $msgsRead messages starting from msg $msgnum. " .
          "$skipped of them were skipped and " .
          "$badMsgs of them were bad");

        if ($badMsgs > 0) {
          $status = IMAPBADMSGS if ($status == ACTIONOK);
        }
      }

      # Time to write out accumulated messages.
      my $acc = @accMsgs;
      my $isLastAppend = 0;
      $isLastAppend = 1 if (($msgnum+$msgsRead) > $msgCount);	

      my @wroteMsgs = ();
      $msgnum += $msgsRead;

      # Write to directroy
      $t0 = [gettimeofday];
      $status = writeToFolder("$dir/$yahooFolder", \@accMsgs, \@accUids, \@wroteMsgs);
      $t1 = tv_interval($t0);
      $logger->logInfo("Time to writeToTempFolder : $t1 secs");
      $logger->logInfo("Wrote $acc messages of total size $accMsgSize to temporary folder $yahooFolder");

      #accumulate the uidls that we have written to file
      foreach my $msgUid (@wroteMsgs){
        my $uidl = $$uidToUidlHash{$msgUid};
        $allUidToUidl{$msgUid} = $uidl;

      }
      $fallUidToUidl{$yahooFolder} = \%allUidToUidl;

      $downloaded += scalar(@wroteMsgs);

    } # for (my $msgnum
  } # foreach item in @$folderAndSeps loop

  # Closing IMAP connection to avoid connection timeout
  closeIMAPConnection($imap);

  # Find partner folders which were deleted
  if ($isDSync) {

    foreach my $yFolder (keys %deletedPartnerFolderMap) {

      if ($deletedPartnerFolderMap{$yFolder}) {

        # Check if this folder was previously migrated
        if (exists $yMigUidlMsgId->{$yFolder}) {

#          $updateFlagsMap{$yFolder}->{folderDeleted} = 1;
        }
      }
    }
  }

  # Write back the updated uidl => msgid map
  if (defined $yMigUidlMsgId) {

    if (open (UIDLMSGID, ">$dir/.info_dsync")) {

      # Read into variable
      my $dmp = Data::Dumper->Dump([$yMigUidlMsgId], [ qw(yMigUidlMsgId) ]);
      print UIDLMSGID $dmp;
      close(UIDLMSGID);
    }
    else {

      $logger->logErr("open $dir/.info_dsync file for writing failed");
      return (ACTIONFAILED, INFOFILEREADERR, 0);
    }

    $yMigUidlMsgId = undef;
  }

  # Check if UIDL mapping using POP3 is required
  if (scalar keys %$popConfigHref) {

    my $t0 = [gettimeofday];

    $logger->logInfo("Start POP3 processing for: $login");

    # Connect to Net::POP3 client
    my $pop = openNetPOP3Connection($popConfigHref);

    unless (defined $pop) {

      return(ACTIONFAILED, NETPOPCONNFAILED, 0);
    }

    # Build MsgId => UIDL map using POP3
    my %msgidUidlHash;
    getMsgidUIDLMap($pop, \%msgidUidlHash);

    # Close the POP3 connection
    closeNetPOP3Connection($pop);

    if (scalar keys %msgidUidlHash) {

      $logger->logInfo("Attempting to replace IMAP Uidls with POP3 Uidls");
      # Login to IMAP server
      $imap = openIMAPConnection($imapId, $imapPasswd, $imapServer, $imapPort, $imapSSL, $imapPeek, $authScheme, $authCallBack);

      if (defined $imap) {

        unless ($imap->IsConnected()) {
          $logger->logErr("cannot connect to IMAP server: $imapServer for user: $imapId port: $imapPort");
          $logger->logStat("IMAP", "IMAPCONNECTIONFAIL", $login, '', '', '');
          return (ACTIONFAILED, IMAPCONNFAILED, 0);
        }

        unless ($imap->IsAuthenticated()) {
          $logger->logErr("cannot login to IMAP server: $imapServer for user: $imapId port: $imapPort. Authentication failed.");
          $logger->logStat("IMAP", "IMAPAUTHFAIL", $login, '', '', '');
          return (ACTIONFAILED, IMAPLOGINFAILED, 0);
        }

      }
      else {

        $logger->logErr("cannot connect to IMAP server: $imapServer for user: $imapId port: $imapPort");
        $logger->logStat("IMAP", "IMAPCONNECTIONFAIL", $login, '', '', '');
        return (ACTIONFAILED, IMAPCONNFAILED, 0);

      }

      # Use unique ids.
      $imap->Uid(1);

      # Examine the imap inbox folder
      unless ($imap->examine("Inbox")) {

        $logger->logError("Cannot examine IMAP Inbox folder for: $login");
        closeIMAPConnection($imap);
        return(ACTIONFAILED, IMAPFOLDERERROR, 0);
      }


      # Get the Inbox map
      my $uidToUidlHref = $fallUidToUidl{Inbox};
      foreach my $uid (keys %$uidToUidlHref) {

        my $msgId = $imap->get_header($uid, 'Message-ID');
        if (defined $msgId && $msgId ne '') {

          my $popUidl = $msgidUidlHash{$msgId};
          if (defined $popUidl && $popUidl ne '') {

            if ($isDSync) {

              # Update old uidl => pop uidl
              $uidlPopUidlMap->{$uidToUidlHref->{$uid}} = $popUidl;
            }
            # Replace with correct POP UIDL
            $uidToUidlHref->{$uid} = $popUidl;
          }
        }
        else {

          $logger->logInfo("IMAP Message-Id missing for: $login uid: $uid");
        }
      }

      # Close IMAP connection
      closeIMAPConnection($imap);
      $logger->logInfo("Finished replacing IMAP Uidls with POP3 Uidls");

      # Write back the updated uidl => pop uidl map
      if (defined $uidlPopUidlMap) {

        if (open (POPUIDL, ">$dir/.info_popuidl")) {

          # Read into variable
          my $dmp = Data::Dumper->Dump([$uidlPopUidlMap], [ qw(uidlPopUidlMap) ]);
          print POPUIDL $dmp;
          close(POPUIDL);
        }
        else {

          $logger->logErr("open $dir/.info_popuidl file for writing failed");
          $status = INFOFILEACCESSERROR;
        }
      }
      $uidlPopUidlMap = undef;
    }
    else {

      $logger->logInfo("POP msgid => uidl hash is undef for: $login");
    }

    my $et = tv_interval($t0);

    $logger->logInfo("End POP3 processing for: $login Time: $et secs");
  }
  else {

    $logger->logInfo("POP Config is undef for: $login");
  }

  #write out our uidl and flags hash
  if (open(INFO, ">$dir/.info")){
    my $dmp = Data::Dumper->Dump([\%fallUidToUidl], [ qw(fallUidToUidl) ]);
    my $flagDmp = Data::Dumper->Dump([\%fallUidToFlags], [ qw(fallUidToFlags) ]);
    my $updateFlagsDump = Data::Dumper->Dump([\%updateFlagsMap], [ qw(updateFlagsMap) ]);

    print INFO $dmp;
    print INFO $flagDmp;
    print INFO $updateFlagsDump;

    close(INFO);
  } else {
    $logger->logErr("open $dir/.info file for writing failed");
    $status = INFOFILEACCESSERROR;
  }

  # For empty folder it basically just create another empty mail folder
  foreach my $f (@emptyFolders) {
    # Yahoo account only support maximum of 256 folders
    if ($foldersCopied >= $maxFolders) {
      $status = TOOMANYFOLDERS if ($status == ACTIONOK);
      last;
    }

    # Spending too much time already?
    unless (MyMailMigrateUtil::verifyLockTime($lockTimeRef)) {
      $status = IMAPTIMEDOUT;
      last;
    }

    ++ $foldersCopied;

    if (!-d "$dir/$f"){
      if (!mkdir("$dir/$f", 0755)){
        $status = FOLDERCREATIONFAILED if ($status == ACTIONOK);
      }
    }

  } #foreach my $f(@emptyFolders)

  #log downloaded number.
  my $timespent = time() - $starttime;
  $logger->logStat("IMAP", "SUCCESS", $login, $timespent, $downloaded);

  if ($status != ACTIONOK){

    if ($status == TOOMANYFOLDERS && $ignoreFoldersOverLimit) {

      return (ACTIONOK, $status, $downloaded);
    }
    else {

      return (ACTIONFAILED, $status, $downloaded);
    }
  }
  return (ACTIONOK, $status, $downloaded);
}

sub isFolderIgnored {

  my ($folder) = @_;
  my $topFolder = "";

  # Find the top folder in the path 
  my @subFolders = split(/\// , $folder);

  if(scalar(@subFolders) > 0) {

    $topFolder = $subFolders[0];

  }

  # Firsr check if folder is mentioned in ignore list
  # If not found check if top folder is ignored

  foreach my $item (@folderIgnore) {

    if ($folder eq $item) {

      return 1;
    }
    if($topFolder eq $item) {

      return 1;
    }
  }

  return 0;
}

sub hasBOM {
  my ($str) = @_;
  my $rawLen = length($str);
  if ($rawLen == 3) {
    if ($str eq "\xef\xbb\xbf") {
      return 1;
    }
  } elsif ($rawLen > 3) {
    my $ustr = new Unicode::String;
    $ustr->utf8($str);
    my $trfdr = $ustr->substr(0, 3);
    if ($trfdr eq "\xef\xbb\xbf") {
      return 1;
    }
  }
  return 0;
}
sub isASCII {
  my ($str) = @_;
  if ($str =~ /^([\x00-\x7F])*$/ox) {
    return 1;
  }
  return 0;
}
sub addBom {
  my ($str) = @_;
  if (isASCII($str)) {
    return $str;
  } else {
    return "\xef\xbb\xbf".$str;
  }
}
sub hasBom {
  my ($str) = @_;
  my $rawLen = length($str);
  if ($rawLen >= 3
    && ( $str =~ /^\xef\xbb\xbf/ox ) ) {
    return 1;
  }
  return 0;
}

sub reduceString {
  my($str, $max) = @_;
  $str =~ s/^\xef\xbb\xbf//ox;  ## strip off bom
  my $rawLen = length($str);
  if (!isASCII($str)) {
    $max -= 3;
  }

  if ($rawLen > $max) {
    my $ustr = new Unicode::String;
    $ustr->utf8($str);
    my $utf8Len = $ustr->length;
    my $utf8TRLen =  floor ($max * $utf8Len / $rawLen) ;
    my $trfdr = $ustr->substr($utf8Len - $utf8TRLen, $utf8TRLen);

    if ( !isASCII($trfdr) and (length($trfdr) > $max+3)) {
      return reduceString( $trfdr, $max+3 );
    }

    return addBom($trfdr);
  }
  return addBom($str);
}
sub makeYahooFolderUnique {
  my ($folders, $fd_to_check, $max_raw_len, $skipCheckLen, $reductionOnly) = @_;
  if (!defined($max_raw_len) || $max_raw_len < 40) {
    $max_raw_len = 40;
  }

  unless (defined($skipCheckLen) && $skipCheckLen) {
    my $trfdr = reduceString( $fd_to_check, $max_raw_len );
    $fd_to_check = $trfdr;
  }

  ### check if unique
  my $found = 0;
  foreach my $item (@$folders) {
    if ($fd_to_check eq $item) {
      $found = 1;
      last;
    }
  }

  ### add to array if unique
  if (!$found) {
    push @$folders, $fd_to_check;
#      $logger->logDebug( "debug: DONE: $fd_to_check is unique" );
    return 0;
  } else {
    if ($reductionOnly) {
      ### try string reduction
      my $trfdr = reduceString( $fd_to_check, $max_raw_len-1 );
      $fd_to_check = $trfdr;

      if (makeYahooFolderUnique($folders, $fd_to_check, $max_raw_len, 1, 1) == 0) {
        return 0;
      } else {
        return 1;
      }
    } else {
      ### try append string
      my $trfdr = reduceString( $fd_to_check, $max_raw_len - 4 );
      $fd_to_check = $trfdr;
      for (my $i = 0; $i < 9; $i++) {
        for (my $j = 0; $j < 9; $j++) {
          for (my $z = 0; $z < 9; $z++) {
            my $temp_str = $fd_to_check . "-$i$j$z";
            my $found = 0;
            foreach my $item (@$folders) {
              if ($temp_str eq $item) {
                $found = 1;
                last;
              }
            }
            if ($found == 0) {
              push @$folders, $temp_str;
# 	      $logger->logDebug( "debug: DONE: $temp_str is unique" );
              return 0;
            }
          }
        }
      } ### done for
    } ### done append string iteration
  } ### tried all 

  ## giving up
  $logger->logErr( "ERROR: unable to make $fd_to_check unique" );
  return 1;
}


sub decodeIMAPUtf7FolderName($) {

  my ($folder) = @_;
  my $result = undef;
  my $len;
  my ($f, $r);
  my $tmp;

  my @utf7Str = split(//, $folder);
  $f = 0;
  $r = 0;
  $len = length($folder);


  while($r < $len){

    # Extract and decode the non-plain ascii characters above 0x7E.
    # These are encoded between a ampersand and hyphen
    if($utf7Str[$r] eq '&') {

      $f = $r;
      $r++;

      while($utf7Str[$r] ne '-') {

        $r++;
        if($r >= $len) { return undef; } 
      }

      $tmp = substr($folder, $f, $r - $f + 1);
      # Perl 5.6 IMAP-UTF-7 decoder doesn't process a comma correctly
      # Workaround
      $tmp =~ s/\,/\//g;
      $tmp = $transcoder->decode($tmp);
      $result = $result . $tmp;
      $f = $r + 1;
      $r++;

    }
    else {
      # plain 7-bit byte character. 
      $f = $r;
      while(($r < $len) && ($utf7Str[$r] ne '&')) {

        $r++;

      }

      # IMAP UTF-7 decoder does not handle the plus sign symbol correctly as part of plain 7-bit ascii
      $tmp = substr($folder, $f, $r - $f);
      if ($tmp =~ /\+/) {

        my @array = split(/\+/, $tmp);
        $tmp = join('+', (map {$transcoder->decode($_)} @array));
        # Handle a plus at the end
        if($utf7Str[$r-1] eq '+') {
          $tmp = $tmp . "+";
        }

      } else {

        $tmp = $transcoder->decode($tmp);

      }

      # Append the decoded value
      $result = $result . $tmp;

    }
  }

  return $result;

}

# Write each of the messages to the directory 
# with its uid as the filename.
sub writeToFolder($$$$){
  my ($folder, $msgs, $uids, $wroteMsgs) = @_;

  my @accMsgs = @$msgs;
  my @accUids = @$uids;

  if (!-d $folder){
    if (!mkdir ($folder, 0755)){
      $logger->logErr("unable to create directory $folder\n");
      return (FOLDERCREATIONFAILED);
    }
  }

  for (my $i = 0; $i <= $#accUids; $i++){
    my $msgFile = "$folder/$accUids[$i]";
    unless (open (FOLDER, ">$msgFile")){
      $logger->logErr("unable to open create message file: $msgFile\n");
      return (OPENTMPMSGFILEFAILED);
    }
    print FOLDER $accMsgs[$i];
    close FOLDER;
    push @{ $wroteMsgs } , $accUids[$i];
  }

  return ACTIONOK;
}

# Retrieve all folders and its delimiters.
sub getAllFolders {
  my ($imap) = @_;

  my $listRef = $imap->list(undef, undef); # what if it returns undef?
  return undef unless defined $listRef;
  my @list = @$listRef;

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
      if (defined($s) && length($s) >= 3) {
        $sep =  ($s eq 'NIL' ? 'NIL' : substr($s, 1, length($s)-2) );
      }
      if ($massageFolder) {
        #$logger->logErr("skip $fdr\n");
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

sub composeATTUidl {
  my ($folderUidValidity, $msgUid) = @_;
  my $eightZero  = "00000000";
  my $part1  = sprintf("%s%x", $eightZero, $folderUidValidity);
  my $part2 = sprintf("%s%x", $eightZero, $msgUid);
  return substr($part1, -8, 8) . substr($part2, -8, 8);
}

sub getMessageUids {
  my ($isRetry, $imap, $folder, $totalMsgs, 
    $folderUidValidity, $sid, $silo, $skipDeleted, $uids) = @_;

  my $uidToMessageIdHash;
  # First get all UIDLs
  # UIDL can be found from "Message-ID:" mail header.
  if ($unique_id_msg eq "Message-ID") {
    $uidToMessageIdHash = MyMailMigrateUtil::getAllMsgHeader(
      $imap, "Message-ID");
  }
  else {
    foreach my $uid (@$uids) {
      my $uidl = composeATTUidl($folderUidValidity, $uid);
      $$uidToMessageIdHash{$uid} = $uidl;
    }
  }

  unless (defined $uidToMessageIdHash) {
    return (undef, undef, 0, FAILTOGETMSGIDHDRS);
  }

  # If it's retry there are some messages had already been
  # copied to Y! account. We skip those messsages.
  my ($success, $uidsToSkip) = (1, undef);
  if ($isRetry) {

    # Create uidlToUid hash
    my %uidlToUid = ();
    foreach my $uid ( keys %$uidToMessageIdHash) {
      my $uidl = $$uidToMessageIdHash{$uid};
      $uidlToUid{$uidl} = $uid;
    }

    # Get list of messages that already downloaded to
    # Yahoo system. When we copied partner mail to Y!
    # account we preserved partner's UIDL for each of
    # the messages.
    ($success, $uidsToSkip) = MyMailMigrateUtil::getListOfDownloadedMessages(
      $folder, \%uidlToUid, $sid, $silo);

    return (undef, undef, 0, IMAPFAILTOGETUIDLS) unless $success;
  }

  my $msgInfoList = MyMailMigrateUtil::selectMessages (
    $imap, $totalMsgs, $uidsToSkip, $skipDeleted);
  return (undef, 0, IMAPSEARCHFAILED) unless (defined $msgInfoList);

  # Generate uid to uidl hash.
  my %uidToUidlHash = ();
  foreach my $msgUid ( keys %$uidToMessageIdHash) {
    my $msgUidl = $$uidToMessageIdHash{$msgUid};
    #print "\nBEFORE HASH, msgUid: $msgUid msgUidl: $msgUidl\n";
    $msgUidl = uc(md5_hex($msgUidl)) if (length($msgUidl) > 40);
    $uidToUidlHash{$msgUid} = $msgUidl;
    #print "msgUid: $msgUid msgUidl: $msgUidl\n";
  }

  # Make sure for any entry in msgInfoList, it should find
  # corresponding element in uidToUidlHash.
  my @newMsgInfoList = ();
  foreach my $msgInfo (@$msgInfoList) {
    my ($msgUid1, $msgFlags1, $msgsize1) = @$msgInfo;
    #print "msgUid1: $msgUid1 msgFlags1: @$msgFlags1 msgSize: $msgsize1\n";
    #if (exists $uidToUidlHash{$msgUid1} and
    #   defined $uidToUidlHash{$msgUid1}) {
    push @newMsgInfoList, $msgInfo;
    #}
  }

  return (\@newMsgInfoList, \%uidToUidlHash, 1, ACTIONOK);
}

# This function has logic to find out:
# 1. New msgs to be fetched from partner Mbox
# 2. Msgs which need not be fetched from partner Mbox
# 3. Msgs flags to be updated in Y! Mbox
sub getDeltaSyncInfo
{
  my ($folderName, $folderUidValidity, $sid, $silo,
    $pMsgInfoList, $yMigUidlMsgId, $uidlPopUidlMap, $deletedPartnerFolderMapRef, $UIDLPrefix) = @_;

  # Processing time
  my $t0 = [gettimeofday];

  # Get all UIDLs in Y! Mbox
  my ($success, $yFolderExists, $yFolderListRef, $yAllUidls) = MyMailMigrateUtil::getUidlHash($folderName, $sid, $silo);
  $logger->logInfo("Time to getUidlHash : " . tv_interval($t0) . " secs");
  unless ($success) {

    $logger->logErr("Error fetching UIDLs for Y! folder: $folderName"); 
    return (undef, undef, undef, 0, IMAPFAILTOGETUIDLS);
  }

  my $yFolderCount = scalar @$yFolderListRef;
  if (!$yFolderExists && $yFolderCount >= $maxFolders) {

    $logger->logInfo("Already $yFolderCount folders migrated, skipping deltasyncinfo for $folderName");
    return (undef, undef, undef, 0, TOOMANYFOLDERS);
  }

  # Create/Update deletedPartnerFolderMap
  foreach my $yFolder (@$yFolderListRef) {

    unless (exists $deletedPartnerFolderMapRef->{$yFolder}) {

      $deletedPartnerFolderMapRef->{$yFolder} = 1;
    }
  }

  # Set current folder not deleted
  if ($yFolderCount && $yFolderExists) {

    $deletedPartnerFolderMapRef->{$folderName} = 0;
  }

  # List of UIDs not fetched from Partner Mbox 
  my @uidsToSkip = ();

  # Common msgs in Y! and Partner Mbox whose flags must be updated
  my %uidlFlagsMap = ();

  # Msg Info list of msgs which will be fetched from Partner Mbox
  my @msgInfoList = ();

  # This hash contains UID => UIDL of all msgs
  # It will be used to fetch the UIDL of msg which is fetched from partner Mbox
  my %uidToUidlHash = ();

  # Loop through msg info list
  foreach my $msgInfoElements (@$pMsgInfoList) {

    my ($pUid, $pFlag, $pSize, $popUIDLImap) = @$msgInfoElements;

    my $pUidl;
    my $uidlV2 = undef;
    my $uidlV2used = 0;
    if (defined $popUIDLImap) {

      # POP UIDL is fetched from IMAP
      $pUidl = $popUIDLImap;
      if (defined ($UIDLPrefix)) {

        $uidlV2 = getUIDLVer2($UIDLPrefix, $pUidl);
      }
    }
    else {
      # Generate UIDL
      $pUidl = composeATTUidl($folderUidValidity, $pUid);
      if (length($pUidl) > 40) {

        $logger->logInfo("Uidl length more that 40");
        my $shortUidl = uc(md5_hex($pUidl));
        $pUidl = $shortUidl;
      }
    }

    my $popUidl = undef;

    # Check if this pUidl is already present in Y! Mbox
    if ( exists $yAllUidls->{$pUidl}) {

      # Previously migrated pUidl, only flag update
      $yAllUidls->{$pUidl} = 0;
      push @uidsToSkip, $pUid;

      # Update UIDL => flags map
      $uidlFlagsMap{$pUidl} = $pFlag;
    }
    elsif (defined $uidlV2 && exists ($yAllUidls->{$uidlV2})) {

      # Need to check if UIDL Ver2 was used

      # Previously migrated uidlV2, only flag update
      $yAllUidls->{$uidlV2} = 0;
      push @uidsToSkip, $pUid;

      # Update UIDL => flags map
      $uidlFlagsMap{$uidlV2} = $pFlag;
    }
    else {

      if (defined $uidlPopUidlMap && exists $uidlPopUidlMap->{$pUidl}) {

        # pUidl is present in uidlPopUidlMap
        # This pUidl was previously replaced by POP UIDL

        $popUidl = $uidlPopUidlMap->{$pUidl};
        if (exists $yAllUidls->{$popUidl} ) {

          # Previously migrated popUidl, only flag update
          $yAllUidls->{$popUidl} = 0;
          push @uidsToSkip, $pUid;

          # Update UIDL => flags map
          if (exists $yMigUidlMsgId->{$folderName}->{$popUidl}) {

            $uidlFlagsMap{$popUidl} = $pFlag;
          }
          else {

            $logger->logErr("POP UIDL: $popUidl found in Y! Mbox but not found in yMigUidlMsgId");
          }
        }
        else {

          # popUidl is not present in Y! Mbox
          if (exists $yMigUidlMsgId->{$folderName}->{$popUidl}) {

            # Deleted msg on Y!, no need to migrate again
            push @uidsToSkip, $pUid;
          }
          else {

            # New msg in Partner Mbox
            # This case is not possible. Just added for completness
            push @msgInfoList, $msgInfoElements;
          }
        }
      }
      else {

        # pUidl is not present in uidlPopUidlMap

        if (exists ($yMigUidlMsgId->{$folderName}->{$pUidl}) ||
          (defined $uidlV2 && exists ($yMigUidlMsgId->{$folderName}->{$uidlV2}))) {

          # Deleted msg on Y!, no need to migrate again
          push @uidsToSkip, $pUid;
        }
        else {

          # New msg in Partner Mbox
          # Since its a new msg, uidlV2 can be used

          if (defined $uidlV2) {

            # remove old uidl
            pop @$msgInfoElements;
            # add uidlV2
            push @$msgInfoElements, $uidlV2;
            $uidlV2used = 1;
          }
          push @msgInfoList, $msgInfoElements;
        }
      }
    }

    # Update UID => UIDL hash
    if (defined $popUidl) {

      $uidToUidlHash{$pUid} = $popUidl;
    }
    elsif (defined $uidlV2 && $uidlV2used) {

      $uidToUidlHash{$pUid} = $uidlV2;
    }
    else {

      $uidToUidlHash{$pUid} = $pUidl;
    }

  } # End of foreach msg info list

  # Y! UIDLs which were not found in Partner Mbox
  foreach my $yUidl (keys %$yAllUidls) {

    if ($yAllUidls->{$yUidl}) {

      if (exists $yMigUidlMsgId->{$folderName}->{$yUidl}) {

        # Deleted msg in Partner Mbox
        my @tempList = ("\\Deleted");
        $uidlFlagsMap{$yUidl} = \@tempList;
      }
      else {

        # New msg in Y! Mbox
        # noop
      }
    }
  }

  my $et = tv_interval($t0);
  $logger->logInfo("getDeltaSyncInfo Time: " . $et . " secs Folder: " . $folderName . " Fetch: "
    . scalar @msgInfoList . " Flag Update: " . scalar keys %uidlFlagsMap);

  return (\@msgInfoList, \%uidToUidlHash, \%uidlFlagsMap, 1, ACTIONOK);
}

sub setLogApplName($) {
  my ($an) = @_;
  $logger->setAppName($an);
}

# Set log file handle and debug mode.
sub setLogFile($) {
  my ($errFile) = @_;

  #  unless (open(ERR, ">> $errFile")) {
#	printDebug("ERROR: Failed to open log file $errFile: $!");
#	return 0;
#    }

  #   $err = \*ERR;
  #  $verbose = $mode;

  $logger->setLogFilename($errFile);
  return(1);
}

sub setVerbose($) {
  my ($mode) = @_;
  $logger->setVerbose($mode);
}


1;

__END__

=head1 NAME

YMCM::FetchEmail - Fetching email via IMAP or POP to disk for migration

=head1 SYNOPSIS

  use YMCM::FetchEmail;

  my ($ok, $status, $numberFetched) =
  YMCM::FetchEmail::FetchEmailIMAP($user, $sid, $silo, $id, $pw,
                                   $server, $port, $dir, $toDelete,
                                   $isRetry, $lockTimeRef, $folderMap);

=head1 DESCRIPTION

This module performs the generic downloading of email using the IMAP, POP and other
future protocols.

=head1 STATIC FUNCTIONS

The following are the public static methods.

=over 1

=item FetchEmail($user,$sid,...)

Parameters are $user, $sid, $silo, $id, $pw, $server, $port, $dir, $toDelete, $isRetry,
$lockTimeRef, $folderMap. $user is the new Yahoo user created for the migration. $sid 
is the Yahoo sid for this new user. $id is the IMAP user id. $pw is the IMAP password
for the IMAP user id. $server and $port are the IMAP server and port. $dir is the temporary
directory that will be used to store downloaded email messages of the under 
$dir/$sid/[mailboxes]. $toDelete specifies whether the folders will be deleted once 
done. $isRetry flag specifies if we are calling FetchMail for more than once for the 
same user.$lockTimeRef is the time lock used to determine if our operation has exceeded the 
time limit specified. $folderMap is a hash reference for mapping of the names of partner
folder to its equivalent Yahoo folder names.

=item setLogFile($logFileName)

Set the name of the log file that we write to. The directory which the log file resides
must be writable.If this method is not called, the log messages are sent to STDERR.

=item setLogApplName($applName)

Set the application name that will get logged to the log file.

=item setVerbose($mode)

Set the verbosity of our logging. If $mode is true, non-zero then we will log to the 
INFO level.

=item openIMAPConnection($imapId, $imapPasswd, $imapServer, $imapPort, $imapSSL)

argument $imapSSL is optional, if it is 1, then SSL is used.

Returns a MAIL::ImapClient $imap object reference for use after logging in by passing the imap id, 
password, server and port parameters. The returned object reference may be undefined if the login 
failed.


=item closeIMAPConnection($imap)

Given 

=head1 DEPENDENCIES

Yahoo Perl package(s):

YMRegister::MailMigrateUtil

CPAN package(s):

Fcntl

Time::HiRes

Digest::MD5

Data::Dumper


=head1 AUTHORS

Questions and bugs should be reported to the Yahoo! Mail Access group,
ymail-access@yahoo-inc.com.


=cut
