#!/home/y/bin/perl -w

use File::Path;
use File::Basename;
use YMRegister::YMRegister;
use YMRegister::MailMigrateUtil;
use YMCM::AccessStatusUpdate;
use YMCM::AccessTransaction;
use YMCM::AppendMessage;
use YMCM::FetchEmail;
use YMCM::Logger;
use ymailext;
use ymextKeyUDMigStatus;
use ydbs;
use MIME::Base64;
use Data::Dumper;

# Perl modules:
use POSIX;
use Carp;
use Sys::Hostname;
use Fcntl qw(:flock);


#-------------------------------------------------------------------#
# Globals
#-------------------------------------------------------------------#

my $mailConf = undef;
my $err     = undef; # File handle
my $verbose = undef;
my $logger  = undef;
my $applName = undef;
my $imapSSL = 0;
my $imapPeek = 0;
my $skipDeleted = 0;
my $toDelete = 0;
my $dir = undef;
my $imapServer = undef;
my $imapPort = undef;
my $popUIDL = undef;
my $popServer = undef;
my $popPort = undef;
my $lockTimeRef = undef;
# IN and OUR FIFOs. 
my $inPipe = undef;
my $outPipe = undef;
my $configFile = undef;
# Execute till shutDown is set to 1
my $shutDown = 0;
my $adminPass = undef;
my $adminUid = 'api_ymig@frontier.com';
my $currUser = undef;
# Function call related variables.
my $func = undef;
my @iParams = undef;
my @output = undef;

my $EOM = "_EOM_";
my $I_AM_ALIVE = "I_AM_ALIVE";
my $PLAIN_SCHEME = "PLAIN";

use constant SUCCESS_ACTION => 1;
use constant MAILBOX_WRITE_FAILED => 101;
use constant MAILBOX_RENUM_FAILED => 102;

# Callback for SASL plain authentication
my $authenticatePlainCallback = sub {

	my ($code) = @_;

	# api_ymig - Frontier's Zimbra mail admin user
    $code = join("\0", $currUser, "api_ymig\@frontier.com", $adminPass);	

	# Encode into base64 and do not break string into multiple lines
	my $encodedStr = encode_base64($code, "");

	return $encodedStr;

};

sub openLogFile($) {

    my($errFile) = @_;

    unless (open(ERR, ">> $errFile")) {
        print "$errFile: $!\n";
        return undef;
    }

    $errHandle = \*ERR;

    return $errHandle;
}

### load Frontier config file for mail migration.
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

=begin COMMENT
    # Skip the request if a lock cannot be acquired for it.
    unless (YMRegister::MailMigrateUtil::lockBtTxRequest(
                                          $reqName, $lockTime)) {
        $logger->logInfo("Can't acquire lock for the event $reqName");
        return undef ;
    }
=end COMMENT
=cut

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

    print "Base dir: $baseLogDir\n";

    unless (defined $baseLogDir) {

        $baseLogDir = '/rocket/accessMail/' . $applName;
    }

    my $err = openLogFile("$baseLogDir/log/error");

    unless(defined($err)) {

      print "Error opening log file\n";
        return 0;

    }

    $verbose=TRUE;

    YMRegister::MailMigrateUtil::setLogHandle($err);
    YMRegister::MailMigrateUtil::setVerbose($verbose);
    YMRegister::MailMigrateUtil::setLogApplName($applName);

    $logger = new YMCM::Logger($err, $applName, $verbose);
    $logger->setLogHandle($err);
    $logger->setVerbose($verbose);
    $logger->setAppName($applName);
    $logger->setSuccessAction(SUCCESS_ACTION());


    $folderMap = $mailConf->{'folder-map'};
    $folderCharMap = $mailConf->{'folderCharMap'};
    $folderIgnore = $mailConf->{'folderIgnore'};

    $imapSSL = $mailConf->{'imapSSL'};
    $imapPeek = $mailConf->{'imapPeek'};
    $skipDeleted = $mailConf->{'imapSkipDeleted'};
    $toDelete = $mailConf->{'toDelete'};

    # POP UIDL
    $popUIDL = $mailConf->{'popUIDL'};
    $popServer = $mailConf->{'popServer'};
    $popPort = $mailConf->{'popPort'};
    print "INIT: $popUIDL $popServer $popPort\n";

    $dir = $mailConf->{'mailStorageBaseDir'};


    # Connect via stunnel
    $imapServer=$mailConf->{'iServer'};
    $imapPort= $mailConf->{'iPort'};

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
    elsif ($status == 1109) {
      $retVal = 5;
    }
    else {
        # Unmapped error
        $retVal = 3;
    }

    return $retVal;

}

