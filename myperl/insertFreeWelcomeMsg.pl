#!/home/y/bin/perl

use strict;
use warnings;
use YMRegister::YMRegister;

#my $newsid       = '114841791653239149';
#my $newsid       = '114841791653276170';
my $newsid = '114841791653297038';
#my $silowithms   = 'ms932140';
my $silowithms   = 'ms932121';
#my $recipient    = 'yqa_reg_rogers1@rogers.com';
my $recipient    = 'yqa_reg_rogers06@rogers.com';

my $sender       = 'Rogers Yahoo! Member Services';
my $subject      = 'Welcome! Get started with your Rogers Yahoo! service';
my $yid          = $recipient;
my $TIPHeader    = '66.218.69.16';
my $sharedHeader =
'address="yqa_reg_rogers1@rogers.com";yid="yqa_reg_rogers1";name="NEIL COLACO";intl=ca';
my $SRVHeader =
'allow=images;cg_sih=16;cg_sih_inv=16;cg_siu=http://mail.yimg.com/a/i/us/pim/ybang_16x16_1.gif;cg_siu_inv=http://mail.yimg.com/a/i/us/pim/ybang_16x16_dark_1.gif;cg_siw=16;cg_siw_inv=16;hih=16;hiu=http://mail.yimg.com/a/i/us/pim/ybang_16x16_1.gif;hiw=16;livewords=false;reportspam=generic;sih=16;';
my $sharedBodyFilePath =
'file:/rocket/ms1/external/static/partners/rogers-acs/ca/welcomeYahoo_hi.html';
my $silentMode = 0;

unless (
         YMRegister::YMRegister::insertSharedMessage(
                    $newsid,             $silowithms, $sender,    $subject,
                    $recipient,          $TIPHeader,  $SRVHeader, $sharedHeader,
                    $sharedBodyFilePath, $silentMode, $yid
         )
  )
{

 print "Error inserting welcome msg!\n";
}
