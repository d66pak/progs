# Transfer partner mail to Y! mailbox.

package MyMailMigrateUtil;

use strict;
use Time::HiRes qw(gettimeofday tv_interval);
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
require AutoLoader;

@ISA = qw(Exporter AutoLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(

);
$VERSION = '0.01';


# Preloaded methods go here.

# Autoload methods go after __END__, and are processed by the autosplit program.


#-------------------------------------------------------------------#
# Required modules
#-------------------------------------------------------------------#

# Y! Mail modules:
#use lib "/rocket/perl";
#use lib "/rocket/perl/blib/lib";
#use lib "/rocket/perl/blib/arch";

use YMAIL::Util;
use YMRegister::YMRegister;
use MsgStore;

#use Yahoo::Crypto;
use ysecure;
use ysecure qw(ycrSignMD5y64);

# Perl modules:
use POSIX;
use Carp;
use Fcntl qw(:flock);
use Date::Manip;

use URI;
use LWP;
use URI::Escape; 
use HTTP::Request;
use HTTP::Request::Common;

# yinst'd CPAN modules:
#use lib '/home/y/lib/perl5/site_perl/5.6.1';
#use lib '/home/y/lib/perl5/site_perl/5.6.1/i386-freebsd';

# non-yinst'd CPAN modules.
#use lib '/rocket/perl/lib/site_perl/5.6.1';
#use lib '/rocket/perl/lib/site_perl/5.6.1/i386-freebsd';

use Mail::IMAPClient;
use Mail::POP3Client;
use Time::HiRes qw(gettimeofday tv_interval);

local $SIG{__WARN__} = \&Carp::cluck;


#-------------------------------------------------------------------#
# Globals
#-------------------------------------------------------------------#

my $err = undef; # File handle
my $verbose = undef;
my $applName = 'bt_tx';

###################################################################
# Logs
###################################################################

# Log message in error file.
sub logMsg($$) {
    my ($msg, $note) = @_;

    if (defined $err) {
	my $time = scalar(localtime);
	my $pid = POSIX::getpid();
	my $str = "[$time] ($pid) ($applName-$note): $msg\n";
	flock($err, LOCK_EX);
	print $err $str;
	flock($err, LOCK_UN);
    }
    else {
      YMAIL::Util::ilogger("($applName-$note): $msg");
    }
}

sub logInfo($) {
    logMsg(shift, 'info') if ($verbose);
}

sub logErr($) {
    logMsg(shift, 'error');
}

sub logEvent($) {
    logMsg(shift, 'info');
}

sub logMon($) {
    logMsg(shift, 'monitor');
}

sub logIMAP($) {
    logMsg(shift, 'imap');
}

sub logPOP($) {
    logMsg(shift, 'pop');
}

sub logDebug($) {
    if (defined $verbose) {
        print shift, "\n" if ($verbose >= 2);
    }
}

sub printDebug($) {
    print shift, "\n";
}

sub isDebugMode() {
    if (defined $verbose) {
        if ($verbose >= 2) {
            return 1 
        }
    }
    return 0; 
}

sub getLogHandle() {
    return $err;
}

sub setLogHandle($) {
    my ($h) = @_;
    $err = $h;
}

sub setLogApplName($) {
    my ($an) = @_;
    $applName = $an;
}

# Set log file handle and debug mode.
sub setLogFile($$) {
    my ($errFile, $mode) = @_;

    unless (open(ERR, ">> $errFile")) {
	printDebug("ERROR: Failed to open log file $errFile: $!");
	return 0;
    }

    $err = \*ERR;
    $verbose = $mode;
    return(1);
}

sub setVerbose($) {
    my ($mode) = @_;
    $verbose = $mode;
}

sub closeLogFile() {
    if (defined $err) {
	close($err);
        $err = undef;
    }
    $verbose = undef;
}

###################################################################
# Lock utilities
###################################################################

sub genBtTxLockString($) {
    my ($sid) = @_;
    my $fp = 'bt_tx-' . $sid;
    return $fp;
}

sub lockBtTxRequest($$) {
    my ($sid, $seconds) = @_;
    my $fp = genBtTxLockString($sid);
    return LockClient::lock($fp, $seconds, 2);
}

sub unlockBtTxRequest($) {
    my ($sid) = @_;
    my $fp = genBtTxLockString($sid);
    LockClient::unlock($fp);
}

sub genLockTimeRef($$$$) {
    my ($ttl, $sid, $lockTime, $actionTime) = @_;

    my $fp = genBtTxLockString($sid);

    my $currentTime = time();
    $actionTime = 0 if ($actionTime < 0);
    if ($lockTime < ( (10*60) + $actionTime)) {
        $lockTime = ( (10*60) + $actionTime);
    }
    my $reqStart = $currentTime;
    my $lockStart = $currentTime;
    my @lockArr = ($ttl, $fp, $lockTime, $actionTime,
                   $reqStart, $lockStart);
    return \@lockArr;
}

sub verifyLockTime($) {
    my ($lockTimeRef) = @_;

    return 1 unless defined $lockTimeRef;

    my ($ttl, $fp, $lockTime, $actionTime, $reqStart, $lockStart) =
               @$lockTimeRef;
    my $currentTime = time();

    # Spending too much time already?
    if ( ($currentTime - $reqStart) >= $ttl ) {
        logErr("Approaching max lock time limit.  Quit for now; try later.");
        return 0 
    }

    return 1 unless defined $fp;

    # Is there enough time for the next action?
    if ( ($lockTime - ($currentTime - $lockStart)) <= $actionTime ) {
        logInfo("Approaching lock time limit. Reacquire lock");
        $$lockTimeRef[5] = $currentTime;

        #LockClient::unlock($fp);
        return LockClient::lock($fp, $lockTime, 2);
    }

    return 1;
}

# Sometimes there are some unusual actions, such as 40M single messages.
# We need to increase the lock for those mega-action.
# The second parameter, $numberOfActions, indicates how many actions
# are equivalent to this single mega-action.
sub increaseLockTime($$) {
    my ($lockTimeRef, $numberOfActions) = @_;

    return 1 unless defined $lockTimeRef;

    my ($ttl, $fp, $lockTime, $actionTime, $reqStart, $lockStart) =
               @$lockTimeRef;

    return 1 unless defined $fp;

    my $megaActionTime = $numberOfActions * $actionTime;
    if ($megaActionTime > $lockTime) {
        $lockTime = $megaActionTime;
    }

    my $currentTime = time();
    $$lockTimeRef[2] = $lockTime;
    $$lockTimeRef[5] = $currentTime;
    logEvent("Need to increase lock time to $megaActionTime for this mega action."); 
    return LockClient::lock($fp, $lockTime, 2);
}


###################################################################
# Address Book and Signature Migration
###################################################################

# We use HTTP POST request to import address book data to Yahoo account.
# This function basically generate a POST request and send to a Yahoo
# address book server.
sub ImportAddresBook($$$$) {
    my ($yid, $csvData, $abServer, $randNum) = @_;

    my $url = "http://" . $abServer . "/yab2/us/";
    $url = $url . $randNum . "/" if (defined $randNum);
    $url = $url . "?";

    # Generate the signature. We hardcoded the secret here
    my $secret = "HHvJBQWZewSkYDPyN5cYagk87vI87ZmsbXZZMoxonGU-";
    my $sig = ycrSignMD5y64($url, $secret);

    # Append the signature to the url.
    $url = $url . "&sig=" . $sig;

    logInfo("<AB import> url:$url, yid:$yid, sig:$sig");

    my $ua = new LWP::UserAgent;
    my $res = $ua->request(
        POST $url,
        Content_Type => 'form-data',
        Content      => [#sig             => $sig,
                          A               => 'X',
                          Upload          => [undef, "yahoo.csv", 
                                              Content_Type => 'application/octet-stream', 
                                              Content      => $csvData
                                             ],
                          redesign_import => '1',
                          #km             => '1',
                          "auth-type"     => "SIG",
                          "yid"           => $yid,
                          btmigration     => '1',
                        ]
    );

    if ($res->is_success) {
        my $content = $res->content;
        $content =~ s/\r//g;
        $content =~ s/\n//g;
        logInfo("<AB import> Response for $yid: $content");

        if($content eq "1") {
            return 1;
        }
        else {
            return 0;
        }
    } else {
        logInfo("<AB import> No Response for $yid");
        return undef;
    }
}

# Call to MsgStore to save user's
# signature to msdb3 file.
sub saveMailSignature($$$) {
    my ($login, $active, $signature) = @_;

    my $startTime = [gettimeofday];

    my ($sid, $silo) = (undef, undef);
    my ($rcode, $user) = YMRegister::YMRegister::openUserSilently($login);
    unless (defined $user) {
        logErr("<UDB> Failed to open user $login");
        return 0;
    }

    # Get sid.
    $sid = $user->sid();
    unless (defined $sid) {
        logErr("<UDB> Missing sid for user $login");
        return 0;
    }
    logInfo("sid: $sid") if (defined $sid);

    # Get silo.
    $silo = $user->silo();
    unless (defined $silo) {
        logErr("<UDB> Missing silo for user $login with sid $sid");
        return 0;
    }
    logInfo("Silo: $silo") if (defined $silo);


    # Open mailbox.
    my $mailbox = Mailbox::new();

    # The reason to open mailbox is to lock the mailbox. 
    # Is there any good way to do it?
    my ($ret, $busy) = $mailbox->open($sid, "yahoo", $silo);

    unless ($ret) {
        if ($busy) {
            logErr("Mailbox open failed: busy");
        }
        else {
            logErr("Mailbox open failed: non-busy");
        }
        # No inbox.
        return 0;
    }

    my $msDb = MsgStoreDB::new();
    $ret = $msDb->open($sid, $silo, 4);

    # UDB_SUCCESS is 0? I need to check it again.
    my $UDB_SUCCESS = 0;
    unless ($ret == $UDB_SUCCESS) {
        logErr("<Mail Sig> Open MsgStoreDB failed for sid=$sid, silo=$silo");
        return 0;
    }

    if ($msDb->get("sig")) {
        logInfo("<Mail Sig> Found existing mail signature for sid=$sid, silo=$silo");
        return 1;
    }

    $msDb->set("sig", $signature);

    # Turn on/off the "Add signature to all messages as default" flag.
    # That flag is stored in Udb with key name of "ym_mail3/SA".
    $user->ymDb_User::setUdbMail("ym_mail3", "SA", $active);
    unless ($user->ymDb_User::commit()) {
        logErr("<Mail Sig> Failed to save the change on the mail signature flag for user $login");
        return 0;
    }

    my $elapsedTime = tv_interval($startTime);
    logInfo("<Mail Sig> Saved email signature in $elapsedTime seconds");

    return 1;
}

###################################################################
# Message Store Utitlities
###################################################################

# Open a mail mail folder and retrieve message UIDLs.
sub getUidlList($$$) {
    my ($folderName, $sid, $silo) = @_;
    my $folder = undef;

    # Open mailbox.
    my $mailbox = Mailbox::new();

    my ($ret, $busy) = $mailbox->open($sid, "yahoo", $silo);

    unless ($ret) {
	if ($busy) {
	    logErr("Mailbox open failed: busy");
	} 
	else {
	    logErr("Mailbox open failed: non-busy");
	}
	# No inbox.
	return (0, undef);
    }
    else {
	$folder = $mailbox->getFolder($folderName) if (defined $mailbox);
	unless (defined $folder) {
	    logInfo("$folderName doesn't exist for sid=$sid, silo=$silo");
	    return (1, undef);
	}
    }

    my $msgList = MessageList::new();
    my $success = $folder->messages($msgList);
    unless ($success) {
        logErr("Failed to get message list from folder $folderName");
        return (0, undef);
    }
    my $numberOfMsgs = $msgList->size();
    my $ii;
    my @uidlList = ();
    for($ii = 0; $ii < $numberOfMsgs; ++$ii) {
        my $uidl = $msgList->getUidlAt($ii);
        push @uidlList, $uidl if($uidl);
    }

    return (1, \@uidlList);
}

# Open mail folder and retrieve message UIDLs.
# Returns UIDL => 1 hash which is efficient for searching UIDLs
sub getUidlHash($$$) {
  my ($folderName, $sid, $silo) = @_;
  my $folder = undef;
  my @folderList = ();

  # Open mailbox.
  my $mailbox = Mailbox::new();

  my ($ret, $busy) = $mailbox->open($sid, "yahoo", $silo);

  unless ($ret) {
    if ($busy) {
      logErr("Mailbox open failed: busy");
    } 
    else {
      logErr("Mailbox open failed: non-busy");
    }
    # No inbox.
    return (0, undef, undef, undef);
  }
  else {
    $folder = $mailbox->getFolder($folderName);
    @folderList = $mailbox->listFolders();
    unless (defined $folder) {
      logInfo("$folderName doesn't exist for sid=$sid, silo=$silo");
      return (1, 0, \@folderList, undef);
    }
  }

  my $msgList = MessageList::new();
  my $success = $folder->messages($msgList);
  unless ($success) {
    logErr("Failed to get message list from folder $folderName");
    return (0, undef, undef, undef);
  }
  my $numberOfMsgs = $msgList->size();
  my $ii;
  my %uidlHash = ();
  for($ii = 0; $ii < $numberOfMsgs; ++$ii) {

    my $uidl = $msgList->getUidlAt($ii);
    if ($uidl) {

      $uidlHash{$uidl} = 1;
    }
  }

  return (1, 1, \@folderList, \%uidlHash);
}

# Append messages to a folder. 
# Return if flag that indicates if there's any problem w/ the folder.
# If the folder doesn't exist and cannot be created the flag will set to false.
sub appendMsgs($$$$$$$) {
    my ($folderName, $msgs, $uidls,$flagLists,$sid,$silo, $appendedMsgs) = @_;

    # We cache a few downloaded messages in memory, open the mailbox,
    # write the messages to the mailbox, and close the mailbox right
    # away.  This way, the amount of time this script holds onto a
    # mailbox can be minimized.

    my $folder = undef;

    # Open mailbox.
    my $mailbox = Mailbox::new();

    my $startTime = [gettimeofday];

    my ($ret, $busy) = $mailbox->open($sid, "yahoo", $silo);

    unless ($ret) {
	if ($busy) {
	    logErr("Mailbox open failed: busy");
	} 
	else {
	    logErr("Mailbox open failed: non-busy");
	}
	# No inbox.
	return (0, 1);
    }
    else {
	# Create the folder if it doesn't exist. 
	$folder = $mailbox->getFolder($folderName) if (defined $mailbox);
	unless (defined $folder) {
	    $mailbox->createMailFolder($folderName);
	}
	$folder = $mailbox->getFolder($folderName) if (defined $mailbox);
	unless (defined $folder) {
	    logErr("$folderName cannot be created for sid=$sid, silo=$silo");
	    return (1, 0);
	}
    }

    logInfo("Mailbox opened, folder $folderName found for sid=$sid, silo=$silo");

    # if $msgs is undefined it means it's for folder creation only
    unless (defined $msgs) {
        return (1, 1);
    }

    my $msgCount = 0;
    my $totalMsgs = @$msgs;
    my $i = 0;
    for ($i = 0; $i < $totalMsgs; ++ $i) {
        my $msg = $$msgs[$i];
        my $flagVals = $$flagLists[$i];
        my $uidl = undef;
        $uidl = $$uidls[$i] if (defined $uidls);

        # Get a new unique message id.
        my $msgId = MessageId::new();
        my $errMsg = undef;
        unless ($msgId) {
	    $errMsg = "Get message ID failed";
	}
	else {
	    my $size = length($msg);
	    my $appendret = undef;
            # Appending 40M message to MsgStore will result in the
            # program abort from the middle. Add logic to work around
            if ($size < 40000000) {
                if (defined $uidl) {
	            $appendret = $folder->appendMsgExtUIDL($msg, $size,
                                                       $msgId, $uidl);
                }
	        else {
	            $appendret = $folder->appendMsg($msg, $size, $msgId);
	        }
	    }
	    unless ($appendret) {
	        $errMsg = "Failed to append message of size $size";
	    }
	    else {
	        # Update flags
                my $flags = Flags::new();
                if ($flags) {
                    $flags->unsetAll();
                    foreach my $f (@$flagVals) {
                        if ($f eq "\\Answered") {
                            $flags->setAnswered();
                        }
                        elsif ($f eq "\\Flagged") {
                            $flags->setFlagged();
                        }
                        elsif ($f eq "\\Deleted") {
                            $flags->setDeleted();
                        }
                        elsif ($f eq "\\Seen") {
                            $flags->setSeen();
                        }
                        elsif ($f eq "\\Draft") {
                            $flags->setDraft();
                        }
                        elsif ($f eq "\\Recent") {
                            $flags->Flags::setRecent();
                        }
                    }
	        }

	        if ($flags && $folder->writeFlags($flags, $msgId)) {
	            # Success!
	            push @$appendedMsgs, $i;
	            ++$msgCount;
	        }
	        else {
	            $errMsg = "Failed to append message of size $size";
	        }
	    }
	}
        if (defined $errMsg) {
            logErr("Failed to append message for sid=$sid,silo=$silo, " .
                   "folder=$folder: $errMsg");
        }
    }

    # Set PIK folder state to 'out of sync'.
    $mailbox->setPIKFolderOutOfSync() if ($mailbox);

    # Close and therefore unlock the mailbox.
    #$mailbox->close() if ($mailbox);

    my $elapsedTime = tv_interval($startTime);

    logInfo("Appended $msgCount messages to fodler $folderName in $elapsedTime seconds");
    logInfo("Mailbox closed for sid=$sid, silo=$silo");

    return (1, 1);
}

###################################################################
# IMAP Utitlities
###################################################################

sub endIMAPSession($) {
    my ($sess) = @_;

    my $imapSession       = $$sess[0];

    my $ret = 1;
    if (defined $imapSession) {
        logIMAP("IMAP session closed");
        $ret = $imapSession->logout();
    }

    $$sess[0] = undef;
    $$sess[1] = undef;
    return $ret;
}

# Connect to imap server.
sub openIMAPConnection($$$$$) {
    my ($sess, $id, $pw, $server, $port) = @_;

    if (defined $sess) {
        my ($imapSession, $lastSessionLogout) = ($$sess[0], $$sess[1]);
        $$sess[1]          = undef;

        if ((defined $imapSession) and (defined $lastSessionLogout)) {
            if ((time() - $lastSessionLogout) >= 10) {
                $imapSession = undef;
            }
        }
        if (defined $imapSession) {
            return ($imapSession, 1);
        }
    }

    my ($x, $domain) = split('@', $id, 2);
    my $imap = Mail::IMAPClient->new(
				   Server => $server,
				   #User => $x,
				   #Password => $pw,
				   Port => $port,
				   Uid => 0,
				   Timeout => 5*60
				   );
    my $connectionOk = 0;
    if (defined $imap ) {
        $connectionOk = 1;
        $imap->User($x);
        $imap->Password($pw);
        $imap = $imap->login();
    }

    if (defined $sess) { # Session was started
        $$sess[0] = $imap;
    }

    unless (defined $imap) {
	logErr("IMAP login failed");

	# External error.  Try again later.
	return (undef, $connectionOk);
    }

    logIMAP("IMAP login OK");

    return ($imap, $connectionOk);
}

# Close the IMAP connection gracefully.
sub closeIMAPConnection($$) {
    my ($sess, $imap) = @_;
    
    my $ret = 1;
    if (defined $sess) { # Session was started
        $$sess[1] = time();
    }
    else {
        logIMAP("IMAP closed");
        $ret = $imap->logout();
    }
    return $ret;
}

# Get list of message flags
sub getMsgFlags {
    my ($imap, $msgNumber) = @_;
    my @msgs = ();
    push @msgs, $msgNumber;
    my $flaghash = $imap->flags(\@msgs);

    if ( defined $flaghash) {
        my @ret = @{$flaghash->{$msgNumber}};
        return \@ret;
    }
    else {
        return undef;
    }
}

sub selectMessages {
    my ($imap, $totalMsgs, $uidsToSkip, $skipDeleted) = @_;

    $imap->Uid(0);
    my $hash = $imap->fetch_hash("UID", "FLAGS", "RFC822.SIZE");
    $imap->Uid(1);
    my @msgInfoList = ();
    my $noMsgFound = 1;
    foreach my $mid ( keys %$hash) {
        $noMsgFound = 0;
        my $val = $$hash{$mid};
        my ($uid, $flag, $size) = (undef, undef, undef);
        my $toSkip = 0;
        foreach my $k ( keys %$val) {
            if ($k eq "UID" or $k eq "uid") {
                $uid = $$val{$k};
                if (defined $uidsToSkip) {
                    if (exists $$uidsToSkip{$uid} and
                        defined $$uidsToSkip{$uid}) {
                        $toSkip = 1;
                    }  
                }  
            }
            elsif ($k eq "FLAGS" or $k eq "FLAGS") {
                my $flagStr = $$val{$k};
                if (defined $flagStr) {
                    my @flagArr = split(" ", $flagStr);
                    foreach my $f (@flagArr) {
                        if (defined($skipDeleted) && ($skipDeleted) && ($f eq "\\Deleted")) {
                            $toSkip = 1;
                            print("Skip a deleted message\n");
                        }
                    }
                    $flag = \@flagArr;
                }
            }
            elsif ($k eq "RFC822.SIZE" or $k eq "rfc822.size") {
                $size = $$val{$k};
            }
        }
        return undef unless (defined $uid and defined $size);
        unless (defined $flag) {
            my @flagArr1 = ("\\Recent");
            $flag = \@flagArr1;
        }
        my @msgInfoElements = ($uid, $flag, $size);
        push @msgInfoList, \@msgInfoElements unless $toSkip;
    }

    if ($totalMsgs > 0 and $noMsgFound) {
        my $errMsg = $imap->LastError();
        logErr("IMAP FETCH hash error: $errMsg") if (defined $errMsg);
        return undef;
    }
    else {
        return \@msgInfoList;
    }
}

# Get message uids 
sub getAllUids {
    my ($imap) = @_;
    my $uids = $imap->search("ALL");
    return $uids;
}

sub showMsgFlags {
    my ($flags) = @_;
    print "Flags: [[[";
    foreach my $k (@$flags) {
        # print: Message 1: \Flag1, \Flag2, \Flag3
        print "($k)";
    }
    print "]]]\n";
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
                        (?:"[^"]*"|NIL)\s+	 # "delimiter" or NIL
                        (?:"([^"]*)"|(.*))\x0d\x0a$  # Name or "Folder name"
                /ix)
        {
	    my $fdr = ($1||$2);
            $massageFolder = 1 if $1 and !$imap->exists($fdr) ;
            my $s = (split(/\s+/,$list[$m]))[3];
	    my $sep = "NIL";
            if (defined($s) && length($s) >= 3) {
                $sep =  ($s eq 'NIL' ? 'NIL' : substr($s, 1, length($s)-2) );
            }
            push @folders, $sep . " " . $fdr unless ($massageFolder);
        }
    } 

    # for my $f (@folders) { $f =~ s/^\\FOLDER LITERAL:://;}
    my @clean = (); my %memory = ();
    foreach my $f (@folders) { push @clean, $f unless $memory{$f}++ }

    return \@clean;
}

