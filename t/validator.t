#! perl -w
use strict;
use warnings;
use Test::Exception;
use Test::More tests => 139;

use t::make_ini {
	ini => {
		TL => {
			trap => 'none',
		},
	},
};
use Tripletail $t::make_ini::INI_FILE;


#---------------------------------- 一般

my $form = $TL->newForm;
  my $validator;
  my $error;
  my @keys;

#---all
  ok($validator = $TL->newValidator, 'newValidator');
  ok($validator->addFilter(
    {
      name  => 'NotEmpty;NotWhitespace',
      email => 'NotEmpty;NotWhitespace[NotEmpty];Email',
    }
  ), 'addFilter');

sub toHash {
	$_ = {map {$_ => 1} @_};
	$_;
}
  ok(@keys = $validator->getKeys, 'getKeys');
  is_deeply(toHash(@keys), toHash(qw{email name}), 'getKeys');

  $form->set(email => ' ');
  ok($error = $validator->check($form), 'check');

  is($error->{name}, 'NotEmpty', 'check');
  is($error->{email}, 'NotEmpty', 'check');

  $form->set(name => '', email => 'mail@@mail');
  $error = $validator->check($form);

  is($error->{name}, 'NotEmpty', 'check');
  is($error->{email}, 'Email', 'check');

#---Blank
  $form->delete('notexists');
  $form->set(space => ' ');
  $form->set(null => '');
  $form->set(null2 => '');
  $form->set(notblank => '123');
  ok($validator->addFilter({
      notexists => 'Blank',
      space     => 'Blank',
      null      => 'Blank',
      null2     => 'Blank;Email',
      notblank  => 'Blank',
  }), 'addFilter');
  $error = $validator->check($form);
  is($error->{notexists}, undef, 'check');
  is($error->{space},     undef, 'check');
  is($error->{null},      undef, 'check');
  is($error->{null2},     undef, 'check');
  is($error->{notblank},  undef, 'check');

#---NotBlank
  $form->delete('notexists');
  $form->set(space => ' ');
  $form->set(null => '');
  $form->set(email => 'tl@tripletail.jp');
  ok($validator->addFilter({
      notexists => 'NotBlank',
      space     => 'NotBlank',
      null      => 'NotBlank',
      email     => 'NotBlank',
  }), 'addFilter');
  $error = $validator->check($form);
  is($error->{notexists}, 'NotBlank', 'check');
  is($error->{space},     'NotBlank', 'check');
  is($error->{null},      'NotBlank', 'check');
  is($error->{email},          undef, 'check');

#---Empty
  $form->delete('notexists');
  $form->set(space => ' ');
  $form->set(null => '');
  $form->set(null2 => '');
  $form->set(notempty => '123');
  ok($validator->addFilter({
      notexists => 'Empty',
      space     => 'Empty',
      null      => 'Empty',
      null2     => 'Empty;Email',
      notempty  => 'Empty',
  }), 'addFilter');
  $error = $validator->check($form);
  is($error->{notexists}, undef, 'check');
  is($error->{space},     undef, 'check');
  is($error->{null},      undef, 'check');
  is($error->{null2},     undef, 'check');

#---NotEmpty
  $form->delete('notexists');
  $form->set(space => ' ');
  $form->set(null => '');
  $form->set(email => 'tl@tripletail.jp');
  ok($validator->addFilter({
      notexists => 'NotEmpty',
      space     => 'NotEmpty',
      null      => 'NotEmpty',
      email     => 'NotEmpty',
  }), 'addFilter');
  ok($validator->addFilter({
      true  => 'NotEmpty',
      false  => 'NotEmpty',
  }), 'addFilter');
  $error = $validator->check($form);
  is($error->{notexists}, 'NotEmpty', 'check');
  is($error->{space},          undef, 'check');
  is($error->{null},      'NotEmpty', 'check');
  is($error->{email},          undef, 'check');

#---NotWhitespace
  $form->delete('notexists');
  $form->set(space => ' ');
  $form->set(null => '');
  $form->set(email => 'tl@tripletail.jp');
  ok($validator->addFilter({
      notexists => 'NotWhitespace',
      space     => 'NotWhitespace',
      null      => 'NotWhitespace',
      email     => 'NotWhitespace',
  }), 'addFilter');
  $error = $validator->check($form);
  is($error->{notexists},           undef, 'check');
  is($error->{space},     'NotWhitespace', 'check');
  is($error->{null},                undef, 'check');
  is($error->{email},               undef, 'check');

