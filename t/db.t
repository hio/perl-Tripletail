use Test::More;
use Test::Exception;
use strict;
use warnings;


BEGIN {
    my ($name) = eval{getpwuid($<)} || $ENV{USERNAME};
    $name = $name && $name=~/^(\w+)$/ ? $1 : 'guest';
    
    open my $fh, '>', "tmp$$.ini";
    print $fh qq{
[TL]
trap = none

[DB]
type   = mysql
defaultset = SET_Default
SET_Default = CON_DBR1

[CON_DBR1]
host   = localhost
user   = $name
dbname = test
};
    close $fh;
    eval q{use Tripletail "tmp$$.ini"};
}

END {
    unlink "tmp$$.ini";
}

eval {
    $TL->errorTrap(
	-DB   => 'DB',
	-main => sub {},
       );
};
if ($@) {
	plan skip_all => "Failed to connect to local MySQL: $@";
}

plan tests => 67;

dies_ok {$TL->getDB} '_getInstance die';

eval {
    $TL->errorTrap(
	-DB   => 'DB',
	-main => \&main,
       );
};
if ($@) {
	die $@;
}

sub main {

    my $DB;
	dies_ok {$TL->getDB(\123)} '_getInstance die';
	ok($DB = $TL->newDB('DB'), 'newDB');
	ok($DB->connect, 'connect');
	ok($DB->disconnect, 'disconnect');
	
    ok($DB = $TL->getDB, 'getDB');
    ok($DB = $TL->getDB('DB'), 'getDB');
    dies_ok {$DB->begin(\123)} 'getDB die';
    dies_ok {$DB->begin('getDB')} 'getDB die';

    dies_ok {$DB->rollback} 'rollback die';
    dies_ok {$DB->commit} 'commit die';
    dies_ok {$DB->unlock} 'unlock die';
    $DB->begin('SET_Default');
    dies_ok {$DB->begin('SET_Default')} 'begin die';
    $DB->commit;
    dies_ok {$DB->execute} 'execute die';
    dies_ok {$DB->execute(\123,\123)} 'execute die';
    dies_ok {$DB->execute(q{ LOCK })} 'execute die';
    dies_ok {$DB->execute(q{??})} 'execute die';
    dies_ok {$DB->execute(q{ LOCK })} 'execute die';
    dies_ok {$DB->setBufferSize(\123)} 'setBufferSize die';
    dies_ok {$DB->symquote} 'symquote die';
    dies_ok {$DB->symquote(\123)} 'symquote die';
    dies_ok {$DB->symquote('"')} 'symquote die';
	is($DB->symquote('a b c'), '`a b c`', 'symquote');

    ok($DB->begin('SET_Default'), 'begin');
    ok($DB->execute('SHOW TABLES'), 'execute');
    ok($DB->rollback, 'rollback');

	$DB->begin('SET_Default');
	# 注意: テストスクリプトを二つ同時に走らせるとおかしくなる。
	$DB->execute(q{
        DROP TABLE IF EXISTS TripletaiL_DB_Test
    });
	$DB->execute(q{
        CREATE TABLE TripletaiL_DB_Test (
            foo   BLOB,
            bar   BLOB,
            baz   BLOB
        )
    });
	$DB->commit;

    ok($DB->execute('SHOW TABLES'), 'execute w/o transaction');
    ok($DB->setDefaultSet('SET_Default'), 'setDefaultSet');
    ok($DB->execute('SHOW TABLES'), 'execute w/o transaction');

	dies_ok {$DB->execute(
		\'die' => q{
        INSERT INTO TripletaiL_DB_Test
               (foo, bar, baz)
        VALUES (?,   ?,   ?  )
    }, 'QQQ', 'WWW', 'EEE'), 'execute die'};

	ok($DB->execute(
		\'SET_Default' => q{
        INSERT INTO TripletaiL_DB_Test
               (foo, bar, baz)
        VALUES (?,   ?,   ?  )
    }, 'QQQ', 'WWW', 'EEE'), 'execute with explicit DBSet');

	ok($DB->execute(q{
		SELECT *
          FROM TripletaiL_DB_Test
         LIMIT ??
    }, [1, 2, \'SQL_INTEGER']), 'execute with fully typed parameters');

#	ok($DB->execute(q{
#		SELECT *
#        FROM TripletaiL_DB_Test
#         LIMIT ??
#   }, 123), 'execute with fully typed parameters');

    dies_ok {$DB->execute(q{
		SELECT *
          FROM TripletaiL_DB_Test
	LIMIT ??
    },123)} 'execute die';

    dies_ok {$DB->execute(q{
		SELECT *
          FROM TripletaiL_DB_Test
	LIMIT ??
    },\1)} 'execute die';

    dies_ok {$DB->execute(q{
		SELECT *
          FROM TripletaiL_DB_Test
    },[\1])} 'execute die';

    dies_ok {$DB->execute(q{
		SELECT *
         FROM TripletaiL_DB_Test
	LIMIT ??
    },[])} 'execute die';

	my $insertsth;
	ok($insertsth = $DB->execute(q{
        INSERT INTO TripletaiL_DB_Test
               (foo, bar)
        VALUES (??)
    }, [1, [2, \'SQL_VARCHAR']]), 'execute with partly typed parameters');
	is($insertsth->ret, 1, 'execute return value');
	
	ok($DB->execute(q{
        INSERT INTO TripletaiL_DB_Test
               (foo, bar)
        VALUES (??)
    }, [3, [4, \'SQL_VARCHAR'], \'SQL_INTEGER']), 'execute with both partly and fully typed parameters');

	my $array;
	ok($array = $DB->selectAllHash(q{
        SELECT *
          FROM TripletaiL_DB_Test
    }), 'selectAllHash');
	is_deeply($array, [
		{foo => 'QQQ', bar => 'WWW', baz => 'EEE'},
		{foo => 1,     bar => 2,     baz => undef},
		{foo => 3,     bar => 4,     baz => undef},
	   ], 'content of selectAllHash()');

	ok($array = $DB->selectAllArray(q{
        SELECT *
          FROM TripletaiL_DB_Test
         WHERE foo = ?
    }, 'QQQ'), 'selectAllArray');
	is_deeply($array, [['QQQ', 'WWW', 'EEE']], 'content of selectAllArray()');

	is_deeply($DB->selectRowHash(q{
		SELECT *
		  FROM TripletaiL_DB_Test
	}), {foo => 'QQQ', bar => 'WWW', baz => 'EEE'}, 'selectRowHash');
	is_deeply($DB->selectRowHash(q{
		SELECT *
		  FROM TripletaiL_DB_Test
		 WHERE 0
	}), undef, 'selectRowHash, no-record becomes empty hashref');

	is_deeply($DB->selectRowArray(q{
		SELECT *
		  FROM TripletaiL_DB_Test
        }), ['QQQ', 'WWW', 'EEE'], 'selectRowArray');

	is_deeply($DB->selectRowArray(q{
		SELECT *
		  FROM TripletaiL_DB_Test
		 WHERE 0
	}), undef, 'selectRowArray, no-record becomes empty arrayref');

	ok($DB->lock(read => 'TripletaiL_DB_Test'), 'lock');
	dies_ok {$DB->lock(read => 'TripletaiL_DB_Test')} 'lock die';

	ok($DB->unlock, 'unlock');

	ok($DB->lock(set => 'SET_Default', read => 'TripletaiL_DB_Test'), 'lock with DBSet');
	$DB->unlock;

	ok($DB->setBufferSize(0), 'setBufferSize');

	is($DB->symquote('a b c'), '`a b c`', 'symquote');
	
    is($DB->getType, 'mysql', 'getType');

	is(ref($DB->getDbh), 'DBI::db', 'getDbh');

	my $sth = $DB->execute(q{
        SELECT *
          FROM TripletaiL_DB_Test
    });
	
	my $hash;
	ok($hash = $sth->fetchHash, 'fetchHash');
	is_deeply($hash, {foo => 'QQQ', bar => 'WWW', baz => 'EEE'}, 'content of fetchHash()');

	ok($array = $sth->fetchArray, 'fetchArray');
	is_deeply($array, [1, 2, undef], 'content of fetchArray()');

	1 while $sth->fetchArray;
	is($sth->rows, 3, 'rows');

	is_deeply($sth->nameArray, ['foo', 'bar', 'baz'], 'nameArray');
	is_deeply($sth->nameHash, {foo => 0, bar => 1, baz => 2}, 'nameHash');


    $DB->setBufferSize(1);

    $DB->execute(\'SET_Default' => q{
        INSERT INTO TripletaiL_DB_Test
               (foo, bar, baz)
        VALUES (?,   ?,   ?  )
    }, 'QQQQQ', 'WWWWW', 'EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE');

    $sth = $DB->execute(q{
        SELECT *
          FROM TripletaiL_DB_Test
    });
    ok($hash = $sth->fetchHash, 'fetchHash');
    is_deeply($hash, {foo => 'QQQ', bar => 'WWW', baz => 'EEE'}, 'content of fetchHash()');

    $sth = $DB->execute(q{
        SELECT *
          FROM TripletaiL_DB_Test
    });
    ok($hash = $sth->fetchArray, 'fetchArray');

    $sth = $DB->execute(q{
        SELECT *
          FROM TripletaiL_DB_Test
        WHERE foo = ?
    },'QQQQQ');
    dies_ok {$hash = $sth->fetchHash} 'fetchHash die';

    $sth = $DB->execute(q{
        SELECT *
          FROM TripletaiL_DB_Test
        WHERE foo = ?
    },'QQQQQ');
    dies_ok {$hash = $sth->fetchArray} 'fetchArray die';

	$sth->finish;

	$DB->execute(q{
        DROP TABLE TripletaiL_DB_Test
    });
}