# Select a IMAP folder and get the folder status.
sub selectImapFolder($$$) {
    my ($imap, $folder, $useSelect) = @_;

    my $msgCount = $imap->message_count($folder);
    unless (defined $msgCount) {
        logErr("IMAP failed to query message count for folder $folder");
        return undef;
    }

    my $folderSelectOk = 1;
    if(lc($folder) eq 'inbox') {
        $folderSelectOk = $imap->select($folder);
    }
    else {
        $folderSelectOk = $imap->examine($folder);
    }
    unless (defined $folderSelectOk) {
        logErr("IMAP failed to select fodler $folder");
        return undef;
    }

    my $folderUidValidity = $imap->uidvalidity($folder);
    unless (defined $folderUidValidity) {
        logErr("IMAP failed to query Uid Validity for fodler $folder");
        return undef;
    }

    my @ret = ($msgCount, $folderUidValidity);
    return \@ret;
}

sub getHeaders($$$$) {
    my ($imap, $header, $uidList, $retHash) = @_;

    $imap->Uid(1);
    my $hash = $imap->parse_headers($uidList, $header);
    unless (defined $hash) {
        logErr("parse_headers() function failed!");
        return undef;
    }

    foreach my $mid ( keys %$hash) {
        #print "{$mid}}\n";
        my $msgHeaderHash = $$hash{$mid};
        unless (defined $msgHeaderHash) {
            logErr("parse_headers(): no entry for $mid.");
            return undef;
        }
        foreach my $hdr ( keys %$msgHeaderHash) {
            next unless ($hdr eq $header);
            my $hdrVals = $$msgHeaderHash{$hdr};
            unless (defined $hdrVals and scalar(@$hdrVals) > 0) {
                logErr("parse_headers(): no entry for $mid.");
                return undef;
            }
            $retHash->{$mid} = $$hdrVals[0];
            #print "\t$hdr: $l, $$hdrVals[0]\n";
        }
    }
    return 1;
}

