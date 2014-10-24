#!/usr/bin/perl -w
use ydbs;
use ymailext;
use constant UDBKEYS => qw/sid,ym_mail_sh/;

use Getopt::Long; 

### Print Error msg if wrong input of command line args.
$usage="\nUsage:\n  yinst-pw perl $0 --file <user list> --del <0 or 1> --dis <0 or 1> \n";

### Collects command line arguments.
GetOptions('file=s' => \$file, 'del=i' => \$del, 'dis=i' => \$dis);
die $usage unless($file);

open (INFILE, "$file");
while ( <INFILE> )
{
 print "YID=$_\n";
 chomp;
 $_ =~ s/^\s+//g;
 $_ =~ s/\s+$//g;
 my $y = tie my %y, "ymailUser";
 my $UDBRET = $y->open($_,0x04|0x800,"ym_mail_sh");
 my $e = tie my %e, "ymailext", $y, "ym_mail_sh";
	print "del=$e{del} and dis=$e{dis}\n";
 $e{del}=$del;
 $e{dis}=$dis;
 $e->saveTo($y);
 $y->save();
	print "del=$e{del} and dis=$e{dis}\n************************\n";
}
close (INFILE);
