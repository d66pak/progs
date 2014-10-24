###
### $Id: AppendMessage.pm,v 1.23 2008-12-17 01:05:14 sumav Exp $
###
package MyAppendMessage;

# Import our predefined constants, return codes
use YMCM::AccessTransaction;
use YMCM::Logger;

#-------------------------------------------------------------------#
# Package library locations
#-------------------------------------------------------------------#

use strict;

# Functions, variables exportable to users of our modules
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use Exporter;
$VERSION = '0.01';
@EXPORT_OK = qw( AppendMessage );

# Perl modules
use Carp;
use Sys::Hostname;
use Fcntl qw(:flock);
use Time::HiRes qw(gettimeofday tv_interval);
local $SIG{__WARN__} = \&Carp::cluck;

#-------------------------------------------------------------------#
# Globals
#-------------------------------------------------------------------#
my $logger = undef;

sub AppendMessage {
  my ($in_log, $login, $sid, $silo, $dir, $lockTimeRef, $skipDeleted, $isDSync, $memUpperLimit) = @_;
  $logger = $in_log;
  return (ACTIONFAILED, UNDEFINED_ARG, 0) unless defined($login);
  return (ACTIONFAILED, UNDEFINED_ARG, 0) unless defined($sid);
  return (ACTIONFAILED, UNDEFINED_ARG, 0) unless defined($silo);
  return (ACTIONFAILED, UNDEFINED_ARG, 0) unless defined($dir);
  return (ACTIONFAILED, UNDEFINED_ARG, 0) unless defined($lockTimeRef);

  my $status = ACTIONOK;
  my $starttime = time();

  # open our info file
  my $infoFile = "$dir/$sid/.info";
  return (ACTIONFAILED, INFOFILEMISSING, 0) unless (-e $infoFile);

  my $fallUidToUidl = undef;
  my $fallUidToFlags = undef;
  my $updateFlagsMap = undef;

  if (open(INFO, $infoFile)){
    local $/ = undef;
    my $str = <INFO>;
    eval $str;
    close(INFO);
  }else{
    $logger->logErr("info file read failed");
    return (ACTIONFAILED, INFOFILEREADERR, 0);
  }


  #iterate through the directory
  $dir = "$dir/$sid";

  #print "opening directory $dir\n";
  return (ACTIONFAILED, OPENDIRFAILED, 0) unless (opendir(TMP_DIR, $dir));
  my @files = readdir(TMP_DIR);
  close(TMP_DIR);

  # Read uidl => msgid map from file
  my $yMigUidlMsgId = undef;
  if (defined $isDSync && $isDSync) {

    if (open (UIDLMSGID, "$dir/.info_dsync")) {

      # Read into variable
      local $/ = undef;
      my $str = <UIDLMSGID>;
      eval $str;
      close(UIDLMSGID);
    }
    else {

      $logger->logErr("open $dir/.info_dsync file for reading failed");
    }
  }

  my $sucAppendedMsgs;
  my $msgs;
  my $ok = ACTIONOK;
  my $appendOk = 1;
  my $appendStatus = ACTIONOK;
  my $numOfAppendedMsgs = 0;
  my $numOfAppenedMsgsFromThisFolder = 0;

  foreach my $fs (@files){
    my $fullpathDir = "$dir/$fs";
    next if ($fs eq '.' || $fs eq '..');
    next if (! -d $fullpathDir);

    #print "processing directory $fs\n";

    unless (MyMailMigrateUtil::verifyLockTime($lockTimeRef)) {
      return( ACTIONFAILED, EVENTLOCKTIMEOUT(), $numOfAppendedMsgs );
    }

    ($ok, $status, $numOfAppenedMsgsFromThisFolder) = appendFolderMsgs($login, $sid, $silo, $lockTimeRef,
      $fullpathDir, $$fallUidToUidl{$fs}, $$fallUidToFlags{$fs}, $fs, $skipDeleted, $isDSync, \$yMigUidlMsgId, $memUpperLimit);

    $logger->logEvent("after append file $fullpathDir, status = $status, ok = $ok, numOfAppenedMsgsFromThisFolder = $numOfAppenedMsgsFromThisFolder");
    unless ($ok) {

      # Few messages are not written, skip them
      $ok = 1;
    }
    &recursiveEmptyDir($fullpathDir) if ($ok);
    $appendOk = $appendOk && $ok;
    $numOfAppendedMsgs += $numOfAppenedMsgsFromThisFolder;
    if( 0 == $ok ) {
      $logger->logErr("Append msgs to folder $fs failed");
      $appendStatus = $status;
    }
  }#foreach my $fs

  # Update flags for common messages
  if (defined $updateFlagsMap) {

    updateMsgFlags($sid, $silo, $updateFlagsMap);
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

  my $timeSpent = time()-$starttime;
  $logger->logStat("APPEND",$appendStatus,$login,$timeSpent,$numOfAppendedMsgs);
  return ($appendOk, $appendStatus, $numOfAppendedMsgs);

}

sub appendFolderMsgs {
  my ($login, $sid, $silo, $lockTimeRef, $folder, $uid2Uidls,
		$uid2Flags, $yFolder, $skipDeleted, $isDSync, $yMigUidlMsgIdRef, $memUpperLimit) = @_;
  my $ok = 1;

  unless (opendir(RDIR, $folder)){
    $logger->logErr("open Dir to read temp stored mail folder $folder failed");
    return( ACTIONFAILED, READTMPMAILFOLDERFAIL(), 0);
  }

  my @files = readdir(RDIR);
  close(RDIR);

#debug - one or the other, no environment for the operation yet.
  my $yUidls = ();
  unless (defined $isDSync && $isDSync == 1) {
    
    $yUidls = &getYahooUidlsInFolder($sid, $silo, $yFolder);
  }
####  my $yUidls = (); ### allow duplicates on retry (server may issue duplicates)
  my %yUidls = map { $_ => 1 } @{$yUidls};

  my $startMsg = 0;
  my $i = 0;
  my $endMsg = 0;
  my $totalMsgs =0;
  my $numMsgs = scalar(@files);
  my $status = MSGAPPENDOK();
  $ok = ACTIONOK;

  # Open mailbox.
  my $mailbox = Mailbox::new();
  my ($ret, $busy) = $mailbox->open($sid, "yahoo", $silo);
  unless ($ret) {

     if ($busy) {
          $logger->logErr("Mailbox sid=$sid silo=$silo open failed: busy");
     }
     else {
          $logger->logErr("Mailbox sid=$sid silo=$silo open failed: non-busy");
     }

     $status = MSGSTOREMBOXERROR;
     $ok = ACTIONFAILED;

     return($ok, $status, $totalMsgs);

  }
  
  $logger->logEvent("Mailbox opened for sid=$sid, silo=$silo to write folder $yFolder");
  $logger->logEvent("Total number of messages in folder $yFolder is $numMsgs");

  ###
  ### set YM_DO_NOT_REMOVE to prevent mbox from getting migrated
  ###
  my $mbox_path = Mailbox::mail_path($sid, "yahoo", $silo);
  my $stop_mig_path = "$mbox_path/YM_DO_NOT_REMOVE";
  if (-e $mbox_path) {
    if (! -e $stop_mig_path) {
        symlink("/dev/null", $stop_mig_path);
    }
  }
 
  while ($endMsg < $numMsgs) {

     $startMsg = $endMsg;
     # Write in chunks of 50 messages to prevent out of memory problem - bug 4745006
     $endMsg = $startMsg + 50;
     if($endMsg > $numMsgs) { $endMsg = $numMsgs; }

     my @msgs = ();
     my @msgUidls = ();
     my @msgFlags = ();
     my @msgFileNames = ();
     my $fileName = $folder;
     my $msgExistInYahoo = 1;
     my $rogersMsgUidl = undef;
     my $accMsgSize = 0;
     for($i = $startMsg; $i < $endMsg; $i++) {

	my $file = $files[$i];
	next if( $file eq '.' || $file eq '..' );

        $rogersMsgUidl = undef;

        #print "processing file: $folder/$file\n"; 
        ### if there is no uidl for this message
        ### it will be undef, and the appendMsg will handle it
        ### in this case, this message will get doubled if remigrated
        if( exists($uid2Uidls->{$file})) {
          $rogersMsgUidl = $uid2Uidls->{$file};
        }
    
    
        if( defined($rogersMsgUidl)) {
          $logger->logStatFolder("APPENDUIDL","EXISTING",$login,'',$rogersMsgUidl,$folder) if( $yUidls{$rogersMsgUidl} ) ;
          next if( $yUidls{$rogersMsgUidl} ) ;
        }

        # Check if accumulated size is more than upper bound
        $fileName = "$folder/$file";
        my $msgSize = -s $fileName;

        if (defined $memUpperLimit && ($accMsgSize + $msgSize > $memUpperLimit)) {

          $logger->logInfo("Upper bound $memUpperLimit bytes exceeded - writing msgs to Mbox");
          $endMsg = $i;
          last;
        }

        $logger->logStatFolder("APPENDUIDL","NEW",$login,'',$rogersMsgUidl,$folder);
        my $msg = undef;
        unless(open(RD, $fileName)) {
          $logger->logErr("Failed to open $fileName to read Stored Mail");
          next;
        }
        local $/ = undef;
        $msg = <RD>;
        close(RD);
        my $size = length($msg);
        $accMsgSize += $size;
        $logger->logStatFolder("APPENDMSG","NEW",$login,'',$size,$folder);
        if( defined($msg)) {
          push @msgFileNames, $fileName;
          push @msgs, $msg;
          push @msgUidls, $rogersMsgUidl;
    
          ## if we find the flag already set for this message we use it
          ## otherwise we set it to unread
          if (defined($uid2Flags) && exists($uid2Flags->{$file})){
    	     push @msgFlags, $uid2Flags->{$file};
          }else{
    	     push @msgFlags, ["\\Recent"];
          }
        }
      }

      my @appendedMsgs = ();
      my $status = MSGAPPENDOK();

      if( 0 != scalar(@msgs)) {

        ###Debug one or the other op
        #my ($mailboxOk, $folderOk) = (0, 0);
        my ($mailboxOk, $folderOk) = appendMsgs($yFolder, \@msgs, \@msgUidls, \@msgFlags,
    					    $sid, $silo, \@appendedMsgs, \@msgFileNames,
    					    $skipDeleted, $mailbox, $isDSync, $yMigUidlMsgIdRef);

        $totalMsgs += scalar(@appendedMsgs);

        if( 0 == $mailboxOk || 0 == $folderOk || scalar(@appendedMsgs) < scalar(@msgs) ) {
          $ok = ACTIONFAILED;
          $status = MSGAPPENDFAILED();
        }

      }elsif ($totalMsgs == 0) {

        #Empty folder
        #Debug one or other
        #my ($mailboxOk, $folderOk) = (1, 1);
        my ($mailboxOk, $folderOk) = appendMsgs($yFolder, undef, undef, undef,
    					    $sid, $silo, undef, undef,
    					    $skipDeleted, $mailbox, $isDSync, $yMigUidlMsgIdRef);
        # The folder doesn't exist and it cannot be created.
        if ($mailboxOk == 0){
          $status = MSGSTOREMBOXERROR;
          $ok = ACTIONFAILED;
        } elsif ($folderOk == 0){
          $status = FOLDERCREATIONFAILED;
          $ok = ACTIONFAILED;
        }
      }

      if($ok != ACTIONOK) { last; }
    
    }

    $mailbox->close();

    $logger->logInfo("Mailbox closed for sid=$sid, silo=$silo. folder $yFolder");

    ###
    ### done with YM_DO_NOT_REMOVE
    ###
    if (-e $stop_mig_path) {
         unlink ($stop_mig_path);
    }
   
    return($ok, $status, $totalMsgs);

}

##
## YMRegister::MailMigrateUtil::appendMsgs is deprecated; use this subroutine.
##
sub appendMsgs {
    my ($folderName, $msgs, $uidls,$flagLists,
	$sid,$silo, $appendedMsgs, $msgFileNames,
	$skipDeleted, $mailbox, $isDSync, $yMigUidlMsgIdRef) = @_;

    # We cache a few downloaded messages in memory, open the mailbox,
    # write the messages to the mailbox, and close the mailbox right
    # away.  This way, the amount of time this script holds onto a
    # mailbox can be minimized.
    my $folder = undef;

    my $startTime = [gettimeofday];

    if (defined($msgFileNames)) {
		$logger->logEvent("appendMsgs for $folderName");
    } else {
		$logger->logEvent("appendMsgs for empty $folderName");
    }


    # Create the folder if it doesn't exist.
    $logger->logEvent("Create folder $folderName");
    $folder = $mailbox->getFolder($folderName) if (defined $mailbox);
    unless (defined $folder) {
	  $mailbox->createMailFolder($folderName);
    }
    $folder = $mailbox->getFolder($folderName) if (defined $mailbox);
    unless (defined $folder) {
        $logger->logErr("$folderName cannot be created for sid=$sid, silo=$silo");
        return (1, 0);
   }

    # if $msgs is undefined it means it's for folder creation only
    unless (defined $msgs) {
        return (1, 1);
    }

    my $msgCount = 0;
    my $totalMsgs = scalar(@$msgs);
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
                if (defined $uidl) {

                  $errMsg .= " UIDL $uidl";
                }
                elsif (defined $msgId) {

                  $errMsg .= " MsgId $msgId";
                }
            }
            else {

              if (defined $isDSync && $isDSync) {

                # Update uidl => msgid map for successfully written msgs
                $$yMigUidlMsgIdRef->{$folderName}->{$uidl} = 1;
              }
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
			  if (defined($skipDeleted)
			      && $skipDeleted) {
                            $flags->setDeleted();
			  }
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
		    unlink($msgFileNames->[$i]);
                    ++$msgCount;
                }
                else {
                    $errMsg = "Failed to write flags for message of size $size";
                }
            }
        }
        if (defined $errMsg) {
            $logger->logErr("Failed to append message for sid=$sid,silo=$silo, " .
                   "folder=$folderName: $errMsg");
        }
    }

    # Set PIK folder state to 'out of sync'.
    $mailbox->setPIKFolderOutOfSync() if ($mailbox);

    my $elapsedTime = tv_interval($startTime);

    $logger->logInfo("Appended $msgCount messages to folder $folderName in $elapsedTime seconds");

    return (1, 1);
}