sub getAllMsgHeader($$) {
    my ($imap, $header) = @_;

    $imap->Uid(1);
    my @all = $imap->search("ALL");

    my %hdrHash = ();
    while (scalar(@all) > 0) {
        my @list = splice(@all, 0, 1000);
        my $ret = getHeaders ($imap, $header, \@list, \%hdrHash);
        return undef unless (defined $ret);
    }
    return \%hdrHash;
}

# Get list of messages that already downloaded to Yahoo system.
# When we copied partner mail to Y! account we preserved partner's UIDL
# for each of the messages.
sub getListOfDownloadedMessages($$$$) {
    my ($folderName, $uidlToUidHash, $sid, $silo) = @_;

    my ($success, $uidlList) = getUidlList ($folderName, $sid, $silo);
    return ($success, undef) unless ($success and (defined $uidlList));
    my %uidHash = ();
    foreach my $uidl (@$uidlList) {
        if ((exists $uidlToUidHash->{$uidl}) and
             (defined $uidlToUidHash->{$uidl})) {
            $uidHash{$uidlToUidHash->{$uidl}} = 1;
        }
    }
    
    return (1, \%uidHash);
}

# Read mail from a remote IMAP server.
sub singleReadMailFromImap($$$$$$$$) {
    my ($imap, $msgStart, $msgCount, $msgInfoList, $lockTimeRef,
        $accMsgs, $accMsgFlags, $accUids) = @_;

    # Returns:
    # (time spent, msgs fetched, msgs skiped, bad msgs,
    #  accumulate msgs, accumulate msg uids, accumulate msg flags);

    my $startTime = time();
    my $skipedMsgs = 0;
    my $badMsgs = 0;

    @$accMsgs = ();
    @$accUids = ();
    @$accMsgFlags = ();

    my $accMsgSize = 0;
    my $upperBound = 1024 * 1024; # 1MB.

    # Buffer at most 20 messages at a time to minimize imap socket
    # connection being disconnected while writing to MsgStore.
    my $maxMsgs = 20;

    my $i;
    for ($i = $msgStart; $i <= $msgCount; $i++) {

        # Enough # of messages
	last if (@$accMsgs >= $maxMsgs);

	my $msgInfo = $$msgInfoList[$i - 1];
        my ($msgUid, $msgFlags, $msgsize) = @$msgInfo;

        # Check if the message is too large. We may need to increase the
        # lock time for the very large message.
        my $thredshold = 10 * 1024 * 1024;    # 10 M
        if ((defined $msgsize) and ($msgsize > $thredshold)) {
            my $numberOfActions = int($msgsize / $thredshold);
            unless (increaseLockTime($lockTimeRef, $numberOfActions+1)) {
                last;
            }
        }
        else {
            last unless (verifyLockTime($lockTimeRef));
       }

	my $msg = $imap->message_string($msgUid);
	if ((defined $msg) and ($msgsize > 0)) {

	    # If message size is large, flush accumulated ones first.
	    # This will guarantee that this large message will be
	    # process in a separate iteration to minimize socket
	    # being closed due to inactivity.
            if ((@$accMsgs > 0) and
		(($accMsgSize + $msgsize) > $upperBound)) {
		logIMAP("Next message of size $msgsize is large, " .
                        "flushing message buffer...");
		last;
	    }

	    # Replace every instance of \r\n with \n.
	    $msg =~ s/\r\n/\n/g;

	    # Accumulate the message.
	    push @$accMsgs, $msg;
	    push @$accMsgFlags, $msgFlags;
	    push @$accUids, $msgUid if (defined $accUids);
	    $accMsgSize += $msgsize;
	}
	else {
	    my $errMsg = $imap->LastError();
	    $errMsg = '???' unless (defined $errMsg);
	    logErr("IMAP FETCH command failed for index $i: $errMsg");
	    ++$badMsgs;
	}
    }

    return (time() - $startTime, $i - $msgStart, $accMsgSize, 
            $skipedMsgs, $badMsgs);
}

