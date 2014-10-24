#!/home/y/bin/perl -w

# $Id$
# $Revision$

use YMRegister::YMRegister;
use YMRegister::MailMigrateUtil;
use YMCM::AccessStatusUpdate;
use YMCM::AccessTransaction;
use YMCM::AppendMessage;
use YMCM::FetchEmail;
use YMCM::Logger;
use ymailext;
use ydbs;
use ymextKeyUDMigStatus;

# Perl modules:
use POSIX;
use Carp;
use File::Path;
use File::Copy;
use MIME::Base64;
use Sys::Hostname;
use File::Basename;
use Fcntl qw(:flock);
use Time::HiRes qw(gettimeofday tv_interval);
use Data::Dumper;
use URI::Escape;
use strict;
use warnings;


#-------------------------------------------------------------------#
# Globals
#-------------------------------------------------------------------#

my $mailConf = undef;
my $verbose = 1;
my $logger  = undef;
my $applName = undef;
my $imapSSL = 0;
my $imapPeek = 0;
my $skipDeleted = 0;
my $toDelete = 0;
my $dir = undef;
my $imapServer = undef;
my $imapPort = undef;
my $imapAuthExpiryTime = undef;
my $lockTimeRef = undef;
my $popUIDL = undef;
my $popServer = undef;
my $popPort = undef;
# IN and OUR FIFOs. 
my $inPipe = undef;
my $outPipe = undef;
my $configFile = undef;
# Execute till shutDown is set to 1
my $shutDown = 0;
my $adminUid = undef;
my $currUser = undef;
# Function call related variables.
my $func = undef;
my @iParams = undef;
my @output = undef;
my $isDSync = 0;
my $lockMBox = 0;
my $lockts = undef;
my $folderMap = undef;
my $consumer_key = undef;
my $consumer_secret = undef;
my $ignoreFoldersOverLimit = 0;
my $folderIgnore = undef;
my $userFolders = undef;
my $appendMemUpperLimit = 41943040;
my $popUIDLField = undef;
my $popUIDLPrefix = undef;

my $EOM = "_EOM_";
my $I_AM_ALIVE = "I_AM_ALIVE";
my $AUTH_SCHEME = "XOAUTH";


use constant MAILBOX_WRITE_FAILED => 101;
use constant MAILBOX_RENUM_FAILED => 102;
use constant SUCCESS_ACTION => 1;

