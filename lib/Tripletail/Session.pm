# -----------------------------------------------------------------------------
# Tripletail::Session - セッションの管理を行う
# -----------------------------------------------------------------------------
package Tripletail::Session;
use strict;
use warnings;
use Tripletail;

sub _POST_REQUEST_HOOK_PRIORITY() { -2_000_000 } # 順序は問わない

# このクラスは次のようなクッキーまたはクエリにデータを保存する。
# * HTTP側  : クッキー名 SID + グループ名 / クエリ名 SID + グループ名
# * HTTPS側 : クッキー名 SIDS + グループ名 / クエリ名 SIDS + グループ名

# -------------------------------------------------------
# セッションデータの入出力は次のようになる。
#
# [出力時]
#   [1: クッキーを使う場合]
#     Tripletail::FilterがSet-Cookie:ヘッダを出力する。
#     この時、iniパラメータ"cookie" / "securecookie"で指定されたグループ名のTripletail::Cookieが使われる。
#   [2: クエリを使う場合]
#     Tripletail::Filterが$SAVEに加える。
#
# [入力時]
#   [1: クッキーを使う場合]
#     Tripletail::InputFilterがdecodeCgi中に$TL->getCookieし、その中にセッションデータがあり、
#     且つTripletail::TinySessionが有効になっていれば、$TL->getTinySession->_setSessionDataする。
#   [2: クエリを使う場合]
#     Tripletail::InputFilterがdecodeCgi中にクエリ内にセッションデータを見付けた場合、
#     Tripletail::TinySessionが有効になっているなら、$TL->getTinySession->_setSessionDataする。

our %_instance;

1;

sub isHttps {
	$ENV{HTTPS} and $ENV{HTTPS} eq 'on';
}

sub get {
	my $this = shift;

	if(!defined($this->{sid})) {
		$this->_createSid;
	}

	$this->{sid};
}

sub renew {
	my $this = shift;

	$this->discard;
	$this->get;
}

sub discard {
	my $this = shift;

	if(defined($this->{sid})) {
		$this->__removeSid($this->{sid});
	}
	$this->__reset;

	$this;
}

sub setValue {
	my $this = shift;
	my $value = shift;

	if((!$this->isHttps) && ($this->{mode} eq 'double' || $this->{mode} eq 'https')) {
		die __PACKAGE__."#setValue, we can't modify session while we are using '$this->{mode}' mode and not in the https.\n";
	}

	if($this->{setvaluewithrenew}) {
		$this->discard;
		$this->{data} = $value;
		$this->get;
	} else {
		if(defined($this->{sid})) {
			$this->{data} = $value;
			$this->{updatetime} = 0; # アップデートを行わせる
			$this->__updateSession;
		} else {
			$this->{data} = $value;
			$this->get;
		}
	}

	$this;
}

sub getValue {
	my $this = shift;

	$this->{data};
}

sub getSessionInfo {
	my $this = shift;
	my $issecure = shift;

	if(!defined($issecure)) {
		$issecure = $this->isHttps
	}

	(($issecure ? 'SIDS' : 'SID') . $this->{group}, $this->{sid}, ($issecure ? $this->{checkvalssl} : $this->{checkval}));
}

sub _createSid {
	my $this = shift;

	$this->{checkval} = '_' x 19; # 64bit整数は 1844 6744 0737 0955 1615 まで
	$this->{checkval} =~ s/_/int(rand(10))/eg;
	$this->{checkvalssl} = '_' x 19; # 64bit整数は 1844 6744 0737 0955 1615 まで
	$this->{checkvalssl} =~ s/_/int(rand(10))/eg;

	$this->{sid} = $this->__createSid($this->{checkval}, $this->{checkvalssl}, $this->{data});
}

