# -----------------------------------------------------------------------------
# Tripletail::RawCookie - 汎用的なクッキー管理を行う
# -----------------------------------------------------------------------------
package Tripletail::RawCookie;
use strict;
use warnings;
use Tripletail;

sub _POST_REQUEST_HOOK_PRIORITY() { -4_000_000 } # 順序は問わない

our $_INSTANCES = {}; # group => Tripletail::RawCookie

1;

sub _getInstance {
	my $class = shift;
	my $group = shift;

	if(!defined($group)) {
		$group = 'Cookie';
	}

	my $obj = $_INSTANCES->{$group};
	if($obj) {
		return $obj;
	}

	$obj = $_INSTANCES->{$group} = $class->__new($group);

	# postRequestフックに、保存されているインスタンスを削除する関数を
	# インストールする。そうしなければFCGIモードで過去のリクエストのクッキーが
	# いつまでも残る。
	$TL->setHook(
		'postRequest',
		_POST_REQUEST_HOOK_PRIORITY,
		sub {
			if(%$_INSTANCES) {
				%$_INSTANCES = ();
				#$TL->log('Tripletail::RawCookie' => 'Deleted cookie object made in this request.');
			}
		},
	);

	$obj;
}

sub get {
	my $this = shift;
	my $name = shift;

	if(!defined($name)) {
		die __PACKAGE__."#get, ARG[1] was undef.\n";
	} elsif(ref($name)) {
		die __PACKAGE__."#get, ARG[1] was Ref.\n";
	}

	if(my $data = $this->{set_cookies}{$name}) {
		# setまたはdeleteされている。
		return $data;
	}

	$this->__readEnvIfNeeded;

	$this->{got_cookies}{$name};
}

sub set {
	my $this = shift;
	my $name = shift;
	my $value = shift;

	if(!defined($name)) {
		die __PACKAGE__."#set, ARG[1] was undef.\n";
	} elsif(ref($name)) {
		die __PACKAGE__."#set, ARG[1] was Ref.\n";
	}

	if(ref($value)) {
		die __PACKAGE__."#set, ARG[2] was Ref.\n";
	}

	$this->{set_cookies}{$name} = $value;
	$this;
}

sub delete {
	my $this = shift;
	my $name = shift;

	if(!defined($name)) {
		die __PACKAGE__."#delete, ARG[1] was undef.\n";
	} elsif(ref($name)) {
		die __PACKAGE__."#delete, ARG[1] was Ref.\n";
	}

	$this->{set_cookies}{$name} = undef;
	$this;
}

sub clear {
	my $this = shift;

	$this->__readEnvIfNeeded;

	foreach my $key (keys %{$this->{got_cookies}},keys %{$this->{set_cookies}}) {
		$this->{set_cookies}{$key} = undef;
	}

	$this;
}

sub _makeSetCookies {
	# Set-Cookie:の値として使えるようにクッキーを文字列化するクラスメソッド。
	# 結果は配列で返される。
	my $class = shift;
	my @result;

	foreach my $this (values %$_INSTANCES) {
		push @result, $this->__makeSetCookie;
	}

	@result;
}

sub _isSecure {
	my $this = shift;
	$TL->INI->get($this->{group} => 'secure');
}

sub __new {
	my $class = shift;
	my $group = shift;
	my $this = bless {} => $class;

	$this->{group} = $group;
	$this->{read} = undef; # 環境変数からロードした後は真。
	$this->{got_cookies} = {}; # キー => 値 (飽くまでキャッシュ。{set_cookies}が優先される。)
	$this->{set_cookies} = {}; # キー => 値 (undefの値はクッキーの削除)

	$this;
}

sub __readEnvIfNeeded {
	# $ENV{HTTP_COOKIE}を読む。
	my $this = shift;

	if($this->{read}) {
		return $this;
	}

	if(my $cookie = $ENV{HTTP_COOKIE}) {
		$cookie =~ tr/\x0a\x0d//d;

		my $str;
		foreach my $pair (split /;/, $cookie) {
			$pair =~ s/ //g;

			my ($key, $value) = split /=/, $pair;
			$this->{got_cookies}{$key} = $value;
		}
	}

	$this->{read} = 1;
	$this;
}