# Read mail from a remote IMAP server.
#sub bulkReadMailFromImap($$$$$$$$) {
sub readMailFromImap($$$$$$$$) {
    my ($imap, $msgStart, $msgCount, $msgInfoList, $lockTimeRef,
        $accMsgs, $accMsgFlags, $accUids) = @_;

    # Returns:
    # (time spent, msgs fetched, msgs skiped, bad msgs,
    #  accumulate msgs, accumulate msg uids, accumulate msg flags);
    logInfo("In readMailFromImap...");

    my $startTime = time();

    my $accMsgSize = 0;
    my $upperBound = 1024 * 1024; # 1MB.

    # Buffer at most 20 messages at a time to minimize imap socket
    # connection being disconnected while writing to MsgStore.
    my $maxMsgs = 20;

    my $i;
    my @uids = ();
    my ($msgInfo, $msgUid, $msgFlags, $msgsize) = 
             (undef, undef, undef, undef);
    for ($i = $msgStart; $i <= $msgCount; $i++) {

        # Enough # of messages
	last if (@uids >= $maxMsgs);

	$msgInfo = $$msgInfoList[$i - 1];
        ($msgUid, $msgFlags, $msgsize) = @$msgInfo;

        # If message size is large, flush accumulated ones first.
        # This will guarantee that this large message will be
        # process in a separate iteration to minimize socket
        # being closed due to inactivity.
        if ((@uids > 0) and
       	    (($accMsgSize + $msgsize) > $upperBound)) {
	    logInfo("Next message of size $msgsize is large, " .
                    "flushing message buffer...");
       	    last;
        }

        push @uids, $msgUid;
        $accMsgSize += $msgsize;
    }


    logInfo("readMailFromImap: total msg size about to fetch: $accMsgSize");
    # Check if the message is too large. We may need to increase the
    # lock time for the very large message.
    my $thredshold = 10 * 1024 * 1024;    # 10 M
    if ($accMsgSize > $thredshold) {
        my $numberOfActions = int($accMsgSize / $thredshold);
        unless (increaseLockTime($lockTimeRef, $numberOfActions+1)) {
            return (0, 0, 0, 0, 0, 0);
        }
    }
    else {
        unless (verifyLockTime($lockTimeRef)) {
            return (0, 0, 0, 0, 0, 0);
        }
    }

    my $t0 = [gettimeofday];

    logInfo("readMailFromImap: caling IMAP->has_capa...");
    my $cmd  =      $imap->has_capability('IMAP4REV1')                              ?
                            "BODY" . ( $imap->Peek ? '.PEEK[]' : '[]' )             :
                            "RFC822" .  ( $imap->Peek ? '.PEEK' : ''  )             ;


    logInfo("readMailFromImap: IMAP->has_capa took " . tv_interval($t0));
    # The reason to put "FLAGS" here is to work around the CPAN bug
    logInfo("readMailFromImap: calling IMAP->fetch_range_hash with cmd: $cmd");
    $t0 = [gettimeofday];
    my $msgHash;
    my $badMsgs = 0;
    my $totalMsgs = $i - $msgStart;
    $accMsgSize = 0;
    my $vcardMsgs = 0;

    eval {

      $msgHash= $imap->fetch_range_hash(\@uids, "UID", $cmd);
    };
    logInfo("readMailFromImap: IMAP->fetch_range_hash took " . tv_interval($t0));

    if ($@) {

      my $errMsg = $imap->LastError();
      logErr ("readMailFromImap: fetch_range_hash crashed: $@ : $errMsg");

      $badMsgs = $totalMsgs;
      return (time() - $startTime, $totalMsgs, $accMsgSize, 
        0, $badMsgs, $vcardMsgs);
    }

    unless (defined $msgHash) {

      my $errMsg = $imap->LastError();
      logErr ("readMailFromImap: fetch_range_hash is undef: $@ : $errMsg");

      $badMsgs = $totalMsgs;
      return (time() - $startTime, $totalMsgs, $accMsgSize, 
        0, $badMsgs, $vcardMsgs);
    }

    @$accMsgs = ();
    @$accUids = ();
    @$accMsgFlags = ();

    for ($i = 0; $i < $totalMsgs; $i++) {
	$msgInfo = $$msgInfoList[$i + $msgStart - 1];
        ($msgUid, $msgFlags, $msgsize) = @$msgInfo;
        my $msg = undef;
        if (exists $$msgHash{$msgUid} and defined $$msgHash{$msgUid}) {

          #logInfo("readMailFromImap: << in");
          my $val = $$msgHash{$msgUid};
	  if (exists $$val{$cmd} and defined $$val{$cmd}) {
	    $msg = $$val{$cmd};
	  }
	  if ( ( !defined($msg) or ( $msg eq '' ) )
	      and ( $cmd eq 'BODY.PEEK[]'
		    and exists $$val{'BODY[]'}
		    and defined $$val{'BODY[]'}) ) {
	    $msg = $$val{'BODY[]'};
	  }
       	  if ( ( !defined($msg) or ( $msg eq '' ) )
	      and ( $cmd eq 'RFC822.PEEK'
		    and exists $$val{'RFC822'}
		    and defined $$val{'RFC822'}) ){
	    $msg = $$val{'RFC822'};
	  }
          #logInfo("readMailFromImap: out >>");

        }
        if ((defined $msg) and ($msg ne '')) {

	    # Replace every instance of \r\n with \n.
	    $msg =~ s/\r\n/\n/g;
	    # Ignore message if it is a VCard 
	    if(!isVcard($imap, $msgUid)) {

	       # Add internal date
               #logInfo("readMailFromImap: calling addInternalDateToMsg...");
               addInternalDateToMsg($imap, \$msg, $msgUid);

	       # Accumulate the message.
	       push @$accMsgs, $msg;
	       push @$accMsgFlags, $msgFlags;
	       push @$accUids, $msgUid if (defined $accUids);
	       $accMsgSize += $msgsize;

               #logInfo("readMailFromImap: msgs accumulated...");
            }
	    else {
                   
                ++$vcardMsgs;
            }

        }  
	else {
	    logErr("IMAP FETCH bad msg for index $i");
	    ++$badMsgs;
	}
    }
    if ($badMsgs > 0) {
        my $errMsg = $imap->LastError();
        logErr("IMAP FETCH range hash error: $errMsg") if (defined $errMsg);
    }

    logInfo("readMailFromImap: exiting...");
    return (time() - $startTime, $totalMsgs, $accMsgSize, 
            0, $badMsgs, $vcardMsgs);
}

