#!/usr/bin/perl

use Net::LDAP;
use DBI;
use IO::File qw();
use XML::Simple;

if (! -d "/opt/zimbra/mailboxd")
{
	die "mailboxd not installed. exiting.\n";
}

my $localxml = XMLin("/opt/zimbra/conf/localconfig.xml");
my $ldappass = $localxml->{key}->{zimbra_ldap_password}->{value};
my $ldapdn  = $localxml->{key}->{zimbra_ldap_userdn}->{value};
my $ldapurl  = $localxml->{key}->{ldap_url}->{value};
my @replicas=split(/ /, $ldapurl);
my $hostname = $localxml->{key}->{zimbra_server_hostname}->{value};
my $ldapfilter = "(&(objectclass=zimbraAccount)(!(zimbraMailHost=$hostname))(!(creatorsName=cn=config)))";
my $db_server = $localxml->{key}->{mysql_bind_address}->{value};
my $db_port = $localxml->{key}->{mysql_port}->{value};
my $db_username = $localxml->{key}->{zimbra_mysql_user}->{value};
my $db_password = $localxml->{key}->{zimbra_mysql_password}->{value};
my $ldap_starttls_supported = $localxml->{key}->{ldap_starttls_supported}->{value};
my $zimbra_home = $localxml->{key}->{zimbra_home}->{value};
my $zimbra_require_interprocess_security = $localxml->{key}->{zimbra_require_interprocess_security}->{value};
my @row;
my $mailbox_id, $group_id, $mail_items, $mailbox_quota, $email, $mailhost;
my $totalspace=0;
my $numboxes=0;
my $zimbra_sql = "select id,group_id from zimbra.mailbox where comment=?";

$db_port||="7306";
$db_username||="zimbra";
$zimbra_home ||= "/opt/zimbra";

my $ldap = Net::LDAP->new(\@replicas)
 or die "Unable to connect to LDAP $@\n";
if ($ldap_url !~ /^ldaps/i) 
{
	if ($ldap_starttls_supported) 
	{
	  $mesg = $ldap->start_tls(
	      verify => 'none',
	      capath => "$zimbra_home/conf/ca",
	   ) or die "start_tls: $@";
	   $mesg->code && die "Could not execute StartTLS\n";
	}
}
my $dbh = DBI->connect("DBI:mysql:zimbra:$db_server:$db_port", $db_username, $db_password) or die "Unable to connect: $DBI::errstr\n";
my $mailbox = $dbh->prepare($zimbra_sql) or die "Can't prepare SQL statement: $DBI::errstr\n";
 
my $result = $ldap->bind(dn => $ldapdn, password => $ldappass);
my $searchresult = $ldap->search(filter => $ldapfilter, attrs => ['zimbraMailDeliveryAddress', 'zimbraMailHost']);
foreach my $entry ($searchresult->entries) 
{
	$email = $entry->get_value("zimbraMailDeliveryAddress");
	$mailhost = $entry->get_value("zimbraMailHost");
	$mailbox->execute($email) or die "Can't execute SQL statement: $DBI::errstr\n";
  if ( $mailbox_ref = $mailbox->fetchrow_arrayref )
  {
      $mailbox_id = $mailbox_ref->[0];
      $group_id = $mailbox_ref->[1];
			$mbox_sql = "select sum(size),count(size) from mboxgroup$group_id.mail_item where mailbox_id=?";
			$info = $dbh->prepare($mbox_sql) or warn "Can't prepare SQL statement: $DBI::errstr\n";
      $info->execute($mailbox_id) or warn "Can't execute SQL statement: $DBI::errstr\n";
      $info_ref = $info->fetchrow_arrayref;
      $info->finish;
      $mailbox_quota=$info_ref->[0];
      $mail_items=$info_ref->[1];
      print "$email has been moved to $mailhost, however $mail_items mail items remain, taking up " . optimize_size($mailbox_quota) . " in diskspace.\n";
      $numboxes++;
      $totalspace+=$mailbox_quota;
  }
  else
  {
     #print "Matched: ", $entry->get_value("zimbraMailDeliveryAddress"), "\n";
  }
  $mailbox->finish;
  warn "Data fetching terminated early by error: $DBI::errstr\n"
    if $DBI::err;
}

if ($numboxes > 0)
{
	print "\nA total of $numboxes mailboxes were moved to another host, taking up " . optimize_size($totalspace) . " of diskspace.\n";
	print "You should run zmpurgeoldmbox if these accounts are no longer needed on this host.\n";
}
else
{
	print "\nNo mailbox copies for moved mailboxes found.\n";
}

$ldap->unbind;
$dbh->disconnect
    or warn "Disconnection failed: $DBI::errstr\n";

sub optimize_size
{
  my($bytes) = @_;

  return '' unless $bytes;

  my($size);
  $size = $bytes . ' Bytes' if ($bytes < 1024);
  $size = sprintf("%.2f", ($bytes/1024)) . ' KB' if ($bytes >= 1024 && $bytes < 1048576);
  $size = sprintf("%.2f", ($bytes/1048576)) . ' MB' if ($bytes >= 1048576 && $bytes < 1073741824);
  $size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
  $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);

  return $size;
}

