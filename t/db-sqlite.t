## ----------------------------------------------------------------------------
#  t/db-sqlite.t
# -----------------------------------------------------------------------------
# Mastering programmed by YAMASHINA Hio
#
# Copyright YMIRLINK, Inc.
# -----------------------------------------------------------------------------
# $Id: db-sqlite.t,v 1.4 2006/12/04 10:14:52 hio Exp $
# -----------------------------------------------------------------------------
use strict;
use warnings;
use Test::More;
use Test::Exception;
use t::make_ini {
	ini => {
		TL => {
		},
		DB => {
			type       => 'sqlite',
			defaultset => 'DBSET_test',
			DBSET_test => [qw(DBCONN_test)]
		},
		DBCONN_test => {
			dbname => 'test.sqlite',
		},
	},
	clean => [ 'test.sqlite' ],
};
use Tripletail $t::make_ini::INI_FILE;

my $has_DBD_SQLite = eval 'use DBD::SQLite;1';
if( !$has_DBD_SQLite )
{
	plan skip_all => "no DBD::SQLite";
}

# -----------------------------------------------------------------------------
# test spec.
# -----------------------------------------------------------------------------
plan tests => 1+3+23+15+15+4;

&test_setup; #1.
&test_getdb; #3.
&test_misc;  #23.
&test_transaction;  #15.
&test_transaction2; #15.
&test_locks;  #4.

# -----------------------------------------------------------------------------
# test setup.
# -----------------------------------------------------------------------------
sub test_setup
{
	lives_ok {
		$TL->trapError(
			-DB   => 'DB',
			-main => sub{},
		);
	} '[setup] connect ok';
}

# -----------------------------------------------------------------------------
# test getdb.
# -----------------------------------------------------------------------------
sub test_getdb
{
	dies_ok {
		$TL->getDB();
	} '[getdb] getDB without startCgi/trapError';
	
	$TL->trapError(
		-DB => 'DB',
		-main => sub{
			isa_ok($TL->getDB(), 'Tripletail::DB', '[getdb] getDB in trapError');
		},
	);
	
	$TL->startCgi(
		-DB => 'DB',
		-main => sub{
			isa_ok($TL->getDB(), 'Tripletail::DB', '[getdb] getDB in startCgi');
			$TL->setContentFilter("t::filter_null");
			$TL->print("test"); # avoid no contents error.
		},
	);
}

# -----------------------------------------------------------------------------
# test misc.
# -----------------------------------------------------------------------------
sub test_misc
{
	$TL->trapError(
		-DB => 'DB',
		-main => sub{
			my $DB = $TL->getDB();
			isa_ok($TL->getDB(), 'Tripletail::DB', '[misc] getDB');
			$DB->execute( q{
				CREATE TEMPORARY TABLE test
				(
					nval INTEGER NOT NULL PRIMARY KEY,
					sval TEXT    NOT NULL
				)
			});
			pass("[misc] create table");
			
			foreach my $sval (qw(apple orange cherry strowberry))
			{
				$DB->execute( q{
					INSERT
					  INTO test (sval)
					VALUES (?)
				}, $sval);
				pass("[misc] insert '$sval'.");
			}
			# check last_insert_id.
			{
				my $sth = $DB->execute( q{
					SELECT last_insert_rowid()
				});
				ok($sth, '[misc] select lastid');
				my $row1 = $sth->fetchArray();
				is_deeply($row1, [4], '[misc] record is [4]');
				my $row2 = $sth->fetchArray();
				is($row2, undef, '[misc] no second record');
				
				is($DB->getDbh()->func('last_insert_rowid'), 4, '[misc] lastid via dbh func');
				SKIP:{
					if( !$DB->getDbh()->can('last_insert_id') )
					{
						skip "[misc] no last_insert_id method", 1;
					}
					is($DB->getDbh()->last_insert_id(undef,undef,undef,undef), 4, '[misc] lastid via dbh last_insert_id');
				};
			}
			
			foreach my $vals ([20, 'plum'],[33, 'melon'],[57,'lychee'] )
			{
				my ($nval, $sval) = @$vals;
				$DB->execute( q{
					INSERT
						INTO test (nval, sval)
					VALUES (?, ?)
				}, $nval, $sval);
				pass("[misc] insert ($nval,'$sval').");
			}
			
			# check valus
			{
				my $sth = $DB->execute( q{
					SELECT nval, sval
					  FROM test
					 ORDER BY nval
				});
				ok($sth, '[misc] iterate all');
				foreach my $row (
					[  1, 'apple'      ],
					[  2, 'orange'     ],
					[  3, 'cherry'     ],
					[  4, 'strowberry' ],
					[ 20, 'plum' ],
					[ 33, 'melon' ],
					[ 57, 'lychee' ],
				)
				{
					my ($nval, $sval) = @$row;
					is_deeply($sth->fetchArray(), $row, "[misc] fetch ($nval, $sval)");
				}
				is($sth->fetchArray(), undef, "[misc] fetch undef (terminator)");
			}
		},
	);
}

# -----------------------------------------------------------------------------
# CREATE TABLE test_colors
# -----------------------------------------------------------------------------
sub _create_table_colors
{
	my $DB = shift;
	$DB->execute( q{
		CREATE TEMPORARY TABLE test_colors
		(
			nval INTEGER NOT NULL PRIMARY KEY,
			sval TEXT    NOT NULL
		)
	});
	foreach my $sval (qw(blue red yellow green aqua cyan))
	{
		$DB->execute( q{
			INSERT
			  INTO test_colors (sval)
			VALUES (?)
		}, $sval);
	}
}

