#!/usr/bin/perl

use Getopt::Long;

GetOptions ('s|server=s' => \$server,
						'q|quotaonly' => \$quotaonly,
						'a|above=s' => \$abovequota,
						'h|help' => \$help);
						
# maximum number of chars in a username to display
$maxchars=35;
                 
# soap host to connect to
if (!$server)
{
	$server = localhost;
}

if ($quotaonly && $abovequota)
{
	print "\nThe -q and -a options are mutually exclusive.  Please only choose one of them.\n\n";
	usage();
	exit;
}

# display help
if ($help)
{
	usage();
	exit;
}

# gather quotas from server
print "Getting quotas from $server (this may take a few minutes if you have a lot of users)...\n";
@quotas = `zmprov gqu $server`;

# go through users quotas one at a time
foreach $quotaline(@quotas)
{
				# chop off the newline character
        chop($quotaline);
        # assign variables to the values
        ($email, $quota, $usage) = split(/\s/,$quotaline);
        # format quota and usage in human readable formats for display
        $fquota=utils_convert_bytes_to_optimal_unit($quota);
        $fusage=utils_convert_bytes_to_optimal_unit($usage);
        if ($quota == 0)
        {
        	if (!$quotaonly && !$abovequota)
        	{
        		print "$email has no quota ($fusage used)\n";
        	}
        }
        else
        {
					$pctusage = ($usage / $quota) * 100;
					# print only accounts above x% of quota
					if ($abovequota && ($pctusage > $abovequota))
					{
						printf("%$maxchars.$maxchars\s\t(%s/%s)\t%.2f%%\n", $email, $fusage,$fquota,$pctusage);
					}
					# don't print anything if we're looking for users above quota
					# and the usage is below quota
					elsif ($abovequota && ($pctusage < $abovequota))
					{
						# do nothing
					}
					# print all usage accounts
					else
					{	
        		printf("%$maxchars.$maxchars\s\t(%s/%s)\t%.2f%%\n", $email, $fusage,$fquota,$pctusage);
        	}
        }
}

sub utils_convert_bytes_to_optimal_unit
{
  my($bytes) = @_;

  return '' if ($bytes eq '');

  my($size);
  $size = $bytes . ' Bytes' if ($bytes < 1024);
  $size = sprintf("%.2f", ($bytes/1024)) . ' KB' if ($bytes >= 1024 && $bytes < 1048576);
  $size = sprintf("%.2f", ($bytes/1048576)) . ' MB' if ($bytes >= 1048576 && $bytes < 1073741824);
  $size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
  $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);

  return $size;
}

sub usage
{
        print "$0 [-s|--server] [-q|--quotaonly] [-a|--above x%] [-h|--help]\n\n";
        print "\t [-s|--server]\tmailbox server to get usage from\n";
        print "\t [-q|--quotaonly]\tDon't print users with no quota\n";
        print "\t [-a|--above]\tPrint only accounts above x% of quota\n";
        print "\t [-h|--help]\tThis help\n";
        print "\n\tEx: $0 -s $server -a 50 displays all accounts above 50% of quota on server $server\n";
}