sub isVcard($$) {
 
    my ($imap, $msgUid) = @_;

    my $type = $imap->get_header($msgUid, "Content-Type");

    if( (defined $type) && ($type =~ /x-vcard/) ) {
         
        return 1;
    }
   
    return 0;

}


# Adds internal date to the mail buffer. Internal 
# date is prepended.
sub addInternalDateToMsg($$$) {

	my ($imap, $msg, $msgUid) = @_;

	my $iDate = $imap->internaldate($msgUid);

	if(defined $iDate) {

		my $epochTime = UnixDate($iDate, "%s");
		$$msg = "X-RocketMIF:" . $epochTime . ";;" . "\n" . $$msg;

	}
	
}

###################################################################
# POP3 Utitlities
###################################################################

#-------------------------------------------------------------------#
# POP status code:
#-------------------------------------------------------------------#
use constant POPOK           =>  0; # OK
use constant POPINTERNALERR  =>  1; # Internal error
use constant POPLOGINFAILED  =>  2; # can't log on
use constant MSGAPPENDFAILED =>  3; # can't append msg to mbox
use constant POPTIMEDOUT     =>  4; # spent too much time
use constant POPBADCONNECT   =>  5; # bad server/port/connection
use constant POPBADPASSWORD  =>  6; # bad id or password
use constant POPBADMSGS      =>  7; # error retrieving msg
use constant POPUIDILFAILED  =>  8; # failed to retrieve uidl from pop
use constant GETYMUIDLFAILED =>  9; # failed to retrieve uidl from msgStore


