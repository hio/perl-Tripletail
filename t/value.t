BEGIN {
    open my $fh, '>', "tmp$$.ini";
    print $fh q{
[TL]
trap = none
};
    close $fh;
    eval q{use Tripletail "tmp$$.ini"};
}

END {
    unlink "tmp$$.ini";
}

use strict;
use warnings;
use Test::Exception;
use Test::More tests => 130;

#---------------------------------- 一般
my $v;
ok($v = $TL->newValue(''), 'new');
ok($v->set('***'), 'set');
is($v->get, '***', 'get');
dies_ok {$v->set(undef)} 'set die';
dies_ok {$v->set(\123)} 'set die';

#---------------------------------- set系
is($v->setDate(2000,1,1)->get, '2000-01-01', 'setDate');
is($v->setDate(2000,99,99)->get, undef, 'setDate');
is($v->setDateTime(2000,1,1,2,3,4)->get, '2000-01-01 02:03:04', 'setDateTime');
is($v->setDateTime(2000,1,1,2,3,99)->get, undef, 'setDateTime');
is($v->setTime(1,2,3)->get, '01:02:03', 'setTime');
is($v->setTime(5)->get, '05:00:00', 'setTime');
is($v->setTime(99)->get, undef, 'setTime');

#---------------------------------- get系
$v->set('あ');
is($v->getLen, 3, 'getLen');
is($v->getSjisLen, 2, 'getSjisLen');
is($v->getCharLen, 1, 'getCharLen');

$v->setDate(2000,8,1);
ok($v->getAge, 'getAge');
is($v->getAge('2005-08-01'), 5, 'getAge');
is($v->getAge('2005-07-31'), 4, 'getAge');
is($v->getAge('****-**-**'), undef, 'getAge');