sub __createSid {
	my $this = shift;
	my $checkval = shift;
	my $checkvalssl = shift;
	my $data = shift;

	my $sid;

	my $DB = $TL->getDB($this->{dbgroup});

	my $type = $DB->getType;
	if($type eq 'mysql') {
		eval {
			$DB->execute(\$this->{dbset} => qq{
				REPLACE INTO $this->{sessiontable}
					VALUES (NULL, ?, ?, ?, now())
			}, $checkval, $checkvalssl, $data);
			$sid = $DB->getLastInsertId(\$this->{dbset});
		};
		if($@) {
			die __PACKAGE__."#__createSid, cannot create sid. [$@]\n";
		}
	}elsif($type eq 'sqlite') {
		eval {
			$DB->execute(\$this->{dbset} => qq{
				REPLACE INTO $this->{sessiontable}
					VALUES (NULL, ?, ?, ?, CURRENT_TIMESTAMP)
			}, $checkval, $checkvalssl, $data);
			$sid = $DB->getLastInsertId(\$this->{dbset});
		};
		if($@) {
			die __PACKAGE__."#__createSid, cannot create sid. [$@]\n";
		}
	} else {
		die __PACKAGE__."#__createSid, the type of DB [$this->{dbgroup}] is [$type], which is not supported.\n";
	}

	if($sid) {
		$TL->log(__PACKAGE__, "Created new session sid [$sid] on the DB [$this->{dbgroup}][$this->{sessiontable}].");
	} else {
		die __PACKAGE__."#__createSid, cannot create sid.\n";
	}

	$sid;
}

sub __removeSid {
	my $this = shift;
	my $sid = shift;

	my $DB = $TL->getDB($this->{dbgroup});

	my $type = $DB->getType;
	if($type eq 'mysql') {
		eval {
			$DB->execute(\$this->{dbset} => qq{
				DELETE FROM $this->{sessiontable}
					WHERE sid = ?
			}, $sid);
		};
	}elsif($type eq 'sqlite') {
		eval {
			$DB->execute(\$this->{dbset} => qq{
				UPDATE $this->{sessiontable}
				   SET checkval = 'x',
				       checkvalssl = 'x',
				       data = null,
				       updatetime = CURRENT_TIME
					WHERE sid = ?
			}, $sid);
		};
		$@ and die "mark as deleted failed: $@";
	} else {
		die __PACKAGE__."#__removeSid, the type of DB [$this->{dbgroup}] is [$type], which is not supported.\n";
	}

	$TL->log(__PACKAGE__, "Remove session sid [$sid] on the DB [$this->{dbgroup}][$this->{sessiontable}].");

	$sid;
}

sub __prepareSessionTable {
	my $this = shift;

	my $DB = $TL->getDB($this->{dbgroup});

	eval {
		$DB->execute(\$this->{readdbset} => qq{SELECT * FROM $this->{sessiontable} LIMIT 0});
	};
	if($@) {
		# テーブルが無いので作る。
		my $type = $DB->getType;
		if($type eq 'mysql') {
			my $typeoption = $TL->INI->get($this->{group} => 'mysqlsessiontabletype', '');
			$typeoption = " TYPE = " . $typeoption if($typeoption);
			eval {
				$DB->execute(\$this->{dbset} => qq{
					CREATE TABLE $this->{sessiontable} (
						sid           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
						checkval      BIGINT UNSIGNED NOT NULL,
						checkvalssl   BIGINT UNSIGNED NOT NULL,
						data          BIGINT UNSIGNED,
						updatetime    TIMESTAMP NOT NULL,
						PRIMARY KEY (sid),
						INDEX (updatetime)
					) AUTO_INCREMENT = 4294967296
					AVG_ROW_LENGTH = 20
					MAX_ROWS = 300000000
					$typeoption
				});
			};
			$@ and die "CREATE TABLE failed: $@";
		}elsif($type eq 'sqlite') {
			# sqlite3: 9223372036854775807. (64bit/signed)
			eval {
				$DB->execute(\$this->{dbset} => qq{
					CREATE TABLE $this->{sessiontable} (
						sid           INTEGER NOT NULL,
						checkval      BLOB NOT NULL,
						checkvalssl   BLOB NOT NULL,
						data          BLOB,
						updatetime    TIMESTAMP NOT NULL,
						PRIMARY KEY (sid),
						INDEX (updatetime)
					)
				});
			};
			$@ and die "CREATE TABLE failed: $@";
		} else {
			die __PACKAGE__."#__prepareSessionTable, the type of DB [$this->{dbgroup}] is [$type], which is not supported.\n";
		}

		$TL->log(__PACKAGE__, "Created table [$this->{sessiontable}] on the DB [$this->{dbgroup}].");
	}

	$this;
}

