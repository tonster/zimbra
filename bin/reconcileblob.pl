#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use XML::Simple;
use File::Find ();
use Time::Progress;

# for the convenience of &wanted calls, including -eval statements:
use vars qw/*name *dir *prune/;
*name   = *File::Find::name;
*dir    = *File::Find::dir;
*prune  = *File::Find::prune;

my $noblob_log = "/opt/zimbra/backups/reconcileblob-notfound.log";
my $altblobfound_log = "/opt/zimbra/backups/reconcileblob-altblob.log";
my $altblobmismatch_log = "/opt/zimbra/backups/reconcileblob-altblobmismatch.log";
my $localxml = XMLin("/opt/zimbra/conf/localconfig.xml");
my $zimbra_accounts_sql = "select id,group_id,comment from zimbra.mailbox";
my $zimbra_volumes_sql = "select * from zimbra.volumes where type='1'";
my $zimbra_numaccounts_sql = "select count(id) from zimbra.mailbox";
my $db_server = $localxml->{key}->{mysql_bind_address}->{value};
my $db_port = $localxml->{key}->{mysql_port}->{value};
my $db_username = $localxml->{key}->{zimbra_mysql_user}->{value};
my $db_password = $localxml->{key}->{zimbra_mysql_password}->{value};
$db_port||="7306";
$db_username||="zimbra";
$| = 1;
my $p = new Time::Progress;

open(NOBLOB, '>', $noblob_log) or die $!;
open(ALTBLOBFOUND, '>', $altblobfound_log) or die $!;
open(ALTBLOBMISMATCH, '>', $altblobmismatch_log) or die $!;

my $dbh = DBI->connect("DBI:mysql:zimbra:$db_server:$db_port", $db_username, $db_password) or die "Unable to connect: $DBI::errstr\n";
my $sth = $dbh->prepare($zimbra_accounts_sql) or die "Can't prepare SQL statement: $DBI::errstr\n";
$sth->execute();
my $accounts = $sth->fetchall_arrayref();

my $numaccountshandle = $dbh->prepare($zimbra_numaccounts_sql) or die "Can't prepare SQL statement: $DBI::errstr\n";
$numaccountshandle->execute();
my @numaccounts = $numaccountshandle->fetchrow_array();

my $progress_count = 0;
$p->attr( min => 0, max => scalar $numaccounts[0] );

foreach my $account (@$accounts)
{
	$progress_count++;
	(my $id, my $group_id, my $comment) = @$account;
	#print "Processing items for $comment...\n";
	my $zimbra_mailitem_sql = "select mail_items.id,mail_items.mod_content,mail_items.size,volume.path,volume.file_bits from mboxgroup$group_id.mail_item AS mail_items INNER JOIN zimbra.volume AS volume ON mail_items.locator = volume.id where mail_items.mailbox_id='$id' and volume.id !='3'";
	my $mailitem_handle = $dbh->prepare($zimbra_mailitem_sql) or die "Can't prepare SQL statement: $DBI::errstr\n";
	$mailitem_handle->execute();
	my $mailitems = $mailitem_handle->fetchall_arrayref();
	foreach my $mailitem (@$mailitems)
	{
		(my $item_id, my $mod_content, my $filesize, my $path, my $file_bits) = @$mailitem;
		my $id_shift = $item_id % (1024*1024) >> $file_bits;
		my $mailbox_id_shift = $id >> $file_bits;
		my $blob = $path . "/" . $mailbox_id_shift . "/" . $id . "/msg/" . $id_shift . "/" . $item_id . "-" . $mod_content . ".msg";
		#print "$item_id\t$mod_content\t$path\t$file_bits\n";
		if (!-e $blob)
		{
			#my $findfile = $path . "/" . $mailbox_id_shift . "/" . $id . "/msg/" . $id_shift . "/";
			my $findfile = $path . "/" . $mailbox_id_shift . "/" . $id . "/msg/";
			#print "$blob not found! Searching for blobs containing $item_id in $findfile...";
			my @foundfiles;
			File::Find::find ( sub {
                        return unless -f;
                        #return unless !/incoming/s;
                        return unless /^$item_id/s;
                        push @foundfiles, $File::Find::name;
                        #$File::Find::prune = @store_dirs > 2;
                }, $findfile );
			if ($#foundfiles >= 0)
			{
				#print $#foundfiles+1 . " found!\n";
				foreach my $file (@foundfiles)
				{
					my $found_filesize = (stat($file))[7];
					if ($found_filesize == $filesize)
					{
						print ALTBLOBFOUND "[$comment] Alternate blob $file for $blob found and is the right size!\n";
						#print "Found file $file is the right size!\n";
					}
					else
					{
						print ALTBLOBMISMATCH "[$comment] Alternate blob $file for $blob found, but size is wrong!\n";
						#print "File size differs. Original: $filesize Found: $found_filesize\n";
					}
				}
			}
			else
			{
				#print "none found.\n";
				print NOBLOB "[$comment] $blob not found!\n";
			}
			#print "$item_id\t$mod_content\t$blob\n";
		}
	}
	print $p->report("[%45b] %p (Account $progress_count/$numaccounts[0]) ETA: %E\r", $progress_count);
	#print "$id\t$group_id\t$comment\n";
}
print "\n";

close(NOBLOB);
close(ALTBLOBFOUND);
close(ALTBLOBMISMATCH);