my $re_hira = qr/(\xe3\x81\x81|\xe3\x81\x82|\xe3\x81\x83|\xe3\x81\x84|\xe3\x81\x85|\xe3\x81\x86|\xe3\x81\x87|\xe3\x81\x88|\xe3\x81\x89|\xe3\x81\x8a|\xe3\x81\x8b|\xe3\x81\x8c|\xe3\x81\x8d|\xe3\x81\x8e|\xe3\x81\x8f|\xe3\x81\x90|\xe3\x81\x91|\xe3\x81\x92|\xe3\x81\x93|\xe3\x81\x94|\xe3\x81\x95|\xe3\x81\x96|\xe3\x81\x97|\xe3\x81\x98|\xe3\x81\x99|\xe3\x81\x9a|\xe3\x81\x9b|\xe3\x81\x9c|\xe3\x81\x9d|\xe3\x81\x9e|\xe3\x81\x9f|\xe3\x81\xa0|\xe3\x81\xa1|\xe3\x81\xa2|\xe3\x81\xa3|\xe3\x81\xa4|\xe3\x81\xa5|\xe3\x81\xa6|\xe3\x81\xa7|\xe3\x81\xa8|\xe3\x81\xa9|\xe3\x81\xaa|\xe3\x81\xab|\xe3\x81\xac|\xe3\x81\xad|\xe3\x81\xae|\xe3\x81\xaf|\xe3\x81\xb0|\xe3\x81\xb1|\xe3\x81\xb2|\xe3\x81\xb3|\xe3\x81\xb4|\xe3\x81\xb5|\xe3\x81\xb6|\xe3\x81\xb7|\xe3\x81\xb8|\xe3\x81\xb9|\xe3\x81\xba|\xe3\x81\xbb|\xe3\x81\xbc|\xe3\x81\xbd|\xe3\x81\xbe|\xe3\x81\xbf|\xe3\x82\x80|\xe3\x82\x81|\xe3\x82\x82|\xe3\x82\x83|\xe3\x82\x84|\xe3\x82\x85|\xe3\x82\x86|\xe3\x82\x87|\xe3\x82\x88|\xe3\x82\x89|\xe3\x82\x8a|\xe3\x82\x8b|\xe3\x82\x8c|\xe3\x82\x8d|\xe3\x82\x8e|\xe3\x82\x8f|\xe3\x82\x90|\xe3\x82\x91|\xe3\x82\x92|\xe3\x82\x93)/;
my $re_kata = qr/(\xe3\x82\xa1|\xe3\x82\xa2|\xe3\x82\xa3|\xe3\x82\xa4|\xe3\x82\xa5|\xe3\x82\xa6|\xe3\x82\xa7|\xe3\x82\xa8|\xe3\x82\xa9|\xe3\x82\xaa|\xe3\x82\xab|\xe3\x82\xac|\xe3\x82\xad|\xe3\x82\xae|\xe3\x82\xaf|\xe3\x82\xb0|\xe3\x82\xb1|\xe3\x82\xb2|\xe3\x82\xb3|\xe3\x82\xb4|\xe3\x82\xb5|\xe3\x82\xb6|\xe3\x82\xb7|\xe3\x82\xb8|\xe3\x82\xb9|\xe3\x82\xba|\xe3\x82\xbb|\xe3\x82\xbc|\xe3\x82\xbd|\xe3\x82\xbe|\xe3\x82\xbf|\xe3\x83\x80|\xe3\x83\x81|\xe3\x83\x82|\xe3\x83\x83|\xe3\x83\x84|\xe3\x83\x85|\xe3\x83\x86|\xe3\x83\x87|\xe3\x83\x88|\xe3\x83\x89|\xe3\x83\x8a|\xe3\x83\x8b|\xe3\x83\x8c|\xe3\x83\x8d|\xe3\x83\x8e|\xe3\x83\x8f|\xe3\x83\x90|\xe3\x83\x91|\xe3\x83\x92|\xe3\x83\x93|\xe3\x83\x94|\xe3\x83\x95|\xe3\x83\x96|\xe3\x83\x97|\xe3\x83\x98|\xe3\x83\x99|\xe3\x83\x9a|\xe3\x83\x9b|\xe3\x83\x9c|\xe3\x83\x9d|\xe3\x83\x9e|\xe3\x83\x9f|\xe3\x83\xa0|\xe3\x83\xa1|\xe3\x83\xa2|\xe3\x83\xa3|\xe3\x83\xa4|\xe3\x83\xa5|\xe3\x83\xa6|\xe3\x83\xa7|\xe3\x83\xa8|\xe3\x83\xa9|\xe3\x83\xaa|\xe3\x83\xab|\xe3\x83\xac|\xe3\x83\xad|\xe3\x83\xae|\xe3\x83\xaf|\xe3\x83\xb0|\xe3\x83\xb1|\xe3\x83\xb2|\xe3\x83\xb3)/;
my $re_narrownum = qr{\d};
my $re_widenum = qr/(\xef\xbc\x90|\xef\xbc\x91|\xef\xbc\x92|\xef\xbc\x93|\xef\xbc\x94|\xef\xbc\x95|\xef\xbc\x96|\xef\xbc\x97|\xef\xbc\x98|\xef\xbc\x99)/;
dies_ok {$v->getRegexp(undef)} 'getRegexp undef';
dies_ok {$v->getRegexp(\123)} 'getRegexp SCALAR';
is($v->getRegexp('HIra'), $re_hira, 'getRegexp');
is($v->getRegexp('kata'), $re_kata, 'getRegexp');
is($v->getRegexp('numbernarrow'), $re_narrownum, 'getRegexp');
is($v->getRegexp('numberwide'), $re_widenum, 'getRegexp');
dies_ok {$v->getRegexp('***')} 'getRegexp';

#---------------------------------- is系
ok($v->set('')->isEmpty, 'isEmpty');

ok($v->set(' ')->isWhitespace, 'isWhitespace');
ok(! $v->set('')->isWhitespace, 'isWhitespace');

ok($v->set(' ')->isBlank, 'isBlank');
ok($v->set('')->isBlank, 'isBlank');