sub _init {
	# TL#startCgiによって呼ばれるクラスメソッド。
	my $class = shift;
	my $groups;
	if(ref($_[0]) eq 'ARRAY') {
		$groups = shift;
	} elsif(!ref($_[0])) {
		$groups = [ @_ ];
	} else {
		my $ref = ref($_[0]);
		die "Tripletail::Session#_init, ARG[1]: group name is Wrong-Ref. [$ref]\n";
	}

	# postRequest時に古いデータを消す。
	$TL->setHook(
		'postRequest',
		_POST_REQUEST_HOOK_PRIORITY,
		sub {
			foreach my $group (@$groups) {
				$_instance{$group}->__reset;
			}
		},
	);
	foreach my $group (@$groups) {
		$_instance{$group} = Tripletail::Session->__new($group);
	}

	undef;
}

sub __new {
	my $class = shift;
	my $group = shift;
	my $this = bless {} => $class;

	$this->{group} = defined $group ? $group : 'Session';

	$this->{mode} = $TL->INI->get($this->{group} => 'mode', 'double');

	my $timeout = $TL->INI->get($this->{group} => 'timeout','30min');
	$this->{timeout_period} = $TL->parsePeriod($timeout);

	my $updateinterval = $TL->INI->get($this->{group} => 'updateinterval','10min');
	$this->{updateinterval_period} = $TL->parsePeriod($updateinterval);

	$this->{setvaluewithrenew} = $TL->INI->get($this->{group} => 'setvaluewithrenew', 1);

	$this->__reset;

	# モードチェック
	if($this->{mode} eq 'https') {
		if(!$this->isHttps) {
			die __PACKAGE__."#__new, the 'https' mode of Session can't be used while we are not in the https.\n";
		}
	} elsif($this->{mode} eq 'http') {
		# 常に利用可能
	} elsif($this->{mode} eq 'double') {
		# 常に利用可能
	} else {
		die __PACKAGE__."#__new, invalid mode: [$this->{mode}]\n";
	}

	$this->{dbgroup} = $TL->INI->get($this->{group} => 'dbgroup');
	$this->{dbgroup} or die __PACKAGE__."#new, dbgroup is not set.\n";
	$this->{dbset} = $TL->INI->get($this->{group} => 'dbset');
	$this->{dbset} or die __PACKAGE__."#new, dbset is not set.\n";
	$this->{readdbset} = $TL->INI->get($this->{group} => 'readdbset', $this->{dbset});
	$this->{sessiontable} = $TL->INI->get($this->{group} => 'sessiontable', 'tl_session_' . $this->{group});

	$this->__prepareSessionTable;

	$this;
}

sub __reset {
	my $this = shift;

	$this->{sid} = undef;
	$this->{data} = undef;
	$this->{checkval} = undef;
	$this->{checkvalssl} = undef;
	$this->{updatetime} = undef; # 新規セッションを作成した場合はundefのまま
}


sub _getInstance {
	# TL#getSessionやTripletail::Filterによって呼ばれるクラスメソッド。
	my $class = shift;
	my $group = shift;

	defined $group or $group = 'Session';

	if($_instance{$group}) {
		$_instance{$group};
	} else {
		die "TL#getSession, the Session of $group group is not in use. ".
			"Specify [-Session => '(group)'] at the call of TL#startCgi if you want to use this.\n";
	}
}

sub _getInstanceGroups {
	# Tripletail::Filterなどによって呼ばれるクラスメソッド。
	my $class = shift;

	return keys %_instance;
}

sub _getRawCookie {
	my $this = shift;
	my $opts = { @_ };		# secure => 1 or 0

	my $group;
	if($opts->{secure}) {
		$group = $TL->INI->get($this->{group} => 'securecookie', 'SecureCookie');
	} else {
		$group = $TL->INI->get($this->{group} => 'cookie', 'Cookie');
	}

	my $cookie = $TL->getRawCookie($group);
	if($opts->{secure} && !$cookie->_isSecure) {
		die __PACKAGE__."#_getRawCookie, cookie group [$group] is not secure.".
			" We can't use it for secure part of session.\n";
	} elsif(!$opts->{secure} and $cookie->_isSecure) {
		die __PACKAGE__."#_getRawCookie, cookie group [$group] is secure.".
		" We can't use it for insecure part of session.\n";
	}
	$cookie;
}