#---PrintableAscii
  ok($validator->addFilter({
      true  => 'PrintableAscii',
      false  => 'PrintableAscii',
  }), 'addFilter');
  $form->set(true => 'a', false => "\n");
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'PrintableAscii', 'check');

#---Wide
  ok($validator->addFilter({
      true  => 'Wide',
      false  => 'Wide',
  }), 'addFilter');
  $form->set(true => '　', false => ' ');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'Wide', 'check');

#---Password
  ok($validator->addFilter({
      true  => 'Password',
      false  => 'Password',
  }), 'addFilter');
  $form->set(true => '1Aa]', false => '1Aa');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'Password', 'check');

#---ZipCode
  ok($validator->addFilter({
      true  => 'ZipCode',
      false  => 'ZipCode',
  }), 'addFilter');
  $form->set(true => '000-0000', false => '00a-0000');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'ZipCode', 'check');

#---TelNumber
  ok($validator->addFilter({
      true  => 'TelNumber',
      false  => 'TelNumber',
  }), 'addFilter');
  $form->set(true => '0-0', false => 'a-0');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'TelNumber', 'check');

#---Email
  ok($validator->addFilter({
      true  => 'Email',
      false  => 'Email',
  }), 'addFilter');
  $form->set(true => 'null@example.org', false => 'null.@example.org');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'Email', 'check');

#---MobileEmail
  ok($validator->addFilter({
      true  => 'MobileEmail',
      false  => 'MobileEmail',
  }), 'addFilter');
  $form->set(true => 'null.@example.org', false => 'null@@example.org');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'MobileEmail', 'check');

#---Integer
  ok($validator->addFilter({
      true  => 'Integer(1,10)',
      false  => 'Integer(1,9)',
  }), 'addFilter');
  $form->set(true => 10, false => 10);
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'Integer', 'check');

  ok($validator->addFilter({
      true  => 'Integer(,20)',
      false  => 'Integer(,20)',
  }), 'addFilter');
  $form->set(true => 10, false => '100');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'Integer', 'check');

  ok($validator->addFilter({
      true  => 'Integer',
      false  => 'Integer',
  }), 'addFilter');
  $form->set(true => 10, false => '10a');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'Integer', 'check');

#---Real
  ok($validator->addFilter({
      true  => 'Real(1,2)',
      false  => 'Real(1,1)',
  }), 'addFilter');
  $form->set(true => 1.5, false => 1.5);
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'Real', 'check');

  ok($validator->addFilter({
      true  => 'Real(,2)',
      false  => 'Real(,1)',
  }), 'addFilter');
  $form->set(true => 1.5, false => 1.5);
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'Real', 'check');

  ok($validator->addFilter({
      true  => 'Real',
      false  => 'Real',
  }), 'addFilter');
  $form->set(true => 1.5, false => '10a');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'Real', 'check');

#---Hira
  ok($validator->addFilter({
      true  => 'Hira',
      false  => 'Hira',
  }), 'addFilter');
  $form->set(true => 'ひらがな', false => 'カタカナ');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'Hira', 'check');

#---Kata
  ok($validator->addFilter({
      true  => 'Kata',
      false  => 'Kata',
  }), 'addFilter');
  $form->set(true => 'カタカナ', false => 'ひらがな');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'Kata', 'check');

#---ExistentDay
  ok($validator->addFilter({
      true  => 'ExistentDay',
      false  => 'ExistentDay',
  }), 'addFilter');
  $form->set(true => '2006-02-28', false => '2006-02-29');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'ExistentDay', 'check');

#---Gif
  ok($validator->addFilter({
      true  => 'Gif',
      false  => 'Gif',
  }), 'addFilter');
  $form->set(true => 'GIF89a', false => 'GIF');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'Gif', 'check');

#---Jpeg
  ok($validator->addFilter({
      true  => 'Jpeg',
      false  => 'Jpeg',
  }), 'addFilter');
  $form->set(true => "\xFF\xD8", false => 'Jpeg');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'Jpeg', 'check');

#---Png
  ok($validator->addFilter({
      true  => 'Png',
      false  => 'Png',
  }), 'addFilter');
  $form->set(true => "\x89PNG\x0D\x0A\x1A\x0A", false => 'Png');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'Png', 'check');

