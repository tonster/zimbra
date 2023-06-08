#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;
use Time::HiRes qw( time );
use Time::Duration;

use Getopt::Long;

my $start;
my $end;
my $runtime;
my $fserver;
my $tserver;
my $help;
my $userline;
my @users;
my $email;
my $quota;
my $usage;
my $fusage;
my $numtransfers = 0;
my $speed;

GetOptions ('f|fromserver=s' => \$fserver,
						't|toserver=s' => \$tserver,
						'h|help' => \$help);

# soap host to connect to
if (!$fserver)
{
	$fserver = `zmhostname`;
	chop($fserver);
	print "fserver=$fserver\n";
}

if (!$tserver)
{
	print "A destination server is required.\n\n";
	usage();
	exit;
}

# display help
if ($help)
{
	usage();
	exit;
}

# gather accounts from source server
print "Getting user list from $fserver (this may take a few minutes if you have a lot of users)...\n";
@users = `zmprov gqu $fserver`;

my $transferstart = time();

# go through users one at a time
foreach $userline(@users)
{
				# chop off the newline character
        chop($userline);
        # assign variables to the values
        ($email, $quota, $usage) = split(/\s/,$userline);
        # format  usage in human readable formats for display
        $fusage=utils_convert_bytes_to_optimal_unit($usage);
				print "Transferring $email...";
				$start = time();
				system("zmmboxmove -a $email -f $fserver -t $tserver -sync");
				$end = time();
				$speed = utils_convert_bytes_to_optimal_unit($usage / ($end - $start));
				$runtime = duration_exact($end - $start);
				print "transferred $fusage in $runtime ($speed/s).\n";
				$numtransfers++;
}

my $transferend = time();
my $totalruntime = duration_exact($transferend - $transferstart);
print "$numtransfers users transfered in $totalruntime.\n";

sub utils_convert_bytes_to_optimal_unit
{
  my($bytes) = @_;

  return '' if ($bytes eq '');

  my($size);
  $size = $bytes . ' Bytes' if ($bytes < 1024);
  $size = sprintf("%.2f", ($bytes/1024)) . ' kiB' if ($bytes >= 1024 && $bytes < 1048576);
  $size = sprintf("%.2f", ($bytes/1048576)) . ' MiB' if ($bytes >= 1048576 && $bytes < 1073741824);
  $size = sprintf("%.2f", ($bytes/1073741824)) . ' GiB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
  $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TiB' if ($bytes >= 1099511627776);

  return $size;
}

sub usage
{
        print "$0 [-f|--fromserver] [-t|--toserver] [-h|--help]\n\n";
        print "\t [-f|--fromserver]\tmailbox server to transfer mailbox from\n";
        print "\t [-t|--toserver]\tmailbox server to transfer mailbox to\n";
        print "\t [-h|--help]\tThis help\n";
        print "\n\tEx: $0 -f $fserver -t new$fserver transfers all accounts from server $fserver to server new$fserver\n";
}