# base64 encoded key for XOAUTH
my $xoauth_b64_encoded = sub {

  my ($user, $domain) = split('@', $currUser);
  my $requester_hdr = '?xoauth_requestor_id=' . $user . '%40' . $consumer_key;
  my $url = "https://mail.google.com/mail/b/" . $currUser . '/imap/' . $requester_hdr;
  my $cmd = "/home/y/bin/oauth.py $currUser $consumer_key $consumer_secret $url 2>&1";

  my $ret = qx/$cmd/;
  if ($?) {

    $logger->logErr("oauth.py failed: $ret");
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

  return encode_base64($xoauth_request, '');
};

sub dumpMemory
{
  my @mem = `ps aux | grep \"$$\"`;
  my($results) = grep !/grep/, @mem;

  chomp $results;
  $results =~ s/^\w*\s*\d*\s*\d*\.\d*\s*\d*\.\d*\s*//g;
  $results =~ s/pts.*//g;
  my ($vsz,$rss) = split(/\s+/,$results);
  $logger->logInfo("Virt: $vsz RES: $rss");
}

sub openLogFile($) {

  my($errFile) = @_;

  unless (open(ERR, ">> $errFile")) {
    return undef;
  }

  my $errHandle = \*ERR;

  return $errHandle;
}

### load Sky config file for mail migration.
sub loadConfigFile($) {

  my ($fp) = @_;

  unless (open(FN, "< $fp")) {
    return undef;
  }

  my $line;
  my $content = '';
  while($line = <FN>) {
    $content .= $line;
  }
  close(FN);

  my $REQFCONFIG;
  eval $content;
  if ($@) {
    cluck("eval content failed");
    return undef;
  }

  return $REQFCONFIG;
}


sub process_begin($) {

  my ($reqName) = @_;

  # Get lock parameters for locking
  my $lockTime = $mailConf->{lockTime};
  $lockTime = (60*60) unless (defined $lockTime);
  my $imapTTL = $mailConf->{imapTTL};
  $imapTTL = (60*60) unless (defined $imapTTL);
  my $actionTime = $mailConf->{actionTime};
  $actionTime = (10*60) unless (defined $actionTime);

  # Skip the request if a lock cannot be acquired for it.
  unless (YMRegister::MailMigrateUtil::lockBtTxRequest(
      $reqName, $lockTime)) {
    $logger->logInfo("Can't acquire lock for the event $reqName");
    print "Can't acquire lock for the event $reqName\n";
    return undef ;
  }

  $logger->logInfo("Acquired lock for request '$reqName'");

  my $lockTimeRef = YMRegister::MailMigrateUtil::genLockTimeRef (
    $imapTTL, $reqName,
    $lockTime, $actionTime);

  return $lockTimeRef;

}

sub process_end($) {

  my ($reqName) = @_;

  # Unlock the request.
  YMRegister::MailMigrateUtil::unlockBtTxRequest($reqName);
  $logger->logInfo("Released lock for request '$reqName'");


}


sub init($) {

  my ($mailConfFile) = @_;

  $mailConf = loadConfigFile($mailConfFile);

  unless(defined($mailConf)) {

    return 0;

  }

  $applName = $mailConf->{applName};

  my $baseLogDir = $mailConf->{baseLogDir};

  unless (defined $baseLogDir) {

    $baseLogDir = '/rocket/accessMail/' . $applName;
  }

  my $err = openLogFile("$baseLogDir/log/error");

  unless(defined($err)) {

    return 0;

  }


  YMRegister::MailMigrateUtil::setLogHandle($err);
  YMRegister::MailMigrateUtil::setVerbose($verbose);
  YMRegister::MailMigrateUtil::setLogApplName($applName);

  $logger = new YMCM::Logger($err, $applName, $verbose);
  $logger->setLogHandle($err);
  $logger->setVerbose($verbose);
  $logger->setAppName($applName);
  $logger->setSuccessAction(SUCCESS_ACTION());


  $folderMap = $mailConf->{'folder-map'};
  my $folderCharMap = $mailConf->{'folderCharMap'};
  $folderIgnore = $mailConf->{'folderIgnore'};

  $imapSSL = $mailConf->{'imapSSL'};
  $imapPeek = $mailConf->{'imapPeek'};
  $skipDeleted = $mailConf->{'imapSkipDeleted'};
  $toDelete = $mailConf->{'toDelete'};

  $dir = $mailConf->{'mailStorageBaseDir'};


  # Connect via stunnel
  $imapServer=$mailConf->{'iServer'};
  $imapPort= $mailConf->{'iPort'};
  $imapAuthExpiryTime = $mailConf->{imapAuthExpiryTime};

  # POP UIDL
  $popUIDL = $mailConf->{'popUIDL'};
  $popServer = $mailConf->{'popServer'};
  $popPort = $mailConf->{'popPort'};

  # Delta sync
  $isDSync = $mailConf->{isDSync};

  # Allow first 512 folders to be written and ignore rest of them
  $ignoreFoldersOverLimit = $mailConf->{ignoreFoldersOverLimit};

  # Memory upper limit while writing messages to Y Mbox in bytes
  $appendMemUpperLimit = $mailConf->{appendMemUpperLimit};

  # POP UIDL can be fetched using this IMAP field
  $popUIDLField = $mailConf->{popUIDLField};
  if (exists $mailConf->{popUIDLPrefix} && defined $mailConf->{popUIDLPrefix}) {

    $popUIDLPrefix = $mailConf->{popUIDLPrefix};
  }

  # Get user folders
  if (exists $mailConf->{userFolders} && defined $mailConf->{userFolders}) {

    $userFolders = $mailConf->{userFolders};
  }

  # Lock migrated Mailbox
  if (exists $mailConf->{lockMBox} && defined $mailConf->{lockMBox}) {

    $lockMBox = $mailConf->{lockMBox};

    if (exists $mailConf->{lockTS} && defined $mailConf->{lockTS}) {

      $lockts = $mailConf->{lockTS};
    }
  }

  if (exists $mailConf->{verbose} && defined $mailConf->{verbose}) {

    $verbose = $mailConf->{verbose};
  }

  YMCM::FetchEmail::setFolderCharMap($folderCharMap);
  YMCM::FetchEmail::setFolderIgnore($folderIgnore);
  YMCM::FetchEmail::setMsgUniqueIdField("UidValidityUid");

  return 1;

}


sub mapFetchMailErrorStatus($) {

  my ($status) = @_;
  # 0 -> success
  my $retVal = 0;

  if($status == 1) {
    # Lock acquire error 
    $retVal = 1;
  } elsif ($status == 102) {
    # User authentication failed
    $retVal = 2;
  }
  elsif ($status == 109) {
    # Connection failed
    $retVal = 3; 
  }
  elsif ($status == 1109) {
    # POP connection failed
    $retVal = 5;
  }
  elsif ($status == 7) {
    # Fork failed
    $retVal = 7;
  }
  else {
    # Unmapped error
    $retVal = 4;
  }

  return $retVal;

}

sub createFileInMbox($$$)
{

  my ($sid, $silo, $file) = @_;

  my $mb_path = Mailbox::mail_path($sid, 'yahoo', $silo);

  if (-e $mb_path) {

    my $full_path = $mb_path . '/' . $file;
    unless (-e $full_path) {

      symlink('/dev/null', $full_path);
    }
  }
}

sub removeFileInMbox($$$)
{
  my ($sid, $silo, $file) = @_;

  my $mb_path = Mailbox::mail_path($sid, 'yahoo', $silo);

  if (-e $mb_path) {

    my $full_path = $mb_path . '/' . $file;
    if (-e $full_path) {

      unlink($full_path);
    }
  }
}

sub writeStatus($$)
{
  my ($fileName, $statusRef) = @_;

  my $OUT;
  unless (open($OUT, ">", $fileName)) {

    $logger->logErr("Can't open $fileName for writing: $!");
    return 0;
  }

  my $dmp = Data::Dumper->Dump([$statusRef], [ qw(statusRef) ]);
  print $OUT $dmp;
  close($OUT);

  return 1;
}

sub readStatus($)
{
  my ($fileName) = @_;

  my $IN;
  unless (open($IN, "<", $fileName)) {

    $logger->logErr("Can't open $fileName for reading: $!");
    return undef;
  }

  local $/ = undef;
  my $content = <$IN>;
  close($IN);

  my $statusRef;
  eval($content);
  if ($@) {

    $logger->logErr("Eval failed for $fileName");
    return undef;
  }

  unlink($fileName);
  return $statusRef;
}

sub removeTempMailDir($$$)
{
  my ($sid, $silo, $success) = @_;
  my $rmDir = "$dir/$sid";

  $logger->logInfo("--removeTempMailDir-- isDSync: $isDSync lockMBox: $lockMBox success: $success");
  if (($isDSync && $lockMBox) ||
    ($isDSync && !$lockMBox && !$success)) {

    my $f1 = time() . "_" . $$;
    move("$rmDir/.info_dsync", "/tmp/.info_dsync_$f1");
    move("$rmDir/.info_popuidl", "/tmp/.info_popuidl_$f1");
    # Uncomment for debugging
    move("$rmDir/.info", "/tmp/.info_$f1");
    print "info file copied at: /tmp/.info_$f1\n";

    $logger->logInfo("Removing directory $rmDir");
    YMCM::AppendMessage::recursiveEmptyDir($rmDir);

    if (! -d $rmDir) {

      if (!mkdir($rmDir, 0755)) {

        $logger->logErr("Failed to create $rmDir");
      }
    }

    move("/tmp/.info_dsync_$f1", "$rmDir/.info_dsync");
    move("/tmp/.info_popuidl_$f1", "$rmDir/.info_popuidl");

    # Lock MBox or keep it locked
    createFileInMbox($sid, $silo, 'YM_DO_NOT_REMOVE');
    if (defined $lockts) {

      my $f = 'norebuild.' . $lockts;
      createFileInMbox($sid, $silo, $f); 
    }
    return 0;
  }
  elsif (!$isDSync ||
    ($isDSync && !$lockMBox && $success)){

    $logger->logInfo("Removing directory $rmDir completely");
    YMCM::AppendMessage::recursiveEmptyDir($rmDir);

    removeFileInMbox($sid, $silo, 'YM_DO_NOT_REMOVE');
    if (defined $lockts) {

      my $f = 'norebuild.' . $lockts;
      removeFileInMbox($sid, $silo, $f); 
    }
    return 1;
  }
}

sub rectifyMsgIds($sid, $silo)
{
  my ($sid, $silo) = @_; 

  # Read uidl => msgid map from file
  my $yMigUidlMsgId = undef;

  if (open (UIDLMSGID, "$dir/$sid/.info_dsync")) {

    # Read into variable
    local $/ = undef;
    my $str = <UIDLMSGID>;
    eval $str;
    close(UIDLMSGID);
  }
  else {

    $logger->logInfo("open $dir/$sid/.info_dsync file for reading failed");
    return;
  }

  # Check if previously rectified
  if (exists $yMigUidlMsgId->{'rectified'} &&
    defined $yMigUidlMsgId->{'rectified'} &&
    $yMigUidlMsgId->{'rectified'}) {

    $logger->logInfo("MsgId rectification done already, skipping...");
  }

  my $mailbox = Mailbox::new();
  my ($ret, $busy) = $mailbox->open($sid, 'yahoo', $silo);

  if ($ret) {

    my @folders = $mailbox->listFolders();

    foreach my $yFolder (@folders) {

      my $folder = $mailbox->getFolder($yFolder);

      unless (defined $folder) {

        $logger->logErr("Folder $yFolder does not exists in Y! Mbox");
        $ret = 0;
        next;
      }   

      my $msgList = MessageList::new();
      unless ($folder->messages($msgList)) {

        $logger->logErr("Failed to get message list folder: $yFolder");
        $ret = 0;
        next;
      }   

      my $numberOfMsgs = $msgList->size();
      for (my $i = 0; $i < $numberOfMsgs; ++$i) {

        # Replace msgIds with correct once
        if (exists $yMigUidlMsgId->{$yFolder} && defined $yMigUidlMsgId->{$yFolder}) {

          my $yFolderRef = $yMigUidlMsgId->{$yFolder};
          my $uidl = $msgList->getUidlAt($i);

          if (exists $yFolderRef->{$uidl} && defined $yFolderRef->{$uidl}) {

            my $msgId = MessageId::new();
            unless ($msgId) {

              $logger->logErr("MsgId creation failed for folder: $yFolder at $i");
              $ret = 0;
              next;
            }   
            unless ($msgList->getMessageIdAt($i, $msgId)) {

              $logger->logErr("getMessageIdAt failed for folder: $yFolder at $i");
              $ret = 0;
              next;
            }   

            my $msgIdStr = $msgId->str();
            if ($msgIdStr ne $yFolderRef->{$uidl}) {

              $yFolderRef->{$uidl} = $msgIdStr;
              $logger->logInfo("Replaced " . $yFolderRef->{$uidl} . " with
                $msgIdStr in folder: $yFolder");
            }
          }
        }
      } # for   
    } # foreach

    $mailbox->close();
  }
  else {

    $logger->logErr("Mailbox open failed, busy: $busy");
  }

  # Write back the updated uidl => msgid map
  if (defined $yMigUidlMsgId) {

    # Set rectified flag
    $yMigUidlMsgId->{'rectified'} = (($ret) ? 1 : 0);

    if (open (UIDLMSGID, ">$dir/$sid/.info_dsync")) {

      # Read into variable
      my $dmp = Data::Dumper->Dump([$yMigUidlMsgId], [ qw(yMigUidlMsgId) ]);
      print UIDLMSGID $dmp;
      close(UIDLMSGID);
    }
    else {

      $logger->logErr("open $dir/$sid/.info_dsync file for writing failed");
      return;
    }
  }
}

sub fetchMail($$$$$$$$) {

  my ($partner, $user, $sid, $silo, $id, $pw, $isRetry, $consumerKey) = @_;
  my ($success, $status, $newdownloaded);
  my $fetchStatus = 0; # success

  $lockTimeRef = process_begin($sid);

  if(!defined $lockTimeRef) {

    return mapFetchMailErrorStatus(1);
  }

  my $fetchResultFile = '/tmp/fetchMail_' . time() . '_' . $$;
  my $writeResultFile = '/tmp/writeMail_' . time() . '_' . $$;

  # Fork a child to carry out fetch operation
  my $childPid = fork();
  unless (defined $childPid) {

    $logger->logErr("Failed to fork a child for fetch operation");
    removeTempMailDir($sid, "ms$silo", 0);
    # Release lock before exiting
    process_end($sid);
    return mapFetchMailErrorStatus(7);
  }

  if ($childPid) {

    $logger->logInfo("Parent process: $$ waiting for fetch child process: $childPid"); 
    print "Parent process: $$ waiting for fetch child process: $childPid\n"; 
    dumpMemory();
    my $pid = waitpid($childPid, 0);
    $logger->logInfo("Fetch child process: $pid exited with status: $?");
    print "Fetch child process: $pid exited with status: $?\n";
  }
  else {

    # Child process

    my $t0 = [gettimeofday];
    my ($mssilo) = "ms$silo";
    $consumer_secret = $pw;
    $consumer_key = $consumerKey;
    $currUser  = $id;
    my %popConfig;

    # Check if Inbox UIDLs need to be fetched using POP3
    if (defined $popUIDL && $popUIDL == 1) {

      $popConfig{popServer} = $popServer;
      $popConfig{popPort}   = $popPort;
      $popConfig{user}      = $currUser;
      $popConfig{adminUid}  = $adminUid;
      $popConfig{adminPass} = $consumer_secret;
      $popConfig{authMech}  = $AUTH_SCHEME;
    }

    # Set attational config parameters
    my %addiConfigHash = (
      isDSync => $isDSync,
      imapAuthExpiryTime => $imapAuthExpiryTime,
      ignoreFoldersOverLimit => $ignoreFoldersOverLimit,
      popUIDLField => $popUIDLField,
      popUIDLPrefix => $popUIDLPrefix,
    );


    $logger->logInfo("Dowloading mail for user $user with sid $sid and silo $mssilo ...");
    dumpMemory();

    ($success, $status, $newdownloaded) =
    YMCM::FetchEmail::FetchMailIMAP($logger, $user, $sid, $mssilo, $id, '', $imapServer, $imapPort, $dir,
      $toDelete, $isRetry, $lockTimeRef, $folderMap, $imapSSL, $imapPeek, $skipDeleted, $AUTH_SCHEME,
      $xoauth_b64_encoded, \%popConfig, \%addiConfigHash);

    dumpMemory();

    # Write return values of FetchMailIMAP to file
    my %statusHash = (
      success => $success,
      status => $status,
      newdownloaded => $newdownloaded,
    );
    writeStatus($fetchResultFile, \%statusHash);

    my $et = tv_interval($t0);
    $logger->logInfo("FetchMail time: $et secs");
    print "FetchMail time: $et secs\n";

    # Exit child process
    exit(0);
  }

  # Parent continue....
  dumpMemory();

  # Read return values of FetchMailIMAP from file
  my $statusRef = readStatus($fetchResultFile);
  $success = ((defined $statusRef) ? $statusRef->{success} : 0);
  $status = ((defined $statusRef) ? $statusRef->{status} : 0);

  my $mailboxSize = 0;
  my $errorMsg = "";


  # Fetch failed for some reason
  if ($success == 0) {

    $logger->logErr("Failed to download mail for user $user.");
    $logger->recordActionStatus($partner, "MailMig", 0, $status, "");
    $fetchStatus = mapFetchMailErrorStatus($status);
    print "fetchStatus: $fetchStatus\n";
    my @statusInfo = statusInfo( $status );
    my $desc = shift @statusInfo;
    if ( defined $desc ) {
      $errorMsg = $desc;
    }
    unless (defined $statusRef) {

      $errorMsg = 'readStatus failed for fetchMail';
    }

    # In case of IMAP timeout error, write what ever is fetched
    # IMAPTIMEDOUT == 103
    if ($status == 103) {

      # Restart the process so that writeMail gets time
      process_end($sid);
      $lockTimeRef = process_begin($sid);
      if (defined $lockTimeRef) {

        $success = 1;
        $errorMsg .= ' for fetchMail, got new lockTimeRef for writeMail';
      }
      else {

        $success = 0;
        $logger->logErr("Unable to get new lockTimeRef for writeMail");
        $errorMsg .= ' Unable to get new lockTimeRef for writeMail';
      }
    }
    else {

      removeTempMailDir($sid, "ms$silo", $success);
    }
  }

  # Fetch was successful
  if ($success == 1) {

    # Fork a child to carry out write operation
    undef $childPid;
    $childPid = fork();
    unless (defined $childPid) {

      $logger->logErr("Failed to fork a child for write operation");
      removeTempMailDir($sid, "ms$silo", 0);
      # Release lock before exiting
      process_end($sid);
      return mapFetchMailErrorStatus(7);
    }

    if ($childPid) {

      $logger->logInfo("Parent process: $$ waiting for write child process: $childPid"); 
      print "Parent process: $$ waiting for write child process: $childPid\n"; 
      dumpMemory();
      my $pid = waitpid($childPid, 0);
      $logger->logInfo("Write child process: $pid exited with status: $?");
      print "Write child process: $pid exited with status: $?\n";
    }
    else {

      # Child process

      my $t0 = [gettimeofday];

      $logger->logInfo("Writing mail to Yahoo mailbox for user $user with sid $sid and silo ms$silo ...");
      dumpMemory();

      my $mboxSize = 0;
      ($success, $mboxSize) = writeMail($partner, $user, $sid, $silo, $id, $pw);

      dumpMemory();

      # Check the status of fetch mail for TOOMANYFOLDERS
      if ($status == 123 && $ignoreFoldersOverLimit && $success == 0) {

        # Indicating success and only first 512 folders have been migrated
        $success = 6;
      }

      # Write retrun status of writeMail to file
      my %statusHash = (
        success => $success,
        mboxSize => $mboxSize,
      );
      writeStatus($writeResultFile, \%statusHash);

      my $et = tv_interval($t0);
      $logger->logInfo("writeMail time: $et secs");
      print "writeMail time: $et secs\n";

      # Exit child process
      exit(0);
    }

    # Parent continue....
    dumpMemory();

    # Read retrun status of writeMail to file
    $statusRef = readStatus($writeResultFile);
    $success = ((defined $statusRef) ? $statusRef->{success} : MAILBOX_WRITE_FAILED);
    $mailboxSize = ((defined $statusRef) ? $statusRef->{mboxSize} : 0);
    unless (defined $statusRef) {

      $errorMsg = 'readStatus failed for writeMail';
    }
  }

  # Parent continue...

  process_end($sid);

  # Check if fetch failed but write passed
  print "write status: $success\n";
  print "fetchStatus: $fetchStatus\n";
  if ($fetchStatus != 0 && ($success == 0 || $success == 6)) {

    $success = $fetchStatus;
  }
  #$success = ($fetchStatus && ($success == 0 || $success == 6)) ? $fetchStatus : $success;
  return ($success, $mailboxSize, $errorMsg);
}

sub mapWriteMailErrorStatus($) {

  my ($status) = @_;
  # 0 -> success
  my $retVal = 0;

  $retVal = MAILBOX_WRITE_FAILED;

  return $retVal;

}

sub writeMail($$$$$$) {

  my ($partner, $user, $sid, $silo, $id, $pw) = @_;

  my ($mssilo) = "ms$silo";
  my ($mboxSize) = 0;

  my ($success,$status, $appendedMsgs) =
  YMCM::AppendMessage::AppendMessage($logger, $user, $sid, $mssilo, $dir,
    $lockTimeRef, $skipDeleted, $isDSync, $appendMemUpperLimit);
  my $removed = removeTempMailDir($sid, "ms$silo", $success);

  unless ($success) {

    $logger->logErr("Failed to write mailbox for user $user.");
    $logger->recordActionStatus($partner, "MailMig", 0, $status, "");
    $success = mapWriteMailErrorStatus($status);

  }
  else {

    $mboxSize = getMboxSize($sid, $mssilo);

    # Perform re-numbering + rebuild only if .norebuild is deleted
#    if ($removed) {

      $logger->logInfo("Renumbering UIDs based on internal date for user $user with sid $sid and silo $mssilo ...");

      for (my $retries = 5; $retries > 0; --$retries) {

        $success = renumberUIDs($sid, $mssilo, $removed);
        last unless ($success);
        sleep (5);
        $logger->logInfo("Renumbering UIDs failed for user $user with sid $sid and silo $mssilo. Retrying in 5 seconds ...");
      }
#    }
#    else {
#
#      $logger->logInfo("Re-numbering + rebuild not performed for user $user with sid $sid and silo $mssilo");
#    }
  }

  return ($success, $mboxSize);
}

sub getMboxSize($$) {

  my ($sid, $mssilo) = @_;
  my $mboxSize = 0;

  my @tstmboxCmdArgs = ("/home/y/bin/ymail_tstmbox", '-i', $sid, '-s', $mssilo, '-z', '2>&1', '|', 'grep', 'Mailbox::size');
  my $tstmboxCmdStat = `@tstmboxCmdArgs`;

  if(($? >>= 8) == 0) {

    # Parse - "Mailbox::size()    : 13682032"
    chomp $tstmboxCmdStat;
    my @nvpSize = split(/:/, $tstmboxCmdStat);
    # Get the last token
    $mboxSize = pop(@nvpSize);
    # trim
    $mboxSize =~ s/^\s+//;
    $mboxSize =~ s/\s+$//;
    $logger->logInfo("Mailbox size for sid $sid and silo $mssilo is $mboxSize bytes");

  }
  else {

    $logger->logErr("Failed to determine mailbox size for sid $sid and silo $mssilo.");

  }



  return $mboxSize;

}

sub renumberUIDs($$$) {

  my ($sid, $mssilo, $removed) = @_;
  my $retVal = 0;

  my @renumCmdArgs = ("/home/y/bin/ymail_renumberUIDs", '-i', $sid, '-s', $mssilo);

  # Do not rebuild if norebuild.xxxxxxxx file is present
  unless ($removed) {

    push (@renumCmdArgs, '-n');
  }
  push (@renumCmdArgs, '2>&1');
  my $renumCmdStat = `@renumCmdArgs`;

  $logger->logInfo("ymail_renumberUIDs returned the following output: $renumCmdStat");
  if(($? >>= 8) != 0) {

    $retVal = MAILBOX_RENUM_FAILED;
    $logger->logErr("Failed to renumber mailbox for sid $sid and silo $mssilo. Return code = $retVal");

  }

  return $retVal;

}

sub readInputParams() {

  my $line = undef;

  $func = undef;
  #clear the input param list.
  @iParams = ();


  chomp($func = <INPIPE>);

  print OUTPIPE length($func) . "\n";

  if($func eq "init" || $func eq "fetchMail" || $func eq "shutdown") {

    while($line = <INPIPE>) {

      chomp($line);    

      print OUTPIPE length($line) . "\n";

      if($line eq $EOM) {
        last;
      }

      push(@iParams, $line);

    }
  }


}

sub process() {

  my $retVal;

  @output = ();

  if($func eq "init") {

    $retVal = init(pop(@iParams));
    push(@output, $retVal); 
  }
  elsif($func eq "fetchMail") {

    my ($partner, $user, $sid, $silo, $id, $pw, $isRetry, $consumerKey);

    $partner = shift(@iParams);
    $user = shift(@iParams);
    $sid = shift(@iParams);
    $silo = shift(@iParams);
    $id = shift(@iParams);
    $pw = shift(@iParams);
    $isRetry = shift(@iParams);
    $consumerKey = shift(@iParams);

    #$pw = 'test1234';

    my ($mboxSize, $errormsg);
    ($retVal, $mboxSize, $errormsg) = fetchMail($partner, $user, $sid, $silo, $user, $pw, $isRetry, $consumerKey);
    push(@output, $retVal); 
    push(@output, $mboxSize);
    if ( $errormsg ne "" ) {
        push(@output, $errormsg);
    }

  }
  elsif($func eq "shutdown") {

    $shutDown = 1;

  }

}

sub writeOutput() {

  my $ack;
  my $line = undef;

  $line = shift(@output);
  while (defined $line)
  {
    print OUTPIPE "$line" . "\n";

    chomp($ack = <INPIPE>);

    $line = shift(@output);
  }

  print OUTPIPE "$EOM" . "\n";

  chomp($ack = <INPIPE>);

}

sub sendAliveMesg() {

  print OUTPIPE "$I_AM_ALIVE" . "\n";

  my $ack;
  chomp($ack = <INPIPE>);

  return 0;
}


sub fileExists($) {

  my ($fileToCheck) = @_;
  my $sleepTime = 0;

  while ( ! -e $fileToCheck) {

    sleep(1);
    $sleepTime++;
    if($sleepTime > 10) { return 0; }

  }

  return 1;

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

#####################
##     Main Loop   ##
#####################
my $argc = @ARGV;
if ($argc < 2) {

    print "Usage: sudo $0 user imap-config-file [send-internal-notif yes/no] [rebuild]\nargc is $argc\n";
    exit;

}

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

print "The new user ID - $> process ID - $$\n";


# Start the migration of mail for the user
my $user =  $ARGV[0];
$configFile = $ARGV[1];
my $sendInternalNotif = $ARGV[2];
my $rebuild = $ARGV[3];
my $consumerKey = 'sky.com';
my $pw = 'yajF3gQiidb1NZUmZqzWyvMy';

#my $consumerKey = 'sso-test-test.sky.com';
#my $pw = 'g2mvQ7z8wzCOB/O6eTB1CNic';

my ($sid, $silo) = findSidSilo($user);

print "Initializing...\n";
init($configFile);

if (defined $rebuild && $rebuild eq 'rebuild') {

  my $cmd = "/home/y/bin/ymail_rebmbox -i $sid -s ms$silo -R -m2 2>&1";
  print "Running rebuild: $cmd\n";
  my $ret = qx/$cmd/;
  print "$ret\n";
}

# Folder wise migration

my @userFoldersCopy = @$userFolders;

print "Folders to migrate: @userFoldersCopy\n";

my $keepMigrating = 1;

while ($keepMigrating) {

  # Determine the folder to migrate
  my $folderToMigrate = pop (@userFoldersCopy);
  my @foldersToIgnore = @$folderIgnore;

  if (defined $folderToMigrate) {

    print "Migrating folder: $folderToMigrate\n";
    push (@foldersToIgnore, @userFoldersCopy);
  }
  else {

    # All folders are migrated
    # Final migration with original ignore list
    print "All folders migrated, final migration\n";
    $keepMigrating = 0;
  }

  print "Ignored folders: @foldersToIgnore\n";
  YMCM::FetchEmail::setFolderIgnore(\@foldersToIgnore);

  # Start migratining....
  my ($retVal, $mboxSize, $errormsg, $attempt) = (1, 0, '', 1);
  while ($retVal) {

    print "Attempt $attempt:  Fetching mailbox for SID $sid SILO $silo\n";
    ($retVal, $mboxSize, $errormsg) = fetchMail('Sky', $user, $sid, $silo, $user, $pw, 0, $consumerKey);

    print "User: $user Status: $retVal MBox size: $mboxSize Error: $errormsg\n";

    if (defined $sendInternalNotif && $sendInternalNotif eq 'yes') {

      print "Sendig internal notification...\n";

      my $notifMsg;
      my $rc;

      if ($retVal) {

        $notifMsg = "Manual migration ";
        $rc = 'R';
      }
      else {

        $notifMsg = "Manual migration ";
        $rc = 'S';
      }

      $notifMsg .= "MBox: " . $mboxSize . " " . $errormsg;

      my $url = "http://mrs01.mail.sp1.yahoo.com/lca/report?partner=Sky&app=SkyMailResync&rc=$rc&uid=$user&seplogfile=true&fs=" . uri_escape($notifMsg);

      my $cmd = "curl \"$url\"";
      my $ret = qx/$cmd/;
      print "$ret\n";
    }
    ++$attempt;
  }

  # Migration of folder is successful
}


