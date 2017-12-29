#!/usr/bin/perl

use Getopt::Long;

GetOptions ('file=s' => \$file,
						'outfile=s' => \$outfile,
						'errorfile=s' => \$errorfile,
						'help' => \$help);
						
# only sanity check these fields
@fields = ('ACTION','BEGIN','CLASS','CREATED','DESCRIPTION','DTEND','DTSTAMP','DTSTART','END','LAST-MODIFIED','LOCATION','METHOD','PRIORITY','PRODID','RECURRENCE-ID','RRULE','SEQUENCE','SUMMARY','TRANSP','TRIGGER','TZID','TZOFFSETFROM','TZOFFSETTO','UID','VERSION','X-CALSTART','X-MICROSOFT-CDO-BUSYSTATUS','X-MICROSOFT-CDO-IMPORTANCE','X-MS-OLK-WKHRDAYS','X-PRIMARY-CALENDAR','X-WR-CALNAME','X-WR-RELCALID');

if ($outfile)
{
	open(OUTICS, ">$outfile");
}
if ($errorfile)
{
	open(ERRORFILE, ">$errorfile");
}
if ($help)
{
	usage();
}
elsif (!$file)
{
	print "Must specify filename.\n\n";
	usage();
	exit;
}
elsif (!-e $file)
{
	print "File does not exist!\n\n";
	usage();
	exit;
}
else
{
	#print "File exists. Continuing...\n";
	open(ICS, "<$file");
	@ics = <ICS>;
	$errors=0;
	$count=0;
	for ($i=0;$i<=$#ics;$i++)
	{
		if ($ics[$i] =~ "BEGIN:VEVENT")
		{
			$count++;
			$organizer=0;
			$attendee=0;
			$event="";
			#print "vevent start\n";
			while ($ics[$i+1] !~ "END:VEVENT")
			{
				($key,$value) = split(/:/,$ics[$i]);
				if (grep ($key,@fields))
				{
					#print "key = $key\n";
					#print "value = $value\n";
				}
				else
				{
					print "not found\n";
				}
				$event .= $ics[$i];
				if ($ics[$i] =~ "ORGANIZER")
				{
					$organizer=1;
				}
				if ($ics[$i] =~ "ATTENDEE")
				{
					$attendee=1;
				}
				$i++;
			}
			#print "vevent end\n";
			if ($attendee && !$organizer)
			{
				$event .= $ics[$i];
				$event .= $ics[$i+1];
				print "Invalid event.  Attendee but no organizer present!\n";
				if ($errorfile)
				{
					print ERRORFILE $event;
				}
				else
				{
					print $event;
				}
				$errors++;
			}
			else
			{
				if ($outfile)
				{
					$event .= $ics[$i];
					$event .= $ics[$i+1];
					print OUTICS $event;
				}
			}
		}
	}
	if ($outfile)
	{
		close(OUTFILE);
	}
	if ($errorfile)
	{
		close(ERRORFILE);
	}
	print "$errors error(s) out of a total of $count events present.\n";
}

sub usage()
{
	print "Usage:\n\n$0\t [--file <filename> | --outfile <filename> | --errorfile <filename>\n\n";
	print "\t--file <filename>\tOriginal ICS File to analyze\n";
	print "\t--outfile <filename>\tFile to store good ICS entries\n";
	print "\t--errorfile <filename>\tFile to store bad ICS entires\n";
}