sub _setSessionDataToCookies {
	# クッキーを使用する場合に，Tripletail::Filter より呼び出される．
	# 必要に応じてセッションデータをCookieにsetする。
	my $this = shift;

	if($this->isHttps) {
		if($this->{mode} eq 'https' || $this->{mode} eq 'double') {
			# https側
			my $cookie = $this->_getRawCookie(secure => 1);

			if(defined($this->{sid})) {
				$this->__updateSession(secure => 1);
				my $s = join('.', $this->{sid}, $this->{checkvalssl});
				$cookie->set('SIDS' . $this->{group} => $s);
			} else {
				$cookie->delete('SIDS' . $this->{group});
			}
		}
		if($this->{mode} eq 'http' || $this->{mode} eq 'double') {
			my $cookie = $this->_getRawCookie(secure => 0);
			if(defined($this->{sid})) {
				my $s = join('.', $this->{sid}, $this->{checkval});
				$cookie->set('SID' . $this->{group} => $s);
			} else {
				$cookie->delete('SID' . $this->{group});
			}
		}
	} else {
		if($this->{mode} eq 'http' || $this->{mode} eq 'double') {
			# http側
			my $cookie = $this->_getRawCookie(secure => 0);

			if(defined($this->{sid})) {
				$this->__updateSession(secure => 0);
				my $s = join('.', $this->{sid}, $this->{checkval});
				$cookie->set('SID' . $this->{group} => $s);
			} else {
				$cookie->delete('SID' . $this->{group});
			}
		} else {
			die __PACKAGE__."#_setSessionDataToCookies, session mode is https.".
				" We can't use it for insecure part of session.\n";
		}
	}

	$this;
}

sub _getSessionDataFromCookies {
	# クッキーを使用する場合に，Tripletail::InputFilter より呼び出される．
	# クッキー中にセッションデータがあれば、それを読む。
	my $this = shift;

	if ($this->{mode} eq 'http' || ((!$this->isHttps) && $this->{mode} eq 'double')) {
		my $cookie = $this->_getRawCookie(secure => 0);

		if(my $s = $cookie->get('SID' . $this->{group})) {
			# http側
			my ($sid, $checkval) = split(/\./, $s);
			$this->__setSession($sid, $checkval, secure => 0);
		}
	}

	if($this->{mode} eq 'https' || ($this->isHttps and $this->{mode} eq 'double')) {
		my $cookie = $this->_getRawCookie(secure => 1);

		if(my $s = $cookie->get('SIDS' . $this->{group})) {
			# https側
			my ($sid, $checkval) = split(/\./, $s);
			$this->__setSession($sid, $checkval, secure => 1);
		}
	}

	$this;
}

sub _setSessionDataToForm {
	# フォームを使用する場合に，Tripletail::Filter より呼び出される．
	# 必要に応じてセッションデータをFormにsetする。
	my $this = shift;
	my $form = shift;

	if($this->isHttps) {
		if(defined($this->{sid})) {
			$this->__updateSession(secure => 1);
			my $s = join('.', $this->{sid}, $this->{checkvalssl});
			$form->set('SIDS' . $this->{group} => $s);
		}
	} else {
		if(defined($this->{sid})) {
			$this->__updateSession(secure => 0);
			my $s = join('.', $this->{sid}, $this->{checkval});
			$form->set('SID' . $this->{group} => $s);
		}
	}

	$this;
}

sub _getSessionDataFromForm {
	# フォームを使用する場合に，Tripletail::InputFilter より呼び出される．
	# フォーム中にセッションデータがあれば、それを読む。
	my $this = shift;
	my $form = shift;

	if($this->{mode} eq 'http' || ((!$this->isHttps) && $this->{mode} eq 'double')) {
		if(my $s = $form->get('SID' . $this->{group})) {
			# http側
			my ($sid, $checkval) = split(/\./, $s);
			$this->__setSession($sid, $checkval, secure => 0);
		}
	}

	if($this->{mode} eq 'https' || ($this->isHttps && $this->{mode} eq 'double')) {
		if(my $s = $form->get('SIDS' . $this->{group})) {
			# https側
			my ($sid, $checkval) = split(/\./, $s);
			$this->__setSession($sid, $checkval, secure => 1);
		}
	}

	$this;
}

