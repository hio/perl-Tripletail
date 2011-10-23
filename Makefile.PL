use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Tripletail',
    AUTHOR              => 'Ymirlink <tl@tripletail.jp>',
    VERSION_FROM        => 'lib/Tripletail.pm',
    ABSTRACT_FROM       => 'lib/Tripletail.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'          => 0,
	'Crypt::CBC'          => 0,
	'Crypt::Rijndael'     => 0,
	'Data::Dumper'        => 0,
	'DBI'                 => 0,
	'Digest::HMAC_SHA1'   => 0,
	'File::Path'          => 0,
	'IO::Scalar'          => 0,
	'MIME::Tools'         => 5.411,
	'PadWalker'           => 1.0,
	'Text::CSV_XS'        => 0, # optional
	'Test::Exception'     => 0, # test
	'Unicode::Japanese'   => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);

sub MM::metafile_target
{
    # from MakeMaker-6.30.
    
    my $self = shift;

    return <<'MAKE_FRAG' if $self->{NO_META};
metafile:
	$(NOECHO) $(NOOP)
MAKE_FRAG

    my $prereq_pm = '';
    foreach my $mod ( sort { lc $a cmp lc $b } keys %{$self->{PREREQ_PM}} ) {
        my $ver = $self->{PREREQ_PM}{$mod};
        $prereq_pm .= sprintf "    %-30s %s\n", "$mod:", $ver;
    }
    
    my $meta = <<YAML;
# http://module-build.sourceforge.net/META-spec.html
#XXXXXXX This is a prototype!!!  It will change in the future!!! XXXXX#
name:         $self->{DISTNAME}
version:      $self->{VERSION}
version_from: $self->{VERSION_FROM}
installdirs:  $self->{INSTALLDIRS}
requires:
$prereq_pm
no_index: 
  directory: 
    - sample
    - t
distribution_type: module
generated_by: ExtUtils::MakeMaker version $ExtUtils::MakeMaker::VERSION
YAML

    my @write_meta = $self->echo($meta, 'META.yml');
    return sprintf <<'MAKE_FRAG', join "\n\t", @write_meta;
metafile :
	%s
MAKE_FRAG

}

# -----------------------------------------------------------------------------
# End of File.
# -----------------------------------------------------------------------------
