use Test::More;
use Test::Exception;
use strict;
use warnings;

BEGIN {
    eval q{use Tripletail qw(/dev/null)};
}

END {
}

if(!$ENV{TL_MEMCACHE_CHECK}){
   plan skip_all => "Cache::Memcached check skip. Please set TL_MEMCACHE_CHECK = 1 when checking.";
}

eval "use Cache::Memcached";
if ($@) {
    plan skip_all => "Cache::Memcached are required for these tests...";
}

plan tests => 15;

my $mem;
ok($mem = $TL->newMemCached, 'newMemCached');

is($mem->set('TLTEST' => 10), 1, 'set');
dies_ok {$mem->set} 'set die';
dies_ok {$mem->set(\123)} 'set die';
dies_ok {$mem->set(' ')} 'set die';
dies_ok {$mem->set('TLTEST')} 'set die';
dies_ok {$mem->set('TLTEST' => \123)} 'set die';

is($mem->get('TLTEST'), 10, 'get');
dies_ok {$mem->get} 'get die';
dies_ok {$mem->get(\123)} 'get die';
dies_ok {$mem->get(' ')} 'get die';

is($mem->delete('TLTEST'), 1, 'delete');
dies_ok {$mem->delete} 'delete die';
dies_ok {$mem->delete(\123)} 'delete die';
dies_ok {$mem->delete(' ')} 'delete die';