sub __setSession {
	# セッションの存在確認をし，問題がなければデータをセットする．
	my $this = shift;
	my $sid = shift;
	my $checkval = shift;
	my %opts = @_;

	my $DB = $TL->getDB($this->{dbgroup});
	my $colname = ($opts{secure} ? 'checkvalssl' : 'checkval');

	my $type = $DB->getType;
	if($type eq 'mysql') {
		eval {
			my $sessiondata = $DB->selectAllArray(\$this->{readdbset} => qq{
				SELECT data, UNIX_TIMESTAMP(updatetime), checkval, checkvalssl
					FROM $this->{sessiontable}
					WHERE sid = ? AND $colname = ?
			}, $sid, $checkval);

			if(!scalar(@$sessiondata)) {
				$TL->log(__PACKAGE__, "Invalid session. session is not found. sid [$sid] checkval [$checkval] on the DB [$this->{dbgroup}][$this->{sessiontable}].");
			}elsif( $sessiondata->[0][2] eq 'x' || $sessiondata->[0][3] eq 'x' ) {
				$TL->log(__PACKAGE__, "Invalid session. session has deletion mark. sid [$sid] checkval [$$sessiondata->[0][2]] checkvalssl [$$sessiondata->[0][3]] on the DB [$this->{dbgroup}][$this->{sessiontable}].");
			} elsif(time - $sessiondata->[0][1] > $this->{timeout_period}) {
				$TL->log(__PACKAGE__, "Invalid session. session is timeout. sid [$sid] checkval [$checkval] updatetime [$sessiondata->[0][1]] on the DB [$this->{dbgroup}][$this->{sessiontable}].");
			} else {
				$this->{sid} = $sid;
				$this->{data} = $sessiondata->[0][0];
				$this->{updatetime} = $sessiondata->[0][1];
				$this->{checkval} = $sessiondata->[0][2];
				$this->{checkvalssl} = $sessiondata->[0][3];
			}
		};
	}elsif($type eq 'sqlite') {
		eval {
			my $sessiondata = $DB->selectAllArray(\$this->{readdbset} => qq{
				SELECT data, datetime(updatetime, 'localtime'), checkval, checkvalssl
					FROM $this->{sessiontable}
					WHERE sid = ? AND $colname = ?
			}, $sid, $checkval);

			my $updatetime = $sessiondata && @$sessiondata && $TL->newDateTime($sessiondata->[0][1])->getEpoch();
			my $now = time;
			if(!scalar(@$sessiondata)) {
				$TL->log(__PACKAGE__, "Invalid session. session is not found. sid [$sid] checkval [$checkval] on the DB [$this->{dbgroup}][$this->{sessiontable}].");
			} elsif($now - $updatetime > $this->{timeout_period}) {
				$TL->log(__PACKAGE__, "Invalid session. session is timeout. sid [$sid] checkval [$checkval] updatetime [$sessiondata->[0][1]=$updatetime] on the DB [$this->{dbgroup}][$this->{sessiontable}], now=[$now], timeout=[$this->{timeout_period}].");
			} else {
				$this->{sid} = $sid;
				$this->{data} = $sessiondata->[0][0];
				$this->{updatetime} = $updatetime;
				$this->{checkval} = $sessiondata->[0][2];
				$this->{checkvalssl} = $sessiondata->[0][3];
			}
		};
	} else {
		die __PACKAGE__."#__setSession, the type of DB [$this->{dbgroup}] is [$type], which is not supported.\n";
	}

	if(defined $this->{sid}) {
		my $datalog = (defined($this->{data}) ? $this->{data} : '(undef)');
		$TL->log(__PACKAGE__, "Valid session data read. secure [$opts{secure}] sid [$this->{sid}] checkval [$this->{checkval}] checkvalssl [$this->{checkvalssl}] data [$datalog] updatetime [$this->{updatetime}] on the DB [$this->{dbgroup}][$this->{sessiontable}].");
	} else {
		$TL->log(__PACKAGE__, "Valid session data didn't read. secure [$opts{secure}] sid [$sid] $colname [$checkval] on the DB [$this->{dbgroup}][$this->{sessiontable}].");
	}

	$this;
}

