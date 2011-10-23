use Test::More tests => 23;
use Test::Exception;
use File::Spec;
use strict;
use warnings;

BEGIN {
    use Tripletail::SMIME;
    my $openssl = '/usr/local/ymir/perl/openssl/bin/openssl';
    if (!-x $openssl) {
        $openssl = '/usr/bin/openssl';
    }
    if(!-x $openssl && -e 'c:/openssl/bin/openssl.exe' )
    {
        $openssl = 'c:/openssl/bin/openssl.exe';
    }

    my $devnull = File::Spec->devnull();
    open(FILE, "> tmp-$$.config") or die $!;
    print FILE<<'CONFIG';
[ req ]
distinguished_name     = req_distinguished_name
attributes             = req_attributes
prompt                 = no
[ req_distinguished_name ]
C                      = AU
ST                     = Some-State
L                      = Test Locality
O                      = Organization Name
OU                     = Organizational Unit Name
CN                     = Common Name
emailAddress           = test@email.address
[ req_attributes ]
CONFIG
    close(FILE);
    foreach my $i (1 .. 2) {
	system(qq{$openssl genrsa > tmp-$$-$i.key 2>$devnull}) and die $!;
        system(qq{$openssl req -new -key tmp-$$-$i.key -out tmp-$$-$i.csr -config tmp-$$.config >$devnull}) and die $!;
	system(qq{$openssl x509 -in tmp-$$-$i.csr -out tmp-$$-$i.crt -req -signkey tmp-$$-$i.key -set_serial $i 2>$devnull >$devnull}) and die $!;
    }
}

END {
    foreach my $i (1 .. 2) {
	unlink "tmp-$$-$i.key", "tmp-$$-$i.csr", "tmp-$$-$i.crt";
    }
    unlink("tmp-$$.config");
}

sub key {
    my $i = shift;

    local $/ = undef;
    open my $fh, '<', "tmp-$$-$i.key";
    <$fh>;
}

sub crt {
    my $i = shift;

    local $/ = undef;
    open my $fh, '<', "tmp-$$-$i.crt";
    <$fh>;
}

my $plain = q{From: alice@example.org
To: bob@example.org
Subject: Tripletail::SMIME test

This is a test mail. Please ignore...
};
$plain =~ s/\r?\n|\r/\r\n/g;
my $verify = q{Subject: Tripletail::SMIME test

This is a test mail. Please ignore...
};
$verify =~ s/\r?\n|\r/\r\n/g;

#-----------------------

my $smime;
ok($smime = Tripletail::SMIME->new, 'new');

ok($smime->setPrivateKey(key(1), crt(1)), 'setPrivateKey (without passphrase)');

dies_ok {$smime->sign} 'sign undef';
dies_ok {$smime->sign(\123)} 'sign ref';
dies_ok {$smime->signonly} 'signonly undef';
dies_ok {$smime->signonly(\123)} 'signonly ref';
dies_ok {$smime->encrypt} 'encrypt undef';
dies_ok {$smime->encrypt(\123)} 'encrypt ref';
dies_ok {$smime->isSigned} 'isSigned undef';
dies_ok {$smime->isSigned(\123)} 'isSigned ref';
dies_ok {$smime->isEncrypted} 'isEncrypted undef';
dies_ok {$smime->isEncrypted(\123)} 'isEncrypted ref';

my $signed;
ok($signed = $smime->sign($plain), 'sign');
ok($smime->isSigned($signed), 'signed');

ok($smime->setPublicKey(crt(1)), 'setPublicKey (one key)');

my $checked;
ok($checked = $smime->check($signed), 'check');
is($checked, $verify, '$verify eq check(sign($plain))');

ok($smime->setPublicKey([crt(1), crt(2)]), 'setPublicKey (two keys)');

my $encrypted;
ok($encrypted = $smime->encrypt($plain), 'encrypt');
ok($smime->isEncrypted($encrypted), 'isEncrypted');

my $decrypted;
ok($decrypted = $smime->decrypt($encrypted), 'decrypt (by sender\'s key)');
is($decrypted, $verify, '$plain eq decrypt(encrypt($plain))');

$smime->setPrivateKey(key(2), crt(2));
ok($decrypted = $smime->decrypt($encrypted), 'decrypt (by recipient\'s key)');

1;