# Connect to pop server.
sub openPOPConnection($$$$) {
    my ($id, $pw, $server, $port) = @_;

    my ($x, $domain) = split('@', $id, 2);

    my $pop = new Mail::POP3Client(
#				   USER => $x,
				   USER => $id,
				   PASSWORD => $pw,
				   HOST => $server,
				   PORT => $port,
				   TIMEOUT => 5*60,
				   AUTH_MODE => 'PASS',
				   DEBUG => 0
				   );

    unless (defined $pop) {
	logErr("POP login failed");

	# External error.  Try again later.
	return (POPLOGINFAILED, 0, undef);
    }

    my $popMsg = $pop->Message();
    $popMsg = '???' unless (defined $popMsg);
    logPOP("<connection> POP connection status for $id: $popMsg");

    my $popCount = $pop->Count();
    $popCount = -1 unless (defined $popCount);
    logInfo("Message count = $popCount");

    if ($popCount < 0) {
	# Something bad happened to the POP object.  No need to close it.
	$pop->State('DEAD');

	if (($popMsg =~ /\-ERR/) and ($popMsg =~ /[pP]assword/)) {
	    logErr("Password supplied for $id is incorrent");
	    return (POPBADPASSWORD, 0, undef);
	}
	else {
	    return (POPBADCONNECT, 0, undef);
	}
    }

    return (POPOK, $popCount, $pop);
}