# -----------------------------------------------------------------------------
# test transaction.
# -----------------------------------------------------------------------------
sub test_transaction
{
	$TL->trapError(
		-DB => 'DB',
		-main => sub{
			my $DB = $TL->getDB();
			
			# begin and commit.
			lives_ok { $DB->begin; }    "[tran] begin ok";
			lives_ok { $DB->commit; }   "[tran] commit ok";
			
			# begin and rollback.
			lives_ok { $DB->begin; }    "[tran] begin ok";
			lives_ok { $DB->rollback; } "[tran] rollback ok";
			
			# begin tran within transaction;
			lives_ok { $DB->begin; }    "[tran] begin ok";
			dies_ok  { $DB->begin; }    "[tran] begin in tran dies";
			lives_ok { $DB->rollback; } "[tran] rollback ok";
			
			# begin/rollback w/o transaction.
			dies_ok { $DB->commit; }   "[tran] commit w/o transaction dies";
			dies_ok { $DB->rollback; } "[tran] rollback w/o transaction dies";
			
			# create test data.
			_create_table_colors($DB);
			
			# check whether rollback works.
			is($DB->selectRowHash(q{SELECT COUNT(*) cnt FROM test_colors})->{cnt}, 6, "[tran] test table contains 6 records");
			lives_ok { $DB->begin; } "[tran] begin";
			lives_ok { $DB->execute("DELETE FROM test_colors"); } "[tran] delete all";
			is($DB->selectRowHash(q{SELECT COUNT(*) cnt FROM test_colors})->{cnt}, 0, "[tran] test table contains no records");
			lives_ok { $DB->rollback; } "[tran] rollback";
			is($DB->selectRowHash(q{SELECT COUNT(*) cnt FROM test_colors})->{cnt}, 6, "[tran] test table contains 6 records");
		},
	);
}

# -----------------------------------------------------------------------------
# test transaction (2).
# -----------------------------------------------------------------------------
sub test_transaction2
{
	$TL->trapError(
		-DB => 'DB',
		-main => sub{
			my $DB = $TL->getDB();
			
			# requireTx, requireNoTx.
			lives_ok {
				$DB->begin();
				$DB->requireTx();
				$DB->commit();
			} "[tran2] requireTx on transaction";
			throws_ok {
				$DB->requireTx();
			} qr/^Tripletail::DB#requireTx, transaction required at/, "[tran2] requireTx outside of tx";
			lives_ok {
				$DB->requireNoTx();
			} "[tran2] requireNoTx out of transaction";
			throws_ok {
				$DB->begin();
				$DB->requireNoTx();
			} qr/^Tripletail::DB#requireNoTx, no transaction required at/, "[tran2] requireNoTx on transaction";
			eval{ $DB->rollback(); };
			
			# tx.
			my $tx_works;
			$DB->tx(sub{
				$tx_works = 1;
			});
			ok($tx_works, "[tran2] tx works");
			
			lives_ok {$DB->tx(sub{
				$DB->requireTx();
			})} "[tran2] requireTx in tx";
			
			
			# create test data (blue red yellow green aqua cyan)
			_create_table_colors($DB);
			{
				my $s = $DB->selectAllHash("SELECT * FROM test_colors");
				is(@$s, 6, '[tran2] implicit commit, 6 records in tx');
				$DB->tx(sub{
					$DB->execute("DELETE FROM test_colors WHERE sval = ?", 'yellow');
					$s = $DB->selectAllHash("SELECT * FROM test_colors");
					is(@$s, 5, '[tran2] implicit commit, 5 records at end of tx');
				});
				$s = $DB->selectAllHash("SELECT * FROM test_colors");
				is(@$s, 5, '[tran2] implicit commit, 5 records after tx');
				
				$DB->tx(sub{
					$DB->execute("DELETE FROM test_colors WHERE sval = ?", 'red');
					$s = $DB->selectAllHash("SELECT * FROM test_colors");
					is(@$s, 4, '[tran2] explicit rollback, 4 records in tx');
					$DB->rollback;
				});
				$s = $DB->selectAllHash("SELECT * FROM test_colors");
				is(@$s, 5, '[tran2] explicit rollback, 5 records after tx (rollbacked)');
				
				$DB->tx(sub{
					$DB->execute("DELETE FROM test_colors WHERE sval = ?", 'red');
					$s = $DB->selectAllHash("SELECT * FROM test_colors");
					$DB->commit;
				});
				$s = $DB->selectAllHash("SELECT * FROM test_colors");
				is(@$s, 4, '[tran2] explicit commit');
				
				eval{ $DB->tx(sub{
					$DB->execute("DELETE FROM test_colors WHERE sval = ?", 'cyan');
					$s = $DB->selectAllHash("SELECT * FROM test_colors");
					is(@$s, 3, '[tran2] die implicits rollback, 3 records in tx');
					die "test\n";
				}) };
				is($@, "test\n", "[trans] die in tx");
				$s = $DB->selectAllHash("SELECT * FROM test_colors");
				is(@$s, 4, '[tran2] die implicits rollback, 4 records after tx');
			}
		},
	);
}

# -----------------------------------------------------------------------------
# test locks.
# -----------------------------------------------------------------------------
sub test_locks
{
	$TL->trapError(
		-DB => 'DB',
		-main => sub{
			my $DB = $TL->getDB();
			_create_table_colors($DB);
			
			lives_ok { $DB->execute(q{SELECT COUNT(*) FROM test_colors}) } "[locks] table test_colors exists";
			dies_ok { $DB->lock(read=>'test_colors') } "[locks] lock test_colors failed";
			
			throws_ok { $DB->lock } qr/Tripletail::DB#lock, no tables are being locked. Specify at least one table./, "[locks] lock no tables";
			throws_ok { $DB->unlock } qr/Tripletail::DB#unlock, no tables are locked/, "[locks] unlock w/o lock";
			
		},
	);
}

