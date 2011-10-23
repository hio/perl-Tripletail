use Test::More;
use Test::Exception;

use strict;
use warnings;

BEGIN {
    open INI, '>', "tmp$$.ini";
    close INI;
    
    eval q{use Tripletail qw("tmp$$.ini")};
}

END {
    unlink "tmp$$.ini";
}


my $csv = eval {
	$TL->getCsv;
	$TL->getCsv;
};
if ($@) {
	if ($@ =~ m/(Text::CSV_XS is unavailable)/) {
		plan skip_all => $1;
	}
	else {
		die $@;
	}
}
else {
	plan tests => 14;
	
	ok($csv, 'getCsv');
}

my $p;
ok($p = $csv->parseCsv(\*DATA), 'parseCsv (fh)');
is_deeply($p->next, ['a,b', 'c"d', "e\nf"], 'next [0]');
is_deeply($p->next, [qw(1 2 3 4 5)], 'next[1]');
is($p->next, undef, 'next[2]');

ok($p = $csv->parseCsv('a,b,c'), 'parseCsv (scalar)');
is_deeply($p->next, [qw(a b c)], 'next [0]');
is($p->next, undef, 'next[1]');

ok($p = $csv->parseCsv('a",b,c'), 'parseCsv (error)');
eval {
	$p->next;
};
$@ ? pass('next [error]') : fail('next [error]');

dies_ok {$csv->makeCsv(\123)} 'makeCsv die';
is($csv->makeCsv([]), "", 'makeCsv [0]');
is($csv->makeCsv([1, 2, 3]), "1,2,3", 'makeCsv [1]');
is($csv->makeCsv(
	['a,b', 'c"d', "e\nf"]),
   qq{"a,b","c""d","e\nf"}, 'makeCsv [2]');

__END__
"a,b","c""d","e
f"
1,2,3,4,5
