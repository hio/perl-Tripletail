use Test::More tests => 54;
use Test::Exception;
use strict;
use warnings;

BEGIN {
    eval q{use Tripletail qw(/dev/null)};
}

END {
}

my $m;
ok($m = $TL->newMail, 'newMail');
ok($m->get, 'get');
ok($m->set(q{日本語}), 'set');

ok($m->_encodeHeader(q{Subject: 日本語 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}), '_encodeHeader');
ok($m->_encodeHeader(q{aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}), '_encodeHeader');
ok($m->_encodeHeader(q{日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語}), '_encodeHeader');
ok($m->_encodeHeader(q{Subject: 日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語 日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語日本語}), '_encodeHeader');


ok($m->parse("From: =?ISO-2022-JP?B?GyRCOjk9UD9NGyhC?=\r\n".
               " =?ISO-2022-JP?B?IA==?=<null\@example.org>\r\n".
               "To: =?ISO-2022-JP?B?GyRCOjk9UD9NGyhC?=\r\n".
               " =?ISO-2022-JP?B?IA==?=<null\@example.org>\r\n".
               "Subject: =?ISO-2022-JP?B?GyRCJWEhPCVrN29MPhsoQg==?=\r\n".
               "\r\n".
               "mail body"), 'parse');

ok($m->set(q{Subject: 日本語ヘッダ
Content-Type: multipart/alternative; boundary="aaaa"
Content-Transfer-Encoding: quoted-printable

--aaaa
Content-Type: text/plain; charset=iso-2022-jp

--aaaa
Content-Type: text/html; charset=iso-2022-jp

--aaaa--
}), 'set');

ok($m->set(q{Subject: 日本語ヘッダ
Content-Type: multipart/alternative; boundary="aaaa"
Content-Transfer-Encoding: 7bit

--aaaa
Content-Type: text/plain; charset=iso-2022-jp

--aaaa
Content-Type: text/html; charset=iso-2022-jp

--aaaa--
}), 'set');

dies_ok {$m->set(q{Subject: 日本語ヘッダ
Content-Type: multipart/alternative; boundary="aaaa"

--bbbb
Content-Type: text/plain; charset=iso-2022-jp

--bbbb
Content-Type: text/html; charset=iso-2022-jp

--bbbb--
})} 'set die';

ok($m->set(q{Subject: 日本語ヘッダ

本文
}), 'set');

like($m->get, qr/Subject: 日本語ヘッダ/, 'get');
ok($m->get, 'get');


my %hash;
ok($m->setHeader(\%hash), 'setHeader');
dies_ok {$m->setHeader(\123)} 'setHeader die';
ok($m->setHeader(From => '日本語 <null@example.org>'), 'setHeader');

is($m->getHeader('Test'), undef, 'getHeader');
is($m->getHeader('From'), '日本語 <null@example.org>', 'getHeader');

$m->setHeader(Foo => 'テスト');
ok($m->deleteHeader('Foo'), 'deleteHeader [1]');
is($m->getHeader('Foo'), undef, 'deleteHeader [2]');

is($m->getBody, "本文\r\n", 'getBody');
ok($m->setBody("BODY"), 'setBody');
ok($m->toStr, 'toStr');


#dies_ok {$m->attach} 'attach die';
my $m2;
$m2 = $TL->newMail;

dies_ok {$m2->attach(
    type => undef,
   )} 'attach die';
dies_ok {$m2->attach(
    type => \123,
   )} 'attach die';
dies_ok {$m2->attach(
    type => 'text/plain',
    data => undef,
   )} 'attach die';
dies_ok {$m2->attach(
    type => 'text/plain',
    data => \123,
   )} 'attach die';

dies_ok {$m2->attach(
    part => \123,
   )} 'attach die';

ok($m2->attach(
    part => $TL->newMail,
   ), 'attach');

$m2->setHeader('Content-Type' => 'plain/text');
ok($m2->attach(
    part => $TL->newMail->setHeader('Content-Disposition' => 'inline'),
   ), 'attach');

ok($m2->attach(
    part => $TL->newMail,
   ), 'attach');

ok($m2->attach(
    type => 'text/html',
    data => 'MULTIPART',
   ), 'attach');

ok($m2->attach(
    type => 'application/xhtml+xml',
    data => 'MULTIPART',
   ), 'attach');

$m2->deleteHeader('Content-Type');
ok($m2->attach(
    type => 'text/html',
    data => 'MULTIPART',
   ), 'attach');

$m2->deleteHeader('Content-Type');
ok($m2->attach(
    type => 'application/xhtml+xml',
    data => 'MULTIPART',
    encoding => '7bit',
   ), 'attach');

ok($m2->attach(
    type => 'text/plain',
    data => 'MULTIPART',
    encoding => '7bit',
   ), 'attach');

ok($m2->attach(
    type => 'text/hdml',
    data => 'MULTIPART',
    filename => 'filename',
    id => 'content-id',
   ), 'attach');

ok($m2->attach(
    type => 'text/x-hdml',
    data => 'MULTIPART',
    encoding => 'base64',
   ), 'attach');

ok($m2->attach(
    type => 'etc',
    data => 'MULTIPART',
   ), 'attach');

ok($m2->attach(
    type => 'etc',
    data => 'MULTIPART',
    encoding => 'base64',
   ), 'attach');

ok($m->attach(
    type => 'text/plain',
    data => 'MULTIPART',
   ), 'attach');


is($m->countParts, 1, 'countParts');

my $child;
ok($child = $m->getPart(0), 'getPart');
dies_ok {$m->getPart} 'getPart die';
dies_ok {$m->getPart(\123)} 'getPart die';
dies_ok {$m->getPart(123)} 'getPart die';

is($child->getBody, 'MULTIPART', 'getBody(child)');

ok($m->deletePart(0), 'deletePart');
dies_ok {$m->deletePart} 'deletePart die';
dies_ok {$m->deletePart(\123)} 'deletePart die';
dies_ok {$m->deletePart(-1)} 'deletePart die';
dies_ok {$m->deletePart(500000)} 'deletePart die';

is($m->countParts, 0, 'countParts (after delete)');