# Close the POP connection gracefully.
sub closePOPConnection($) {
    my ($pop) = @_;
    
    return $pop->Close();
}

# Get POP status.
sub getPOPStatus($$$$) {
    my ($id, $pw, $server, $port) = @_;

    my ($status, $count, $pop) = openPOPConnection($id, $pw, $server, $port);

    unless (defined $pop) {
	return ($status, $count, '');
    }
    
    my $msg = $pop->Message();
    $msg = '???' unless (defined $msg);
    closePOPConnection($pop);

    return ($status, $count, $msg);
}

sub getListOfUnPoppedMessages($$$$) {
    my ($pop, $sid, $silo, $isRetry) = @_;
    my $uidlText = $pop->Uidl();
    return (0, POPUIDILFAILED, undef, undef) unless (defined $uidlText);
    $uidlText =~ s/\r//g;
    my @uidlList = split("\n", $uidlText);

    my %uidlToUidHash = ();
    my %uidToUidlHash = ();
    foreach my $line (@uidlList) {
        my ($num, $uidl) = split ' ', $line;
        $uidlToUidHash{$uidl} = $num;
        $uidToUidlHash{$num} = $uidl;
    }

    my %emptyHash = ();
    my $downloadedUidHash = \%emptyHash;
    if ($isRetry) {
        my $success = 1;
        ($success, $downloadedUidHash) = getListOfDownloadedMessages("Inbox",
                                        \%uidlToUidHash, $sid, $silo);
        return (0, GETYMUIDLFAILED, undef, undef) unless ($success and (defined $downloadedUidHash));
    }

    my @unPoppedUidList = ();
    foreach my $uidl1 (keys %uidlToUidHash) {
        my $uid1 = $uidlToUidHash{$uidl1};

        # was the msg downloaded already?
        if ((exists $downloadedUidHash->{$uid1}) and
             (defined $downloadedUidHash->{$uid1})) {
            next;
        }
        else {
            push @unPoppedUidList, $uid1;
        }
    }
    return (1, POPOK, \@unPoppedUidList, \%uidToUidlHash);
}

# Read mail from a remote IMAP server.
sub readMailFromPOP($$$$$$$$) {
    my ($pop, $msgStart, $msgCount, $msgNumList,
        $lockTimeRef, $accMsgs, $msgNums, $accUidls) = @_;

    # Returns:
    # (time spent, msgs fetched, accumulate msgs sizes, bad msgs,
    #  was LIST command failed, was time expired);

    my $startTime = time();
    my $badMsgs = 0;
    my ($wasListFailed, $wasTimeExpired) = (0, 0);

    @$accMsgs = ();
    @$accUidls = () if (defined $accUidls);
    @$msgNums = ();

    my $accMsgSize = 0;
    my $upperBound = 1024 * 1024; # 1MB.

    # Buffer at most 20 messages at a time to minimize imap socket
    # connection being disconnected while writing to MsgStore.
    my $maxMsgs = 20;

    my $i1;
    for ($i1 = $msgStart; $i1 <= $msgCount; $i1++) {
        my $i = $$msgNumList[$i1-1];

        # Enough # of messages
	last if (@$accMsgs >= $maxMsgs);

	# Spending too much time already?
        unless (verifyLockTime($lockTimeRef)) {
            $wasTimeExpired = 1;
            last;
        }

	my $listVal = $pop->List($i);

	# Quit this POP session if LIST command failed for any reason.
	unless (defined $listVal) {
	    my $errMsg = $pop->Message();
	    $errMsg = '???';
	    logErr("LIST($i) command failed: $errMsg");
            $wasListFailed = 1;
	    last;
	}

	my ($msgnum, $msgsize) = (undef, undef);
	($msgnum, $msgsize) = split(' ', $listVal);

	if ((defined $msgnum)
	    and ($msgnum > 0)
	    and (defined $msgsize)
	    and ($msgsize > 0)) {

            # Check if there is any message whose size is over 40M
            if ($msgsize >= 40000000) {
		logErr("Message size is over 40M for index $i");
		++$badMsgs;
                next;
            }

            # Check if the message is too large. We may need to increase the
            # lock time for the very large message.
            my $thredshold = 10 * 1024 * 1024;    # 10 M
            if ((defined $msgsize) and ($msgsize > $thredshold)) {
                my $numberOfActions = int($msgsize / $thredshold);
                unless (increaseLockTime($lockTimeRef, $numberOfActions+1)) {
                    $wasTimeExpired = 1;
                    last;
                }
            }

            # If message size is large, flush accumulated ones first.
            # This will guarantee that this large message will be
            # process in a separate iteration to minimize socket
            # being closed due to inactivity.
            if ((@$accMsgs > 0) and
                (($accMsgSize + $msgsize) > $upperBound)) {
                logIMAP("Next message of size $msgsize is large, " .
                        "flushing message buffer...");
                last;
            }

	    logInfo("Downloading message $msgnum of size $msgsize");
	    my $msg = $pop->Retrieve($msgnum);
	    my $uidl = undef;
            if (defined $accUidls) {
	        if (defined $msg) {
	            my $uidlLine = $pop->Uidl($msgnum);
		    $uidlLine =~ s/\r//g;
		    $uidlLine =~ s/\n//g;
                    my $numTmp;
                    ($numTmp, $uidl) = split ' ', $uidlLine;
	            $msg = undef unless (defined $uidl);
	        }
            }

	    if (defined $msg) {
		# Replace every instance of \r\n with \n.
		$msg =~ s/\r\n/\n/g;

		# Accumulate the message.
		push @$accMsgs, $msg;
		push @$msgNums, $msgnum;
		push @$accUidls, $uidl if (defined $accUidls);
		$accMsgSize += $msgsize;
	    }
	    else {
		my $errMsg = $pop->Message();
		$errMsg = '???' unless (defined $errMsg);
		logErr("Undefined message returned by POP RETR command for index $i: $errMsg");
		++$badMsgs;
	    }
        }
	else {
	    my $errMsg = $pop->Message();
	    $errMsg = '???' unless (defined $errMsg);
	    logErr("Undefined message number or size returned by POP LIST command for index $i: $errMsg");
	    ++$badMsgs;
	}
    }

    return (time() - $startTime, $i1 - $msgStart, $accMsgSize, $badMsgs,
            $wasListFailed, $wasTimeExpired);
}