# Input:   MsgId => [Flags] map
# Job:     Writes Flags to Y Mbox
# Returns: ACTIONOK/ACTIONFAILED
sub updateMsgFlags($$$)
{
  my ($sid, $silo, $updateFlagsMap) = @_;

  my $t0 = [gettimeofday];

  # Open mailbox.
  my $mailbox = Mailbox::new();
  my ($ret, $busy) = $mailbox->open($sid, "yahoo", $silo);
  unless ($ret) {

    if ($busy) {
      $logger->logErr("Mailbox sid=$sid silo=$silo open failed: busy");
    }
    else {
      $logger->logErr("Mailbox sid=$sid silo=$silo open failed: non-busy");
    }

    return(ACTIONFAILED, UPDATEMSGFLAGSFAILED());
  }

  $logger->logInfo("Mailbox opened for sid=$sid, silo=$silo");

  foreach my $folderName (keys %$updateFlagsMap) {

    $logger->logInfo("Updating flags for folder: $folderName");

    my $flag_fail = 0;
    my $flag_skipped = 0;
    my $uidlFlagsMap = $updateFlagsMap->{$folderName};
    my $total = scalar(keys(%$uidlFlagsMap));

    if (exists $uidlFlagsMap->{folderDeleted} &&
      $uidlFlagsMap->{folderDeleted}) {

      # Folder is deleted in partner mbox
      my $ret = $mailbox->removeFolder($folderName);
      $logger->logInfo("Y! Folder deleted with status: $ret");
    }
    else {

      # Check if any flags need to be updated for this folder
      if ($total > 0) {

        my $folder = $mailbox->getFolder($folderName);
        unless (defined $folder) {

          $logger->logErr("$folderName not persent in Y Mbox");
          next;
        }

        my $msgList = MessageList::new();
        unless ($folder->messages($msgList)) {

          $logger->logErr("Failed to get message list for folder: $folderName");
          next;
        }

        my $numberOfMsgs = $msgList->size();

        for (my $i = 0; $i < $numberOfMsgs; ++$i) {

          my $uidl = $msgList->getUidlAt($i);

          # Check if this UIDL needs flag update
          unless (exists $uidlFlagsMap->{$uidl} && defined $uidlFlagsMap->{$uidl}) {

            ++$flag_skipped;
            next;
          }

          # Get msgid for this msg
          my $msgId = MessageId::new();
          $msgList->getMessageIdAt($i, $msgId);
          unless (defined $msgId) {

            $logger->logErr("Unable to create new msgId");
            ++$flag_skipped;
            next;
          }


          my $flags = Flags::new();
          unless (defined $flags) {

            $logger->logErr("Unable to create new flags");
            ++$flag_skipped;
            next;
          }

          $flags->unsetAll();
          my $flagsArray = $uidlFlagsMap->{$uidl};
          foreach my $f (@$flagsArray) {

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
              $flags->setRecent();
            }
          }

          # Write the flags
          unless($flags && $folder->writeFlags($flags, $msgId)) {

            $flag_fail++;
            $logger->logErr("Flag update failed for UIDL: $uidl");
          }

        } # for
      } # if ($total > 0)

      # Statistics
      $logger->logInfo("Update flags pass: " . ($total - $flag_fail) . " fail: $flag_fail skipped: $flag_skipped total: $total");
    }
  } # foreach

  # Set PIK folder state to 'out of sync'.
  $mailbox->setPIKFolderOutOfSync();

  # Close Mailbox
  $mailbox->close();

  my $et = tv_interval($t0);

  $logger->logInfo("Mailbox closed for sid=$sid, silo=$silo Updated flags in $et seconds");
  return (ACTIONOK, UPDATEMSGFLAGSOK());
}

