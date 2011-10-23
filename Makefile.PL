use strict;
use warnings;
use ExtUtils::MakeMaker;
use inc::ExtUtils::MY_Metafile;

my $requires = {
    'DBI'                 => 0,
    'Data::Dumper'        => 0,
    'Digest::HMAC_SHA1'   => 0,
    'File::Path'          => 0,
    'IO::Scalar'          => 0, # IO-stringy
    'MIME::Tools'         => 5.411,
    'PadWalker'           => '1.0',
    'Unicode::Japanese'   => 0,
    'Text::CSV_XS'        => 0, # optional
    'Sub::ScopeFinalizer' => 0,
};

my $build_requires = {
    'Crypt::CBC'          => 0,
    'Crypt::Rijndael'     => 0,
    'IO::ScalarArray'     => '2.110', # IO-stringy, older one has inf-loop bug?
    'Test::Exception'     => 0,
    'Test::More'          => 0,
};

my_metafile Tripletail => {
  no_index => {
    directory => [qw(sample t)],
  },
  requires => $requires,
  build_requires => $build_requires,
  license => 'perl',
};

WriteMakefile(
    NAME                => 'Tripletail',
    AUTHOR              => 'Ymirlink <tl@tripletail.jp>',
    VERSION_FROM        => 'lib/Tripletail.pm',
    ABSTRACT_FROM       => 'lib/Tripletail.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        %$build_requires,
        %$requires,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);

# -----------------------------------------------------------------------------
# End of File.
# -----------------------------------------------------------------------------
