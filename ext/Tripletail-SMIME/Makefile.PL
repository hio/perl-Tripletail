use strict;
use warnings;
use ExtUtils::MakeMaker;

require 'openssl_config.PL';
my $OPENSSL = &openssl_config();

WriteMakefile(
    NAME                => 'Tripletail::SMIME',
    AUTHOR              => 'Ymirlink <tl@tripletail.jp>',
    VERSION_FROM        => 'SMIME.pm',
    ABSTRACT_FROM       => 'SMIME.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    LIBS                => "$OPENSSL->{LIBS}",
    INC                 => "$OPENSSL->{CFLAGS}",
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Tripletail-SMIME-*' },
    map{/([A-Z_]+)=(.*)/} @ARGV,
);