sub getYahooUidlsInFolder
{
    my ($sid, $silo, $folderName) = @_;
    my ($success, $uidlList) = MyMailMigrateUtil::getUidlList ($folderName, $sid, $silo);
    return ($success, $uidlList);
}


sub setLogApplName($) {
    my ($an) = @_;
    $logger->setAppName($an);
}

# Set log file handle and debug mode.
sub setLogFile($) {
    my ($errFile) = @_;
    $logger->setLogFile($errFile);

    #unless (open(ERR, ">> $errFile")) {
	#printDebug("ERROR: Failed to open log file $errFile: $!");
	#return 0;
    #}

    #$err = \*ERR;
    #$verbose = $mode;
    return(1);
}

sub setVerbose($) {
    my ($mode) = @_;
    $logger->setVerbose($mode);
}

sub recursiveEmptyDir
{
    my $dir = shift;
    unless(opendir(RDIR, $dir)) {
	return 0;
    }
    my @files = readdir(RDIR);
    close(RDIR);
    foreach my $file (@files) {
	next if ($file eq '.' || $file eq '..' );
	if( -d "$dir/$file") {
	    &recursiveEmptyDir("$dir/$file") ;
	}
	else {
	    unlink("$dir/$file") || $logger->logErr("Failed to delete file $dir/$file, errno: $!");
	}
    }
    rmdir($dir) || $logger->logErr("Failed to delete $dir, errno: $!");
}

