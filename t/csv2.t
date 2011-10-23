use Test::More;
use Test::Exception tests => 1;

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

require Tripletail::CSV;
	dies_ok {delete $INC{"Text/CSV_XS.pm"};local(@INC);Tripletail::CSV->_new;}