#---HttpUrl
  ok($validator->addFilter({
      true  => 'HttpUrl',
      true2  => 'HttpUrl(s)',
      false  => 'HttpUrl',
  }), 'addFilter');
  $form->set(true => 'http://tripletail.jp/', true2 => 'https://tripletail.jp/', false => 'https://tripletail.jp/');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'HttpUrl', 'check');

  ok($validator->addFilter({
      true  => 'HttpUrl(a)',
      true2  => 'HttpUrl(s)',
      false  => 'HttpUrl(s)',
  }), 'addFilter');
  $form->set(true => 'http://tripletail.jp/', true2 => 'http://tripletail.jp/', false => 'tripletail.jp');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{true2}, undef, 'check');
  is($error->{false}, 'HttpUrl', 'check');

#---isHttpsUrl
  ok($validator->addFilter({
      true  => 'HttpsUrl',
      false  => 'HttpsUrl',
  }), 'addFilter');
  $form->set(true => 'https://tripletail.jp/', false => 'http://tripletail.jp/');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'HttpsUrl', 'check');

#---Len
  ok($validator->addFilter({
      true  => 'Len(1,3)',
      true2  => 'Len(,3)',
      true3  => 'Len',
      false  => 'Len(1,2)',
  }), 'addFilter');
  $form->set(true => 'あ', true2 => 'あ', false => 'あ');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{true2}, undef, 'check');
  is($error->{true3}, undef, 'check');
  is($error->{false}, 'Len', 'check');

#---SjisLen
  ok($validator->addFilter({
      true  => 'SjisLen(1,2)',
      true2  => 'SjisLen(,2)',
      true3  => 'SjisLen',
      false  => 'SjisLen(1,1)',
  }), 'addFilter');
  $form->set(true => 'あ', true2 => 'あ', false => 'あ');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{true2}, undef, 'check');
  is($error->{true3}, undef, 'check');
  is($error->{false}, 'SjisLen', 'check');

#---CharLen
  ok($validator->addFilter({
      true  => 'CharLen(1,2)',
      true2  => 'CharLen(,2)',
      true3  => 'CharLen',
      false  => 'CharLen(1,1)',
  }), 'addFilter');
  $form->set(true => 'あい', true2 => 'あい', false => 'あい');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{true2}, undef, 'check');
  is($error->{true3}, undef, 'check');
  is($error->{false}, 'CharLen', 'check');

#---Portable
  ok($validator->addFilter({
      true  => 'Portable',
      false  => 'Portable',
  }), 'addFilter');
  $form->set(true => 'I', false => 'Ⅰ');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'Portable', 'check');

#---IpAddress
  ok($validator->addFilter({
      true  => 'IpAddress(127.0.0.1/24)',
      false  => 'IpAddress(127.0.0.1/24)',
  }), 'addFilter');
  $form->set(true => '127.0.0.1', false => '128.0.0.1');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'IpAddress', 'check');
  ok($validator->addFilter({
      true  => 'IpAddress(0.0.0.0/0)',
      false  => 'IpAddress(0.0.0.0/0)',
  }), 'addFilter');
  $form->set(true => '127.0.0.1', false => '1.0.0');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'IpAddress', 'check');

#---Enum
  ok($validator->addFilter({
      true  => 'Enum(1,あ,テスト)',
      false  => 'Enum(1,あ,テスト)',
  }), 'addFilter');
  $form->set(true => 'テスト', false => 'あい');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'Enum', 'check');

#---Or
  ok($validator->addFilter({
      true  => 'Or(Hira|Kata)',
      true2  => 'Or(Hira|Kata)',
      false  => 'Or(Hira|Kata)',
  }), 'addFilter');
  $form->set(true => 'テスト', true2 => 'あ', false => 'あテスト');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{true2}, undef, 'check');
  is($error->{false}, 'Or', 'check');

#---RegExp
  ok($validator->addFilter({
      true  => 'RegExp(^\d+$)',
      false  => 'RegExp(^\d+$)',
  }), 'addFilter');
  $form->set(true => '12345', false => '12345 ');
  $error = $validator->check($form);
  is($error->{true}, undef, 'check');
  is($error->{false}, 'RegExp', 'check');


  ok($validator->addFilter({true => 'test;file'}), 'addFilter');
  dies_ok {$validator->check($form)} 'check die';