1;

__END__

=head1 NAME

YMCM::AppendMessage - Append email from folders in temp directory to Yahoo mailbox

=head1 SYNOPSIS

use YMCM::AppendMessage;

my ($ok, $status, $numberFetched) =
  YMCM::AppendMessage::AppendMessage($login, $sid, $silo, $dir, $lockRef);

=head1 DESCRIPTION

This module contains the functions necessary for reading mail folders in a temporary
folder and appending it to a specified Yahoo mailbox. This module works closely
with the YMCM::FetchEmail module. Directories created must be of the form 
$dir/$sid/[mail folders]. There should also be an uid->uidl mapping file, 
$dir/$sid/.info in $dir/$sid directory. Each mail folder directory will contain files
named after their message uid. Each file contains the message whose uid corresponds
to its name.Each uid and hence file name is unique, and should be listed in the info file.

=head1 STATIC FUNCTIONS

=item AppendMessage($login, $sid, $silo, $dir, $lockRef)

Parses the $dir/$sid directory and traverses through all the mail folders that 
it finds. For each message file underneath the mail folders, check for its corresponding 
uidl in the info file and use it for appending the message into its corresponding 
Yahoo mail folder. The $login parameter is the Yahoo login, $sid the Yahoo user SID,
$silo the user's allocated silo, $dir the temporary directory, and $lockRef the time lock
on the user mailbox.

=item setLogFile($logFileName)

Set the name of the log file that we write to. The directory which the log file resides
must be writable.If this method is not called, the log messages are sent to STDERR.

=item setLogApplName($applName)

Set the application name that will get logged to the log file.

=item setVerbose($mode)

Set the verbosity of our logging. If $mode is true, non-zero then we will log to the 
INFO level.

=head1 DEPENDENCIES

Yahoo Perl package(s):

Mailbox

YMRegister::MailMigrateUtil

CPAN package(s)

Carp

Sys::Hostname

Fcntl

Time::HiRes

=head1 AUTHORS

Questions and bugs should be reported to the Yahoo! Mail Access group,
ymail-access@yahoo-inc.com.

=cut