sub __updateSession {
	my $this = shift;
	my %opts = @_;

	if(!defined($this->{updatetime})) {
		return $this;
	}

	if(time - $this->{updatetime} < $this->{updateinterval_period}) {
		return $this;
	}

	my $DB = $TL->getDB($this->{dbgroup});

	my $type = $DB->getType;
	if($type eq 'mysql') {
		eval {
			my $sessiondata = $DB->execute(\$this->{readdbset} => qq{
				UPDATE $this->{sessiontable}
					SET updatetime = now(), data = ?
					WHERE sid = ?
			}, $this->{data}, $this->{sid});
		};
	}elsif($type eq 'sqlite') {
		eval {
			my $sessiondata = $DB->execute(\$this->{readdbset} => qq{
				UPDATE $this->{sessiontable}
					SET updatetime = CURRENT_TIMESTAMP, data = ?
					WHERE sid = ?
			}, $this->{data}, $this->{sid});
		};
	} else {
		die __PACKAGE__."#__updateSession, the type of DB [$this->{dbgroup}] is [$type], which is not supported.\n";
	}

	$this->{updatetime} = time;

	my $datalog = (defined($this->{data}) ? $this->{data} : '(undef)');
	$TL->log(__PACKAGE__, "Update session. sid [$this->{sid}] data [$datalog] on the DB [$this->{dbgroup}][$this->{sessiontable}].");

	$this;
}


__END__

=encoding utf-8

=head1 NAME

Tripletail::Session - セッション

=head1 SYNOPSIS

=head2 PCブラウザ向け

  $TL->startCgi(
      -DB      => 'DB',
      -Session => 'Session',
      -main    => \&main,
  );

  sub main {
      my $session = $TL->getSession('Session');

      my $oldValue = $session->getValue;
      
      $session->setValue(12345);

      ...
  }

=head2 携帯ブラウザ向け

  $TL->setInputFilter('Tripletail::InputFilter::MobileHTML');
  $TL->startCgi(
      -DB      => 'DB',
      -Session => 'Session',
      -main    => \&main,
  );
  
  sub main {
      $TL->setContentFilter(
          'Tripletail::Filter::MobileHTML',
          charset => 'Shift_JIS',
      );
      my $session = $TL->getSession('Session');

      my $oldValue = $session->getValue;
      
      $session->setValue(12345);

      ...
  }

=head1 DESCRIPTION

64bit符号無し整数値の管理機能を持ったセッション管理クラス。

セッションは64bit符号無し整数以外のデータを取り扱えない為、その他のデータを管理したい場合は、
セッションキーを用い別途管理する必要がある。 

セッションキーは、 L<出力フィルタ|Tripletail/"出力フィルタ"> に L<Tripletail::Filter::HTML>
を使用している場合は L<クッキー|Tripletail::Cookie> に、 L<Tripletail::Filter::MobileHTML>
の場合は L<クエリ|Tripletail::Form> に、それぞれ挿入される。

また、 L<入力フィルタ|Tripletail/"入力フィルタ"> に L<Tripletail::InputFilter::HTML>
を使用している場合は L<クッキー|Tripletail::Cookie> から、L<Tripletail::InputFilter::MobileHTML>
の場合は L<クエリ|Tripletail::Form> から、それぞれ読み取られる。

出力フィルタに L<Tripletail::Filter::HTML> を利用した場合は、
入力フィルタに L<Tripletail::InputFilter::HTML> を使用する必要がある。

同様に、出力フィルタに L<Tripletail::Filter::MobileHTML> を利用した場合は、
入力フィルタに L<Tripletail::InputFilter::MobileHTML> を使用する必要がある。

出力フィルタに L<Tripletail::Filter::MobileHTML> を利用する場合は
フォームの利用の仕方に注意が必要であるため、
L<Tripletail::Filter::MobileHTML> ドキュメントに書かれている
利用方法を別途確認すること。

Sessionは L<DB|Tripletail::DB> を使用してセッションの管理を行う。

プログラム本体とDB接続を共有するため、以下の点に注意しなければならない。

=over 4

=item *

セッションの操作は、トランザクション中及びテーブルロック中には行わない。

=item *

コンテンツの出力操作は、トランザクション中及びテーブルロック中には行わない。

=back

=head2 METHODS

=over 4

=item C<< $TL->getSession >>

  $session = $TL->getSession($group)

Tripletail::Session オブジェクトを取得。
引数には L<ini|Tripletail::Ini> で設定したグループ名を渡す。省略可能。

このメソッドは、 L<Tripletail#startCgi|Tripletail/"startCgi">
の呼び出し時に C<< -Session => '(Iniグループ名)' >> で指定されたグループのセッションが有効化
されていなければ C<die> する。

引数省略時は 'Session' グループが使用される。

=item C<< isHttps >>

  $session->isHttps

