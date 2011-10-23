## ----------------------------------------------------------------------------
#  t/db-sqlite.t
# -----------------------------------------------------------------------------
# Mastering programmed by YAMASHINA Hio
#
# Copyright YMIRLINK, Inc.
# -----------------------------------------------------------------------------
# $Id: db-sqlite.t,v 1.2 2006/11/07 05:18:42 hio Exp $
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
plan tests => 46;

&test_setup; #1.
&test_getdb; #3.
&test_misc;  #23.
&test_transaction;  #15.
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
			lives_ok { $DB->begin; } "[trans] begin";
			lives_ok { $DB->execute("DELETE FROM test_colors"); } "[trans] delete all";
			is($DB->selectRowHash(q{SELECT COUNT(*) cnt FROM test_colors})->{cnt}, 0, "[tran] test table contains no records");
			lives_ok { $DB->rollback; } "[trans] rollback";
			is($DB->selectRowHash(q{SELECT COUNT(*) cnt FROM test_colors})->{cnt}, 6, "[tran] test table contains 6 records");
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
			
			lives_ok { $DB->execute(q{SELECT COUNT(*) FROM test_colors}) } "table test_colors exists";
			dies_ok { $DB->lock(read=>'test_colors') } "lock test_colors failed";
			
			throws_ok { $DB->lock } qr/Tripletail::DB#lock, no tables are being locked. Specify at least one table./, "[lock] lock no tables";
			throws_ok { $DB->unlock } qr/Tripletail::DB#unlock, no tables are locked/, "[lock] unlock w/o lock";
			
		},
	);
}

