use strict;
use warnings;
use YAML::XS 'LoadFile';
use Data::Dumper;
use MIME::Base64;

my $configs = LoadFile('zmc-configs.yml');
my $secrets = LoadFile('zmc-secrets.yml');

if (! -d ".config")
{
	mkdir ".config";
}

if (! -d ".secrets")
{
	mkdir ".secrets";
}

if (! -d ".keystore")
{
	mkdir ".keystore";
}

for (keys %{$configs->{data}})
{
	#print "$_: $configs->{data}->{$_}\n";
	open (FILE, ">.config/$_");
	print FILE $configs->{data}->{$_};
	close (FILE);
}

for (keys %{$secrets->{data}})
{
	if ($_ =~ "\\.csr" || $_ =~ "\\.crt" || $_ =~ "\\.pem" || $_ =~ "\\.key")
	{
		open (FILE, ">.keystore/$_");
		print FILE decode_base64($secrets->{data}->{$_});
		close (FILE);
	}
	else
	{
		open (FILE, ">.secrets/$_");
		print FILE decode_base64($secrets->{data}->{$_});
		close (FILE);
	}
}
