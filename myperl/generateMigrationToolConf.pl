#!/usr/local/bin/perl

sub getEnvSetting($$) {
    my $key = shift;
    my $def = shift;

    return defined($ENV{$key}) ? $ENV{$key} : $def;
}

# my $variableName = getEnvSetting("ymail_HomeStore_java__settingName", "defaultValue");

my $fetchRetryDelay = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__fetchRetryDelay", "1");
my $lsgHost = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__lsgHost", "ls100.mail.vip.cnh.yahoo.com");
my $fetchFailRetryCount = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__fetchFailRetryCount", "1");
my $pathToUnprocessedSleds = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__pathToUnprocessedSleds", "/rocket/ms1/external/accessMail/free_archive_mig/new");
my $pathToArchiveFiles = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__pathToArchiveFiles", "/rocket/ms1/external/accessMail/free_archive_mig/archive_files");
my $pathToMigrationDoneMarker = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__pathToMigrationDoneMarker", "/rocket/ms1/external/accessMail/free_archive_mig/new");
my $locatorFileEntitySeparator = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__locatorFileEntitySeparator", "\\|");
my $pathToTempFileLocation = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__pathToTempFileLocation", "/home/y/logs/ymailArchiveStoreMigrationTool/temp/");
my $pathToMigrationLogLine = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__pathToMigrationLogLine", "/home/y/logs/ymailArchiveStoreMigrationTool/MigrationTool.log");
my $ycaCertificate = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__ycaCertificate", "yahoo.mail.acl.yca.lsg-prod");
my $proxy = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__proxy", "true");
my $dryrun = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__dryrun", "false");
my $msgStoreMaxRetry = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__msgStoreMaxRetry", "3");
my $msgStoreRetryInterval = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__msgStoreRetryInterval", "60");
my $testMode = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__testMode", "true");
my $msgStoreClientPath = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__msgStoreClientPath", "/home/y/libexec/ymailArchiveStoreMigrationTool/messageStoreClient");
my $testSled = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__testSled", "19140299344060779");
my $testSilo = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__testSilo", "ms932321");
my $featureEnabled = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__featureEnabled", "false");
my $headersToRemove = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__headersToRemove", "X-RocketMail,X-RocketUID,X-RocketYMUMID");
my $webFeHosts= getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__webFeHosts",
"web190001,web190101,web190201,web190301,web190401,web190501,web190601," .
"web190701,web190801,web190901,web192201,web192301,web192401,web192501," .
"web192601,web193601,web193701,web193801,web193901,web194001,web2701," .
"web192701,web192801,web192901,web193001,web193101,web193201,web193301," .
"web193401,web193501,web194601,web194701,web194901,web195001,web195301," .
"web195302,web195303,web195304,web195305,web195306,web195307,web195308," .
"web195309,web195310,web195311,web195312,web195313,web195314,web195315," .
"web195316,web195317,web195318,web195319,web195320,web932302"
);
my $toMigrateArchiveClusters = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__toMigrateArchiveClusters", "cnh.yahoo.com,cn3.yahoo.com,cnb.yahoo.com");
my $threads = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__threadLimit", "1");
my $filescanner = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__filescanner", "false");
my $inputfile = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__inputfile", "/home/monishg/tmp/sleds");
my $scandir = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__scandir", "/rocket/ms%s01/external/accessMail/free_archive_mig/new");
my $logFilePath = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__logFilePath", "/home/y/logs/ymailArchiveStoreMigrationTool/CrawlerTool.log");
my $loglevel = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__loglevel", "FINEST");
my $ignoreFolders = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__ignoreFolders", "Bulk,trash");
my $lsghashfile = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__lsghashfile", "/home/y/conf/ymailArchiveStoreMigrationTool/lsgHostHash.Conf");
my $appendMsgBatchSize = getEnvSetting("ymail_ArchiveStoreMigration_Tool_Conf__appendMsgBatchSize", "1000");

printf("###############################################################################\n");
printf("# This is the config file for Ymail Archive Migration tool.  It consists of simple name     #\n");
printf("# value pairs.  If a line begins with #, it is a comment and not processed.   #\n");
printf("# Every value is interpreted in the code as either a string or a long.        #\n");
printf("# Quotes (\" or ') are not used as delimiters.  If used, they will appear in   #\n");
printf("# in the string.                                                              #\n");
printf("###############################################################################\n");
printf("\n");
printf("# If the modified-on date of this file is more than this many seconds in the\n");
printf("# past, it will be re-parsed by tool.\n");
printf("fetchRetryDelay=%s\n", $fetchRetryDelay);
printf("\n");
printf("lsgHost=%s\n", $lsgHost);
printf("\n");
printf("fetchFailRetryCount=%s\n", $fetchFailRetryCount);
printf("\n");
printf("pathToUnprocessedSleds=%s\n", $pathToUnprocessedSleds);
printf("\n");
printf("pathToArchiveFiles=%s\n", $pathToArchiveFiles);
printf("\n");
printf("pathToMigrationDoneMarker=%s\n", $pathToMigrationDoneMarker);
printf("\n");
printf("locatorFileEntitySeparator=%s\n", $locatorFileEntitySeparator);
printf("\n");
printf("pathToTempFileLocation=%s\n", $pathToTempFileLocation);
printf("\n");
printf("pathToMigrationLogLine=%s\n", $pathToMigrationLogLine);
printf("\n");
printf("ycaCertificate=%s\n", $ycaCertificate);
printf("\n");
printf("msgStoreClientPath=%s\n", $msgStoreClientPath);
printf("\n");
printf("proxy=%s\n", $proxy);
printf("\n");
printf("dryrun=%s\n", $dryrun);
printf("\n");
printf("msgStoreMaxRetry=%s\n", $msgStoreMaxRetry);
printf("\n");
printf("msgStoreRetryInterval=%s\n", $msgStoreRetryInterval);
printf("\n");
printf("testMode=%s\n", $testMode);
printf("\n");
printf("testSled=%s\n", $testSled);
printf("\n");
printf("testSilo=%s\n", $testSilo);
printf("\n");
printf("featureEnabled=%s\n", $featureEnabled);
printf("\n");
printf("threadLimit=%s\n", $threads);
printf("\n");
printf("toMigrateArchiveClusters=%s\n", $toMigrateArchiveClusters);
printf("\n");
printf("webFeHosts=%s\n", $webFeHosts);
printf("\n");
printf("headersToRemove=%s\n", $headersToRemove);
printf("\n");
printf("loglevel=%s\n", $loglevel);
printf("\n");
printf("appendMsgBatchSize=%s\n", $appendMsgBatchSize);
printf("\n");
printf("###############################################################################\n");
printf("\n");
printf("# Crawler related specific settings\n");
printf("\n");
printf("filescanner=%s\n", $filescanner);
printf("\n");
printf("inputfile=%s\n", $inputfile);
printf("\n");
printf("scandir=%s\n", $scandir);
printf("\n");
printf("logFilePath=%s\n", $logFilePath);
printf("\n");
printf("ignoreFolders=%s\n", $ignoreFolders);
printf("\n");
printf("lsghashfile=%s\n", $lsghashfile);
printf("\n");