# Transfer mail from POP server to Y! mail account.
sub popMail($$$$$$$) {
    my ($pop, $msgCount, $deleteMsg, $lockTimeRef, $sid, $silo, $isRetry) = @_;

    my ($downloaded) = (0);

    # Generate message default flags.
    my @accMsgFlags = ();
    my @defFlagArr = ("\\Recent");
    my $defFlag = \@defFlagArr;
    for (my $i = 0; $i < 40; ++$i) {
        push @accMsgFlags, $defFlag;
    }

    my ($success, $status, $msgNumList, $uidToUidlHash) = getListOfUnPoppedMessages ($pop, $sid, $silo, $isRetry);
    return (0, $downloaded, $status) unless ($success);
    $msgCount = @$msgNumList;

    for (my $msgnum = 1; $msgnum <= $msgCount;) {
        # Spending too much time already?
        unless (verifyLockTime($lockTimeRef)) {
            $status = POPTIMEDOUT;
            last;
        }

        my @accMsgs = ();
        my @accUidls = ();
        my @msgNums = ();

        my ($timeTaken, $msgsRead, $accMsgSize, $badMsgs,
            $wasListFailed, $wasTimeExpired) = readMailFromPOP (
                          $pop, $msgnum, $msgCount,
                          $msgNumList, $lockTimeRef,
                          \@accMsgs, \@msgNums, undef);
        foreach my $mn (@msgNums) {
            push @accUidls, $$uidToUidlHash{$mn};
        }

        logInfo("Read $msgsRead messages starting from msg $msgnum. " .
                "$badMsgs of them were bad");
        if ($badMsgs > 0) {
            $status = POPBADMSGS if ($status == POPOK);
        }

        # Time to write out accumulated messages.
        my @appendedMsgs = ();
        my $acc = @accMsgs;
        if ($acc > 0) {
            logInfo("Appending $acc messages of total size $accMsgSize.");
            my ($mailboxOk, $folderOk) = appendMsgs(
                                         'Inbox', \@accMsgs, \@accUidls,
                                         \@accMsgFlags, $sid,
                                         $silo, \@appendedMsgs);

            if ($mailboxOk == 0) {
                $status = MSGAPPENDFAILED if ($status == POPOK);
                last;
            }
            # The folder doesn't exist and it cannot be created.
            # Quit for now and try later.
            elsif ($folderOk == 0) {
                $status = MSGAPPENDFAILED if ($status == POPOK);
                last;
            }

            # Safe to delete the message.
            if ($deleteMsg) {
                foreach my $an (@appendedMsgs) {
                    my $msgn = $msgNums[$an];
                    if ($pop->Delete($msgn)) {
                        logInfo("Message $msgn deleted from remote mailbox");
                    }
                    else {
                        logErr("Failed to delete message $msgn from remote mailbox");
                    }
                }
            }
        }

        if ($wasTimeExpired) {
            $status = POPTIMEDOUT;
            last;
        }
        elsif ($wasListFailed) {
            $status = POPBADMSGS if ($status == POPOK);
            last;
        }

        # Is there any errors during appending message to MsgStore?
        if (@appendedMsgs < $acc) {
            $status = MSGAPPENDFAILED if ($status == POPOK);
        }

        $downloaded += @appendedMsgs;
        $msgnum += $msgsRead;
    }

    if ($status == POPOK) {
        return (1, $downloaded, $status);
    }
    else {
        return (0, $downloaded, $status);
    }
}

# Pop user's mail to Y! mailbox.
sub popUserMail($$$$$$$$$$) {
    my ($user, $sid, $silo,
	$id, $pw, $server, $port,
	$deleteMsg, $isRetry, $lockTimeRef) = @_;

    # Returns:
    # (successful?, msgs downloaded, POP status code, POP message)

    unless ((defined $sid)
	    and (defined $silo)
	    and (defined $id)
	    and (defined $pw)
	    and (defined $server)
	    and (defined $port)) {
	logErr("================= POP User: Missing arguments");
	logErr("    Missing Sled ID") unless (defined $sid);
	logErr("    Missing silo") unless (defined $silo);
	logErr("    Missing POP ID") unless (defined $id);
	logErr("    Missing POP password") unless (defined $pw);
	logErr("    Missing POP server") unless (defined $server);
	logErr("    Missing POP port") unless (defined $port);
	return (0, 0, POPINTERNALERR, '');
    }

    logInfo("=== POP User:");
    logInfo("    Sled ID=$sid");
    logInfo("    silo=$silo");
    logInfo("    POP ID=$id");
    logInfo("    POP password=$pw");
    logInfo("    POP server=$server");
    logInfo("    POP port=$port");

    # Start POP!
    my $popStartTime = [gettimeofday];

    # Log on to the POP server.
    my ($popStatus, $popCount, $pop)
	= openPOPConnection($id, $pw, $server, $port);

    return (0, 0, $popStatus, '') unless (defined $pop);
    
    my $msg = $pop->Message();
    $msg = '???' unless (defined $msg);

    my ($successful, $downloaded, $status);

    if ($popCount == 0) {
	($successful, $downloaded, $status) = (1, 0, POPOK);
    }
    else {
	# Download messages.
	($successful, $downloaded, $status)
	    = popMail($pop, $popCount, $deleteMsg, $lockTimeRef, $sid, $silo, $isRetry);
    }

    # Close POP connecton.
    closePOPConnection($pop);

    
    # Done POP!
    my $popElapsedTime = tv_interval($popStartTime);
    
    logPOP("<downloaded> Downloaded $downloaded messages in $popElapsedTime seconds from $id");
    
    return ($successful, $downloaded, $status, $msg);
}

1;
__END__
