# -----------------------------------------------------------------------------
# Tripletail::Filter::Redirect - リダイレクトヘッダ出力
# -----------------------------------------------------------------------------
package Tripletail::Filter::Redirect;
use strict;
use warnings;
use Tripletail;
require Tripletail::Filter;
require Tripletail::Filter::HTML;
our @ISA = qw(Tripletail::Filter);

# オプション一覧:
# * location => URL文字列。

1;

sub _new {
	my $class = shift;
	my $this = $class->SUPER::_new(@_);

	# リンク種別を決定する関数
	$this->{decide_link_func} = undef;

	# 保存するフォームオブジェクト
	$this->{save} = $TL->newForm->set(
		CCC => '愛',
	);

	# オプションのチェック
	my $check = {
		location    => [qw(defined no_empty scalar)],
	};
	$this->_check_options($check);

	$this->setDecideLink;
	$this;
}

sub getSaveForm {
	my $this = shift;
	$this->{save};
}

sub setDecideLink {
	my $this = shift;
	my $func = shift;

	if(defined($func)) {
		if(ref($func) eq 'CODE') {
			$this->{decide_link_func} = $func;
		} else {
			die __PACKAGE__."#setDecideLink, ARG[1] was not CODE Ref.\n";
		}
	} else {
		$this->{decide_link_func} = \&_default_decide_link;
	}

	$this;
}

sub print {
	my $this = shift;
	my $data = shift;

	if(ref($data)) {
		die __PACKAGE__."#print, ARG[1] was a Ref. [$data]\n";
	}

	return '' if($data eq '');

	die __PACKAGE__."#print, print called after location.\n";
}
  
sub _relink { goto &Tripletail::Filter::HTML::_relink; }
sub _default_decide_link { goto &Tripletail::Filter::HTML::_default_decide_link; }

sub _make_header {
	my $this = shift;

	if(defined(&Tripletail::Session::_getInstance)) {
		# Tripletail::Sessionが有効になっているので、データが有れば、それをクッキーに加える。
		foreach my $group (Tripletail::Session->_getInstanceGroups) {
			Tripletail::Session->_getInstance($group)->_setSessionDataToCookies;
		}
	}

	require Tripletail::RawCookie;
	require Tripletail::Cookie;

	my %opts;
	if(!$TL->getDebug->{location_debug}) {
		# relinkした上でLocationを生成。
		%opts = (Location => $this->_relink(url => $this->{option}{location}));
	}

	return {
		%opts,
		'Set-Cookie' => [
			Tripletail::Cookie->_makeSetCookies,
			Tripletail::RawCookie->_makeSetCookies,
		],
	};
}

sub flush {
	# デフォルトの実装。必要に応じてオーバーライドする。
	my $this = shift;

	$this->setHeader('Content-Type' => 'text/html');

	my $data = $this->_flush_header;

	if($TL->getDebug->{location_debug}) {
		my $link = $this->_relink(url => $this->{option}{location});
		$data .= q{<html><head><title>redirect</title></head><body><a href="}
			. $TL->escapeTag($link)
			. q{">}
			. $TL->escapeTag($link)
			. q{</a></body></html>};
	}

	$this->_reset;

	$data;
}

sub _reset {
	my $this = shift;
	$this->SUPER::_reset;

	$this->{save} = $TL->newForm->set(
		CCC => '愛',
	);

	$this;
}

__END__

=encoding utf-8

=head1 NAME

Tripletail::Filter::Redirect - リダイレクトヘッダ出力

=head1 SYNOPSIS

  $TL->setContentFilter(
      'Tripletail::Filter::Redirect',
      location => 'http://example.org/');

あるいは

  $TL->location('http://example.org/');

=head1 DESCRIPTION

以下の処理を行う。

=over 4

=item Locationヘッダの生成。

=item 特定フォームデータを指定された種別のリンク(リダイレクト先)に付与する。

=back

L<< $TL->location|Tripletail/"location" >> は、出力フィルタをこのクラスに
設定する為のユーティリティーメソッドである。


=head2 フィルタパラメータ

=over 4

=item location

リダイレクト先のURLを指定する。

=back


=head2 METHODS

=over 4

=item getSaveForm

  my $SAVE = $filter->getSaveForm;

出力フィルタが所持している、保存すべきデータが入った
L<Form|Tripletail::Form> オブジェクトを返す。

=item setDecideLink

  $filter->setDecideLink(\&func);

リンク種別を決定する関数を設定する。
値を渡さないとデフォルトの判別処理に戻す。

関数の戻り値が1であれば、同じTLライブラリで作成された環境へのリンクとして、リンクの書き換えを行う。
関数の戻り値が0であれば、リンクの書き換えは行わない。 

デフォルトの判別処理は以下の関数で行っている。

  sub defaultDecideLink {
    my (%param) = @_;

    if($param{'link'} =~ m/^https?/) {
      return 0;
    }
    elsif($param{'link'} =~ m/^javascript/i) {
      return 0;
    }
    elsif($param{'link'} =~ m/^(?:mailto|ftp):/) {
      return 0;
    }
    elsif(not length $param{'link'}) {
      return 0;
    }
    else {
      return 1;
    }
  }

=item setHeader

  $filter->setHeader($key => $value)

他の出力の前に実行する必要がある。
同じヘッダを既に出力しようとしていれば、そのヘッダの代わりに指定したヘッダを出力する。（上書きされる）

=item addHeader

  $filter->addHeader($key => $value)

他の出力の前に実行する必要がある。
同じヘッダを既に出力しようとしていれば、そのヘッダに加えて指定したヘッダを出力する。（追加される）

=item flush

L<Tripletail::Filter>参照

=item print

L<Tripletail::Filter>参照

=back


=head1 SEE ALSO

=over 4

=item L<Tripletail>

=item L<Tripletail::Filter>

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