ok(! $v->set('')->isPrintableAscii, 'isPrintableAscii');
ok(! $v->set('　')->isPrintableAscii, 'isPrintableAscii');
ok($v->set(' ')->isPrintableAscii, 'isPrintableAscii');
ok($v->set('a')->isPrintableAscii, 'isPrintableAscii');
ok($v->set('a ')->isPrintableAscii, 'isPrintableAscii');
ok(! $v->set("\n")->isPrintableAscii, 'isPrintableAscii');

ok(! $v->set('')->isWide, 'isWide');
ok($v->set('　')->isWide, 'isWide');
ok(! $v->set('1あＡ')->isWide, 'isWide');
ok(! $v->set('1あＡ')->isWide, 'isWide');
ok(! $v->set('ｱ')->isWide, 'isWide');

ok($v->set('_1aA')->isPassword, 'isPassword');
ok(! $v->set('1aA')->isPassword, 'isPassword');
ok(! $v->set('あ_1aA')->isPassword, 'isPassword');

ok($v->set('112-3345')->isZipCode, 'isZipCode');
ok($v->set('743-48763-3216')->isTelNumber, 'isTelNumber');
   
ok($v->set('null@example.org')->isEmail, 'isEmail');
ok(! $v->set('null.@example.org')->isEmail, 'isEmail');
ok($v->set('null.@example.org')->isMobileEmail, 'isMobileEmail');

$v->set(500);
ok($v->isInteger, 'isInteger');
ok($v->isInteger(0, 500), 'isInteger');
ok(! $v->isInteger(0, 499), 'isInteger');
ok(! $v->set('100.1')->isInteger, 'isInteger');

$v->set(500.52);
ok($v->isReal, 'isReal');
ok($v->isReal(0, 500.6), 'isReal');
ok(! $v->isReal(0, 500.51), 'isReal');
ok(! $v->set('500.')->isReal, 'isReal');

ok($v->set('あああ')->isHira, 'isHira');
ok(! $v->set('あああ1')->isHira, 'isHira');
ok($v->set('アアア')->isKata, 'isKata');
ok(! $v->set('アアア1')->isKata, 'isKata');

ok($v->set('2004-02-29')->isExistentDay, 'isExistentDay');
ok(! $v->set('2003-02-29')->isExistentDay, 'isExistentDay');

ok($v->set('GIF89a-----')->isGif, 'isGif');
ok($v->set("\xFF\xD8-----")->isJpeg, 'isJpeg');
ok($v->set("\x89PNG\x0D\x0A\x1A\x0A-----")->isPng, 'isPng');

ok($v->set("https://foo/")->isHttpsUrl, 'isHttpsUrl');
ok($v->set("http://foo/")->isHttpUrl, 'isHttpUrl');

$v->set('テスト');
ok($v->isLen(0, 9), 'isLen');
ok(! $v->isLen(0, 8), 'isLen');
ok($v->isSjisLen(0, 6), 'isSjisLen');
ok(! $v->isSjisLen(0, 5), 'isSjisLen');
ok($v->isCharLen(0, 3), 'isCharLen');
ok(! $v->isCharLen(0, 2), 'isCharLen');

is($v->set("192.168.0.1")->isIpAddress("10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.1 fe80::/10 ::1"), 1, 'isIpAddress');
is($v->set("255.168.0.1")->isIpAddress("10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.1 fe80::/10 ::1"), undef, 'isIpAddress');
is($v->set("255.168.0.1")->isIpAddress, undef, 'isIpAddress error');
is($v->set("255.168.0.1")->isIpAddress(\123), undef, 'isIpAddress error');
is($v->set("fe80::1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1")->isIpAddress('192.168.0.1'), undef, 'isIpAddress error');
is($v->set("255.168.0.1")->isIpAddress('fe80::1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1:1/10'), undef, 'isIpAddress error');

#---------------------------------- conv系