sub fetchMail($$$$$$$) {

    my ($partner, $user, $sid, $silo, $id, $pw, $isRetry) = @_;
    my ($mssilo) = "ms$silo";
    my ($success, $status, $newdownloaded);
    my ($reportState) = 1;

    $lockTimeRef = process_begin($sid);

    if(!defined $lockTimeRef) {

        print "Lock acquire error\n";
        return mapFetchMailErrorStatus(1);
    }

    $adminPass = $pw;
    $currUser  = $id;
    my %popConfig;

    # Check if Inbox UIDLs need to be fetched using POP3
    if (defined $popUIDL && $popUIDL == 1) {

      $popConfig{popServer} = $popServer;
      $popConfig{popPort}   = $popPort;
      $popConfig{user}      = $currUser;
      $popConfig{adminUid}  = $adminUid;
      $popConfig{adminPass} = $adminPass;
      $popConfig{authMech}  = $PLAIN_SCHEME;
   
      print "$popUIDL $popServer $popPort $currUser $adminUid $adminPass $PLAIN_SCHEME\n";
    }

    print Dumper(\%popConfig);

    $logger->logInfo("Dowloading mail for user $user with sid $sid and silo $mssilo ...");
    ($success, $status, $newdownloaded) =
    YMCM::FetchEmail::FetchMailIMAP($logger, $user, $sid, $mssilo,$id, $pw, $imapServer, $imapPort, $dir,
            $toDelete, $isRetry, $lockTimeRef, $folderMap, $imapSSL, $imapPeek, $skipDeleted, $PLAIN_SCHEME, $authenticatePlainCallback, \%popConfig );

    print "\n STATUS CODE: $status success is $success\n\n";

    unless ($success) {

              $logger->logErr("Failed to download mail for user $user.");

              $logger->recordActionStatus($partner, "MailMig", 0, $status, "");
              my $rmDir = "$dir/$sid";
              $logger->logInfo("Removing directory $rmDir");
              YMCM::AppendMessage::recursiveEmptyDir($rmDir);
              
              $success = mapFetchMailErrorStatus($status);

    }
    else {
   
        $logger->logInfo("Writing mail to Yahoo mailbox for user $user with sid $sid and silo $mssilo ...");
        #$success = writeMail($partner, $user, $sid, $silo, $id, $pw);
    }

   process_end($sid);

   return $success;

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

    my ($success,$status, $appendedMsgs) =
                YMCM::AppendMessage::AppendMessage($logger, $user, $sid, $mssilo, $dir,
                                                   $lockTimeRef, $skipDeleted);
    my $rmDir = "$dir/$sid";
    $logger->logInfo("Removing directory $rmDir");
    YMCM::AppendMessage::recursiveEmptyDir($rmDir);

    unless ($success) {

           $logger->logErr("Failed to write mailbox for user $user.");
           $logger->recordActionStatus($partner, "MailMig", 0, $status, "");
           $success = mapWriteMailErrorStatus($status);

    }
    else {
          $logger->logInfo("Renumbering UIDs based on internal date for user $user with sid $sid and silo $mssilo ...");
          $success = renumberUIDs($sid, $mssilo);
    }

    return $success;

}

sub renumberUIDs($$) {

    my ($sid, $mssilo) = @_;
    my $retVal = 0;

    my @renumCmdArgs = ("/home/y/bin/ymail_renumberUIDs", '-i', $sid, '-s', $mssilo, '2>&1');
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
            
        my ($partner, $user, $sid, $silo, $id, $pw, $isRetry);

        $partner = shift(@iParams);
        $user = shift(@iParams);
        $sid = shift(@iParams);
        $silo = shift(@iParams);
        $id = shift(@iParams);
        $pw = shift(@iParams);
	    $isRetry = shift(@iParams);

        $retVal = fetchMail($partner, $user, $sid, $silo, $id, $pw, $isRetry);
        push(@output, $retVal); 
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
     
     print "File $fileToCheck not found\n";
     sleep(1);
     $sleepTime++;
     if($sleepTime > 10) { return 0; }

  }

  return 1;

}

#####################
##     Main Loop   ##
#####################

# Read the input params
$shutDown = 0;

print "Callint init...\n";
init("/home/dtelkar/scripts/FrontierIMAPMail.conf");
print "Calling FetchMail...\n";
#fetchMail("ftr", 'yqa_ftr_i1025@frontiernet.net', "24769798597096774", "37202", 'yqa_ftr_i1025@frontiernet.net', "AW3b4Pp0aJVcEX4x", "0");
#fetchMail("ftr", 'yqa_ftr_pop1000@frontiernet.net', "14636699461014832", "37205", 'yqa_ftr_pop1000@frontiernet.net', "AW3b4Pp0aJVcEX4x", "0");
fetchMail("ftr", 'yqa_ftr_pop1016@frontiernet.net', "13510803864290666", "37213", 'yqa_ftr_pop1016@frontiernet.net', "AW3b4Pp0aJVcEX4x", "0");
#fetchMail("ftr", 'yqa_ftr_pop1020@frontiernet.net',  "24769798745045271", "37213", 'yqa_ftr_pop1020@frontiernet.net', "AW3b4Pp0aJVcEX4x", "0");