現在のリクエストがhttpsなら1を、そうでなければundefを返す。

  if ($session->isHttps) {
      ...
  }

=item C<< get >>

  $sid = $session->get

ユニークなセッションキーを取得する。

セッションキーは64bit符号無し整数値となる。

Perlでは通常32bit整数値までしか扱えないため、セッションキーを数値として扱ってはならない。

セッションが存在しなければ、新規に発行する。

セッションの発行は常に行え、double モード時の非SSL側からの get メソッド呼び出しでもセッションは設定される。
ただし、SSL側からアクセスした際にセッションが無効になるため、その時にセッションIDは再作成される。

このメソッドの呼び出しは、コンテンツデータを返す前に行わなければならない。

=item C<< renew >>

  $sid = $session->renew

新しくユニークなセッションキーを発行し、取得する。

以前のセッションキーが存在した場合、そのセッションキーは無効となる。
また、以前のセッションに保存されていた値も破棄される。

このメソッドの呼び出しは、コンテンツデータを返す前に行わなければならない。

=item C<< discard >>

  $session->discard

現在のセッションキーを無効にする。

このメソッドの呼び出しは、コンテンツデータを返す前に行わなければならない。

=item C<< setValue >>

  $session->setValue($value)

セッションに値を設定する。

設定できる値は '64bit符号無し整数' のみ。
その他のデータを管理したい場合は、セッションキーを用いて別途実装する必要がある。

doubleモードの場合は、SSL起動時の場合に限り、両方のセッションに書き込まれる。
doubleモードで非SSL側からこのメソッドを使ってセッションを書換えようとした場合、
httpsモードで非SSL側から書き換えようとした場合は C<die> する。

このメソッドの呼び出しは、コンテンツデータを返す前に行わなければならない。

=item C<< getValue >>

  $value = $session->getValue

セッションから値を取得する。

セッションが存在しない場合は undef を返す。

=item C<< getSessionInfo >>

  ($name, $sid, $checkval) = $session->getSessionInfo

セッション情報を取得する。

クッキーやフォームにセッションを保存する際の名称、セッションキー、チェック値を返す。
チェック値は、現在のリクエストが https/http によって使用されているものが返される。
そのため、double モードの場合、現在のリクエスト状態に応じてチェック値が異なる。

セッションが存在しない場合は $sid、$checkval には undef が返る。

=back


=head2 古いセッションデータの削除

TripletaiL は、古いセッションデータを削除することはしません。

パフォーマンスを維持するため、古いセッションデータを定期的に削除するバッチを作成し、定期的に
実行するようにして下さい。

削除は以下のようなクエリで行えます。

 DELETE FROM tablename WHERE updatetime < now() - INTERVAL 7 DAY LIMIT 10000

セッションの保存期間にあわせて、WHERE条件を変更して下さい。

また、セッションテーブルがMyISAM形式の場合は、LIMIT句を付けて一度に削除する
レコード件数を制限し、長時間ロックがかからないようにすることを推奨します。

DELETE結果の件数が0件になるまで、ループして処理して下さい。

セッションテーブルがInnoDB形式の場合も、トランザクションが大きくなりすぎないよう、
LIMIT句を利用することを推奨します。

=head3 TripletaiL 0.29 以前のセッションテーブルの注意

TripletaiL 0.29 以前では、セッションテーブルを作成する際に、
updatetime カラムにインデックスを張っていませんでした。

レコードの件数が多い場合、古いデータの削除に時間がかかることがあります。
その場合は、updatetime カラムにインデックスを張るようにして下さい。

0.30以降では、セッションテーブル作成時にインデックスを張るように動作が変更されています。

 ALTER TABLE tablename ADD INDEX (updatetime);
 CREATE INDEX tablename_updtime_idx ON tablename (updatetime);


=head2 Ini パラメータ

=over 4

=item mode

  mode = double

設定可能な値は、'http'、 'https'、 'double'のいずれか。省略可能。

デフォルトはdouble。

=over 8

=item httpモード

SSLでの保護がないセッションを利用する。http/httpsの両方で使用できるが、セッションキーはhttp側から漏洩する可能性があるため、https領域からアクセスした場合も、十分な安全性は確保できないことに注意する必要がある。

=item httpsモード

SSLでの保護があるセッションを利用する。セッションキーはhttp側からの漏洩を防ぐため、http通信上には出力されない。https側でのみセッションへのアクセスが可能。

