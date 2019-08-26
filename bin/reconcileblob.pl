#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use XML::Simple;
use File::Find ();

# for the convenience of &wanted calls, including -eval statements:
use vars qw/*name *dir *prune/;
*name   = *File::Find::name;
*dir    = *File::Find::dir;
*prune  = *File::Find::prune;

my $localxml = XMLin("/opt/zimbra/conf/localconfig.xml");
my $zimbra_accounts_sql = "select id,group_id,comment from zimbra.mailbox";
my $zimbra_volumes_sql = "select * from zimbra.volumes where type='1'";
my $db_server = $localxml->{key}->{mysql_bind_address}->{value};
my $db_port = $localxml->{key}->{mysql_port}->{value};
my $db_username = $localxml->{key}->{zimbra_mysql_user}->{value};
my $db_password = $localxml->{key}->{zimbra_mysql_password}->{value};
$db_port||="7306";
$db_username||="zimbra";

my $dbh = DBI->connect("DBI:mysql:zimbra:$db_server:$db_port", $db_username, $db_password) or die "Unable to connect: $DBI::errstr\n";
my $sth = $dbh->prepare($zimbra_accounts_sql) or die "Can't prepare SQL statement: $DBI::errstr\n";
$sth->execute();
my $accounts = $sth->fetchall_arrayref();

foreach my $account (@$accounts)
{
	(my $id, my $group_id, my $comment) = @$account;
	print "Processing items for $comment...\n";
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
			print "$blob not found! Searching for blobs containing $item_id in $findfile...";
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
				print $#foundfiles+1 . " found!\n";
				foreach my $file (@foundfiles)
				{
					my $found_filesize = (stat($file))[7];
					if ($found_filesize == $filesize)
					{
						print "Found file $file is the right size!\n";
					}
				}
			}
			else
			{
				print "none found.\n";
			}
			#print "$item_id\t$mod_content\t$blob\n";
		}
	}
	#print "$id\t$group_id\t$comment\n";
}

#4841    30454   /opt/zimbra/store/12288/3/msg/19828736/4841-30454.99104/1074-11998.msg