use Test::More tests => 25;
use Test::Exception;
use strict;
use warnings;

BEGIN {
    eval q{use Tripletail qw(/dev/null)};
}
END {
}

dies_ok {$TL->charconv} 'charconv die';
dies_ok {$TL->charconv(\123)} 'charconv die';
dies_ok {$TL->charconv('テスト',\123)} 'charconv die';
dies_ok {$TL->charconv('テスト','auto',\123)} 'charconv die';
dies_ok {$TL->charconv('テスト','auto','EUC-JP',\123)} 'charconv die';

is($TL->charconv("\xa5\xc6\xa5\xb9\xa5\xc8"), 'テスト', 'charconv auto(EUC-JP) => UTF-8');

is($TL->charconv('テスト', 'UTF-8' => 'EUC-JP'), "\xa5\xc6\xa5\xb9\xa5\xc8", 'charconv UTF-8 => EUC-JP');
is($TL->charconv('テスト', 'auto' => 'EUC-JP'), "\xa5\xc6\xa5\xb9\xa5\xc8", 'charconv auto(UTF-8) => EUC-JP');

is($TL->charconv("\xa5\xc6\xa5\xb9\xa5\xc8", 'EUC-JP' => 'UTF-8'), 'テスト', 'charconv EUC-JP => UTF-8');
is($TL->charconv("\xa5\xc6\xa5\xb9\xa5\xc8", 'auto' => 'UTF-8'), 'テスト', 'charconv auto(EUC-JP) => UTF-8');
is($TL->charconv("\xa5\xc6\xa5\xb9\xa5\xc8", 'auto' => 'utf8' ), 'テスト', 'charconv auto(EUC-JP) => UTF-8');

is($TL->charconv('テスト', 'auto' => 'Shift_JIS'), "\x83\x65\x83\x58\x83\x67", 'charconv auto(UTF-8) => Shift_JIS');
is($TL->charconv("\x83\x65\x83\x58\x83\x67", 'auto' => 'UTF-8'), 'テスト', 'charconv auto(Shift_JIS) => UTF-8');
is($TL->charconv("\x83\x65\x83\x58\x83\x67", ['Shift_JIS','UTF-8'] => 'Shift_JIS'), "\x83\x65\x83\x58\x83\x67", 'charconv Shift_JIS => Shift_JIS');

is($TL->charconv('テスト', 'auto' => 'ISO-2022-JP'), "\x1b\x24\x42\x25\x46\x25\x39\x25\x48\x1b\x28\x42", 'charconv auto(UTF-8) => ISO-2022-JP');
is($TL->charconv("\x1b\x24\x42\x25\x46\x25\x39\x25\x48\x1b\x28\x42", 'auto' => 'UTF-8'), 'テスト', 'charconv auto(ISO-2022-JP) => UTF-8');

is($TL->charconv("ABC123", 'auto' => 'UTF-8'), 'ABC123', 'charconv auto(ASCII) => UTF-8');

is($TL->charconv('テスト', 'UTF-8' => 'EUC-JP', 1), "\xa5\xc6\xa5\xb9\xa5\xc8", 'charconv UTF-8 => EUC-JP (encode)');
is($TL->charconv('テスト', 'auto' => 'EUC-JP', 1), "\xa5\xc6\xa5\xb9\xa5\xc8", 'charconv auto(UTF-8) => EUC-JP (encode)');

is($TL->charconv("\xa5\xc6\xa5\xb9\xa5\xc8", 'EUC-JP' => 'UTF-8', 1), 'テスト', 'charconv EUC-JP => UTF-8 (encode)');
is($TL->charconv("\xa5\xc6\xa5\xb9\xa5\xc8", 'auto' => 'UTF-8', 1), 'テスト', 'charconv auto(EUC-JP) => UTF-8 (encode)');
is($TL->charconv("\x83\x65\x83\x58\x83\x67", ['Shift_JIS','EUC-JP'] => 'UTF-8', 1), 'テスト', 'charconv EUC-JP,Shift_JIS => UTF-8 (encode)');
is($TL->charconv("\x83\x65\x83\x58\x83\x67", 'Shift_JIS' => 'Shift_JIS', 1), "\x83\x65\x83\x58\x83\x67", 'charconv Shift_JIS => Shift_JIS (encode)');

ok($TL->charconv("\xff\xd8\xff\xe0", 'auto' => 'ISO-2022-JP' , 1), 'charconv null');

require Tripletail::CharConv;
ok(Tripletail::CharConv->__getEncodeAliases, 'characonv __getEncodeAliases');