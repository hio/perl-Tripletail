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