sub __cookieTime {
	my $this = shift;
	my $epoch = shift;

	local $[ = 0;

	my @DoW = qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday);
	my @MoY = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

	my ($sec, $min, $hour, $mday, $mon, $year, $wday) = gmtime $epoch;
	$year += 1900;

	sprintf '%s, %02d-%s-%04d %02d:%02d:%02d GMT',
		$DoW[$wday], $mday, $MoY[$mon], $year, $hour, $min, $sec;
}

sub __makeSetCookie {
	my $this = shift;
	my @result;

	while(my ($key, $value) = each %{$this->{set_cookies}}) {
		my @parts;
		push @parts, sprintf('%s=%s', $key, defined $value ? $value : '');

		if(defined($value)) {
			if(defined(my $expires = $TL->INI->get($this->{group} => 'expires'))) {
				push @parts, "expires=".$this->__cookieTime(
					time + $TL->parsePeriod($expires));
			}
		} else {
			push @parts, "expires=".$this->__cookieTime(0);
		}

		if(defined(my $path = $TL->INI->get($this->{group} => 'path'))) {
			push @parts, "path=$path";
		}
		if(defined(my $domain = $TL->INI->get($this->{group} => 'domain'))) {
			push @parts, "domain=$domain";
		}
		if($TL->INI->get($this->{group} => 'secure')) {
			push @parts, 'secure';
		}
		if($TL->INI->get($this->{group} => 'httponly')) {
			push @parts, 'httponly';
		}

		my $line = join '; ', @parts;
		if(length($line) > 1024 * 4) {
			die __PACKAGE__."#_makeSetCookies, we have a too big cookie. [$line]";
		}

		push @result, $line;
	}

	@result;
}


__END__

=encoding utf-8

=head1 NAME

Tripletail::RawCookie - 汎用的なクッキー管理を行う

=head1 SYNOPSIS

  my $rawcookie = $TL->getRawCookie;

  my $val = $rawcookie->get('Cookie1');
  $rawcookie->set('Cookie2' => 'val2');

=head1 DESCRIPTION

生の文字列の状態でクッキーを取り出し、また格納する。
改行などのコントロールコードが含まれないように注意する必要性がある。 

クッキー有効期限、ドメイン、パス等は、 L<ini|Tripletail::Ini> ファイルで指定する。

=head2 METHODS

=over 4

=item C<< $TL->getRawCookie >>

  $TL->getRawCookie($inigroup)
  $TL->getRawCookie('Cookie')

Tripletail::RawCookie オブジェクトを取得。
引数には L<ini|Tripletail::Ini> で設定したグループ名を渡す。
引数省略時は 'Cookie' グループが使用される。

=item C<< get >>

  $str = $cookie->get($cookiename)

指定された名前のクッキーの内容を返す。

=item C<< set >>

  $cookie->set($cookiename => $str)

文字列を、指定された名前のクッキーとしてセットする。

=item C<< delete >>

  $cookie->delete($cookiename)

指定された名前のクッキーを削除する。

=item C<< clear >>

  $cookie->clear

全てのクッキーを削除する。

=back


=head2 Ini パラメータ

=over 4

=item path

  path = /cgi-bin

クッキーのパス。省略可能。
デフォルトは省略した場合と同様。

=item domain

  domain = example.org

クッキーのドメイン。省略可能。
デフォルトは省略した場合と同様。

=item expires

  expires = 30 days

クッキー有効期限。 L<度量衡|Tripletail/"度量衡"> 参照。省略可能。
省略時はブラウザが閉じられるまでとなる。

=item secure

  secure = 1

secureフラグの有無。省略可能。
1の場合、secureフラグを付ける。
0の場合、secureフラグを付けない。
デフォルトは0。

=item httponly

  httponly = 1

httponlyフラグの有無。省略可能。
1の場合、httponlyフラグを付ける。
0の場合、httponlyフラグを付けない。
デフォルトは0。
現状ではIEでしか意味が無い。

=back


=head1 SEE ALSO

=over 4

=item L<Tripletail>

=item L<Tripletail::Cookie>

生の文字列でなく L<Tripletail::Form> を扱うクッキークラス。

=item L<Tripletail::Form>

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