=item doubleモード

http側とhttps側で二重にセッションを張る。
https側からのみセッションへの書き込み・破棄が行え、その際にhttp側のセッション情報も同時に書き換えられる。
http側からはhttps側からセットされたセッション情報の参照のみが出来る。

http側はセッションキー漏洩の危険性があり、十分な安全性は確保できないが、https側は十分な安全性が確保できる。http側からセッションキーが漏洩した場合でも、https領域でのアクセスは安全である。

                http領域読込    http領域書込    https領域読込   http領域書込
  httpモード    ○              ○              ○              ○
  httpsモード   die             die             ○              ○
  doubleモード  ○              die             ○              ○

=back

=item cookie

  cookie = Cookie

http領域で使用するクッキーのグループ名を指定する。省略可能。

デフォルトは'Cookie'。

=item securecookie

https 領域で使用するクッキーのグループ名を指定する。省略可能。
secureフラグが付いていなければエラーとなる。

デフォルトは'SecureCookie'．

=item timeout

  timeout = 30 min

指定の時間経過したセッションは無効とする。L<度量衡|Tripletail/"度量衡"> 参照。省略可能。
最短で timeout - updateinterval の時間でタイムアウトする可能性がある。

デフォルトは30min。

=item updateinterval

  updateinterval = 10 min

最終更新時刻から指定時間以上経過していたら、DBの更新時刻を更新する。L<度量衡|Tripletail/"度量衡"> 参照。省略可能。
最短で timeout - updateinterval の時間でタイムアウトする可能性がある。

デフォルトは10min。

=item setvaluewithrenew

  setvaluewithrenew = 1

setValueした際に自動的にrenewを行うか否か。
0の場合、行わない。
1の場合、行う。

デフォルトは1。

=item dbgroup

  dbgroup = DB

使用するDBのグループ名。
L<ini|Tripletail::Ini> で設定したグループ名を渡す。
L<Tripletail#startCgi|Tripletail/"startCgi"> で有効化しなければならない。

=item dbset

  dbset = W_Trans

使用する書き込み用DBセット名。
L<Tripletail#startCgi|Tripletail/"startCgi"> で有効化しなければならない。
L<ini|Tripletail::Ini> で設定したグループ名を渡す。

=item readdbset

  readdbset = R_Trans

使用する読み込み用DBセット名。
L<Tripletail#startCgi|Tripletail/"startCgi"> で有効化しなければならない。
L<ini|Tripletail::Ini> で設定したグループ名を渡す。

省略された場合は dbset と同じものが使用される。

=item sessiontable

  sessiontable = tl_session

セッションで使用するテーブル名。
デフォルトは tl_session_グループ名 が使用される。

=item mysqlsessiontabletype

  mysqlsessiontabletype = InnoDB

MySQLの場合、セッションで使用するテーブルの種類を何にするかを指定する。
デフォルトは指定無し。

セッションの管理情報が重要である場合、例えばアフィリエイトの追跡に
利用していて、セッションが意図せず途切れるとユーザに金銭的被害が
生じるような場合は、InnoDB を利用することを推奨します。

それ以外の場合は、MyISAM を利用することを推奨します。
TripletaiL のセッションテーブルは Fixed 型となるため、
非常に高速にアクセスできます。

=item csrfkey

  csrfkey = JLapCbI4XW7G8oEi

addSessionCheck及びhaveSessionCheckで使用するキー。
サイト毎に値を変更する必要性がある。

=back


=head1 SEE ALSO

=over 4

=item L<Tripletail>

=item L<Tripletail::Cookie>

=item L<Tripletail::DB>

=item L<Tripletail::Filter::HTML>

=item L<Tripletail::Filter::MobileHTML>

=item L<Tripletail::InputFilter::HTML>

=item L<Tripletail::InputFilter::MobileHTML>

=back

=head1 AUTHOR INFORMATION

=over 4

Copyright 2006 YMIRLINK Inc. All Rights Reserved.

This framework is free software; you can redistribute it and/or modify it under the same terms as Perl itself

このフレームワークはフリーソフトウェアです。あなたは Perl と同じライセンスの 元で再配布及び変更を行うことが出来ます。

Address bug reports and comments to: tl@tripletail.jp

HP : http://tripletail.jp/

=back

=cut
