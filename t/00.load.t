use Test::More tests => 1;

BEGIN {
    open INI, '>', "temp$$.ini";
    close INI;
    
    use_ok( 'Tripletail', "temp$$.ini" );

    unlink "temp$$.ini";
}

diag( "Testing Tripletail $Tripletail::VERSION" );
