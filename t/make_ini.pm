## ----------------------------------------------------------------------------
#  t/make_ini.pm
# -----------------------------------------------------------------------------
# Mastering programmed by YAMASHINA Hio
#
# Copyright YMIRLINK, Inc.
# -----------------------------------------------------------------------------
# $Id: make_ini.pm,v 1.3 2006/12/04 09:35:21 hio Exp $
# -----------------------------------------------------------------------------
package t::make_ini;
use strict;
use warnings;

our $USER;
our $INI_FILE;
our @cleanup;
our $NOCLEAN = $ENV{TL_TEST_NOCLEAN};

&setup;

1;

# -----------------------------------------------------------------------------
# $pkg->import({ ini => \%ini, });
# $pkg->import({ ini => sub{\%ini}, cleanup=>[qw(..)]);
# use t::make_ini \%opts;
# -----------------------------------------------------------------------------
sub import
{
	my $pkg  = shift;
	my $opts = shift;
	
	my $ini = $opts->{ini};
	$ini or die "no ini";
	ref($ini) eq 'CODE' and $ini = $ini->();
	write_ini($ini);
	
	if( $opts->{clean} )
	{
		push(@cleanup, @{$opts->{clean}});
	}
}

# -----------------------------------------------------------------------------
# setup.
# -----------------------------------------------------------------------------
sub setup
{
	$USER = eval{getpwuid($<)} || $ENV{USERNAME};
	$USER && $USER=~/^(\w+)\z/ or $USER = 'guest';
	
	$INI_FILE = "tmp$$.ini";
	-d "t" and $INI_FILE = "t/$INI_FILE";
}

# -----------------------------------------------------------------------------
# tear down.
# -----------------------------------------------------------------------------
END
{
	$NOCLEAN or unlink @cleanup;
}

# -----------------------------------------------------------------------------
# write_ini(%ini);
# write ini on $t::make_ini::INI_FILE;
# -----------------------------------------------------------------------------
sub write_ini
{
	my $hash = shift;
	
	#print STDERR "write [$INI_FILE]\n";
	open my $fh, '>', $INI_FILE or die "could not create file [$INI_FILE]: $!";
	my @keys = sort keys %$hash;
	@keys = ((grep{/^TL$/}@keys),(grep{!/^TL$/}@keys));
	my $cont = 0;
	foreach my $group (@keys)
	{
		$cont and print $fh "\n";
		print $fh "[$group]\n";
		foreach my $key (sort keys %{$hash->{$group}})
		{
			my $val = $hash->{$group}{$key};
			ref($val) eq 'ARRAY' and $val = join(',',@$val);
			print $fh "$key = $val\n";
		}
		$cont = 1;
	}
	close $fh;
	push(@cleanup, $INI_FILE);
}

# -----------------------------------------------------------------------------
# End of File.
# -----------------------------------------------------------------------------
