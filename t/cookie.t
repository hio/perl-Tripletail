use Test::More tests => 9;
use Test::Exception;
use strict;
use warnings;

BEGIN {
    eval q{use Tripletail qw(/dev/null)};
}

END {
}

# print $TL->newForm(aaa => 111)->_freeze, "\n";
# h616161r79333333313333333133333331

# print $TL->newForm(aaa => 333)->_freeze, "\n";
# h616161r79333333333333333333333333

$ENV{HTTP_COOKIE} = 'foo=h616161r79333333313333333133333331';

my $c;
ok($c = $TL->getCookie('name'), 'getCookie');
ok($c = $TL->getCookie, 'getCookie');

my $form;
ok($form = $c->get('esa'), 'get');
ok($form = $c->get('foo'), 'get');

is($form->get('aaa'), '111', '$form->get');

dies_ok {$c->set('foo')} 'set die';
dies_ok {$c->set('foo',\123)} 'set die';

$form->set(aaa => 333);
$c->set(foo => $form);

my @set = $c->_makeSetCookies;
is($set[0], 'foo=h616161r79333333333333333333333333', '_makeSetCookies');

ok($c = $TL->getCookie, 'getCookie');