is($v->set('1あアあ')->convHira->get, '1あああ', 'convHira');
is($v->set('1あアあ')->convKata->get, '1アアア', 'convKata');
is($v->set('あ１２３')->convNumber->get, 'あ123', 'convNumber');
is($v->set('_！１Ａ')->convNarrow->get, '_!1A', 'convNarrow');
is($v->set('＃3b')->convWide->get, '＃３ｂ', 'convWide');
is($v->set('1')->convComma->get, '1', 'convComma');
is($v->set('12')->convComma->get, '12', 'convComma');
is($v->set('123')->convComma->get, '123', 'convComma');
is($v->set('1234')->convComma->get, '1,234', 'convComma');
is($v->set('12345')->convComma->get, '12,345', 'convComma');
is($v->set('123456')->convComma->get, '123,456', 'convComma');
is($v->set('1234567')->convComma->get, '1,234,567', 'convComma');
is($v->set('12345678')->convComma->get, '12,345,678', 'convComma');
is($v->set('-12345678')->convComma->get, '-12,345,678', 'convComma');
is($v->set('-12345678.9')->convComma->get, '-12,345,678.9', 'convComma');

is($v->set("\n\n")->convLF->get, "\n\n", 'forceLF');
is($v->set("\r\n\r\n")->convLF->get, "\n\n", 'forceLF');
is($v->set("\r\r")->convLF->get, "\n\n", 'forceLF');

is($v->set("\n")->convBR->get, "<BR>\n", 'forceBR');
is($v->set("\r")->convBR->get, "<BR>\n", 'forceBR');
is($v->set("\r\n")->convBR->get, "<BR>\n", 'forceBR');

#---------------------------------- force系

is($v->set('1あア')->forceHira->get, 'あ', 'forceHira');
is($v->set('1あア')->forceKata->get, 'ア', 'forceKata');
is($v->set('１ａｂ9')->forceNumber->get, '9', 'forceNumber');

dies_ok {$v->set(500)->forceMin(undef)} 'set undef';
dies_ok {$v->set(500)->forceMin(\123)} 'set SCALAR';
is($v->set(500)->forceMin(10, 'foo')->get, '500', 'forceMin');
is($v->set(  5)->forceMin(10, 'foo')->get, 'foo', 'forceMin');
dies_ok {$v->set(500)->forceMax(undef)} 'set undef';
dies_ok {$v->set(500)->forceMax(\123)} 'set SCALAR';
is($v->set(500)->forceMax(10, 'foo')->get, 'foo', 'forceMax');
is($v->set(  5)->forceMax(10, 'foo')->get, '5'  , 'forceMax');

is($v->set('あえいおう')->forceMaxLen(6)->get, 'あえ', 'forceMaxLen');
is($v->set('あえいおう')->forceMaxUtf8Len(5)->get, 'あ', 'forceMaxUtf8Len');
is($v->set('あえいおう')->forceMaxSjisLen(5)->get, 'あえ', 'forceMaxSjisLen');
is($v->set('あえいおう')->forceMaxCharLen(4)->get, 'あえいお', 'forceMaxCharLen');

#---------------------------------- その他

is($v->set(' A ')->trimWhitespace->get, 'A', 'trimWhitespace');
is($v->set('　A　')->trimWhitespace->get, 'A', 'trimWhitespace');
is($v->set("\t\tA\t\t")->trimWhitespace->get, 'A', 'trimWhitespace');
is($v->set("\t\t 　\tA  A\t 　　\t")->trimWhitespace->get, 'A  A', 'trimWhitespace');
ok(! $v->set(Unicode::Japanese->new("\xED\x40", 'sjis')->utf8)->isPortable, 'isPortable');
ok($v->set('あ')->isPortable, 'isPortable');
is($v->set("あああ　えええ")->countWords, 2, 'countWords');

my @str;
ok(@str = $v->set('あabいうえcdお')->strCut(2), 'strCut');

is($str[0],'あa','strCut');
is($str[1],'bい','strCut');
is($str[2],'うえ','strCut');
is($str[3],'cd','strCut');
is($str[4],'お','strCut');

