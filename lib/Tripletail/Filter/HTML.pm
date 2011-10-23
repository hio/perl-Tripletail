# -----------------------------------------------------------------------------
# Tripletail::Filter::HTML - 通常HTML用出力フィルタ
# -----------------------------------------------------------------------------
package Tripletail::Filter::HTML;
use strict;
use warnings;
use Tripletail;
require Tripletail::Filter;
our @ISA = qw(Tripletail::Filter);

# Tripletail::Filter::HTMLは、
# * 文字コードの変換をする
# * フォームへ"CCC=愛"を追加する
# * 外部リンクの書換えを *しない*
# * セッションデータをリンク・フォームに追加 *しない*
# * Content-Dispositionを出力しない

# オプション一覧:
# * charset     => 出力の文字コード。(UTF-8から変換される)
#                  Encode.pmが利用可能なら利用する。(UniJP一部互換エンコード名、sjis絵文字使用不可)
#                  デフォルト: Shift_JIS
# * contenttype => デフォルト: text/html; charset=(CHARSET)
# * type        => 'html'または'xhtml'。デフォルト: html
#                  HTML書換え時の動作が変化する。

# 注意:
# * Tripletail::Filter::HTMLはバッファリングを行わない為、出力されるhtmlの
#    <meta>要素を見て文字コードを自動判別する事は出来ない。
# * ヘッダの出力は、最初にフィルタのprint()メソッドが使われた時、
#   すなわち最初に$TL->printが呼ばれた時に行われる。
#   出力すべきクッキーの設定/変更(セッション含む)は、
#   $TL->printを呼び出す前に行わなければならない。

1;

sub _new {
	my $class = shift;
	my $this = $class->SUPER::_new(@_);

	# Contentが1バイトでも出力されたかどうか
	$this->{content_printed} = undef;

	# 保存するフォームオブジェクト
	$this->{save} = $TL->newForm->set(
		CCC => '愛',
	);

	# デフォルト値を埋める。
	my $defaults = [
		[charset     => 'Shift_JIS'],
		[contenttype => sub {
			# 動的に決まるのでCODE Refを渡す。引数は取らない。
			require Tripletail::CharConv;
			sprintf 'text/html; charset=%s', $this->{option}{charset};
		}],
		[type        => 'html'],
	];
	$this->_fill_option_defaults($defaults);

	# オプションのチェック
	my $check = {
		charset     => [qw(defined no_empty scalar)],
		contenttype => [qw(defined no_empty scalar)],
		type        => [qw(no_empty scalar)],
	};
	$this->_check_options($check);

	if($this->{option}{type} ne 'html' && $this->{option}{type} ne 'xhtml') {
		die "TL#setContentFilter, option [type] for [Tripletail::Filter::HTML] ".
			"must be 'html' or 'xhtml' instead of [$this->{option}{type}].\n";
	}

	$this->setHeader('Content-Type' => $this->{option}{contenttype});

	$this->{buffer} = '';

	$this;
}

sub getSaveForm {
	my $this = shift;
	$this->{save};
}

sub print {
	my $this = shift;
	my $data = shift;
	my $output = $this->_flush_header;

	if(ref($data)) {
		die __PACKAGE__."#print, ARG[1] was a Ref. [$data]\n";
	}

	$data = $this->{buffer} . $data;
	$this->{buffer} = '';
	if($data =~ s/(<[^>]+)$//) {
		$this->{buffer} = $1;
	}

	$data = $this->_relink_html(html => $data);

	if(length($data)) {
		$this->{content_printed} = 1;
	}

	$output .= $TL->charconv($data, 'UTF-8' => $this->{option}{charset});

	$output;
}

sub flush {
	my $this = shift;

	my $data = $this->{buffer};
	$this->{buffer} = '';

	$data = $this->_relink_html(html => $data);

	if(length($data)) {
		$this->{content_printed} = 1;
	}

	my $output = $TL->charconv($data, 'UTF-8' => $this->{option}{charset});

	if(!$this->{content_printed}) {
		die __PACKAGE__."#flush, We printed no content during this request.\n";
	}

	$this->_reset;

	$output;
}

sub _make_header {
	my $this = shift;

	if(defined(&Tripletail::Session::_getInstance)){
		# Tripletail::Sessionが有効になっているので、データが有れば、それをクッキーに加える。
		foreach my $group (Tripletail::Session->_getInstanceGroups) {
			Tripletail::Session->_getInstance($group)->_setSessionDataToCookies;
		}
	}

	require Tripletail::RawCookie;
	require Tripletail::Cookie;

	return {
		'Set-Cookie' => [
			Tripletail::Cookie->_makeSetCookies,
			Tripletail::RawCookie->_makeSetCookies,
		],
	};
}

sub _relink_html {
	# $this->{save}の内容でhtmlを書換える。
	# 書換え内容:
	#   * form.action : 空ならREQUEST_URIにする。相対リンクならhiddenで$saveの内容を追加する。
	my $this = shift;
	my $opts = { @_ };
	my $html = $opts->{html}; # 書換えるHTML

	if(!defined($this->{save})) {
		# sanity check
		die __PACKAGE__."#_relink_form, internal error: \$this->{save} was undefined.\n";
	}

	# _relink用のキャッシュ(配列)
	my $relink_cache = [];

	my $is_xhtml = $this->{option}{type} eq 'xhtml' || 0;
	my @intr = qw(form a);
	$is_xhtml and push(@intr, qw(input br option));
	my $filter = $TL->newHtmlFilter(
		interest => \@intr,
	);

	$filter->set($html);

	while(my ($context, $elem) = $filter->next) {
		my $elem_name_lc = lc($elem->name);
		if($elem_name_lc eq 'form') {
			my $link_unescaped = do {
				my $action = $elem->attr('action');
				if (!defined($action) || !length($action)) {
					# actionが空。
					my $uri = $ENV{REQUEST_URI} || '';
                    
                    # ファイル名以外を消す
                    $uri =~ s/\?.*$//;
					$uri =~ s|.*/([^/]+)$|$1|; 

					#$TL->log(
					#	__PACKAGE__,
					#	sprintf(
					#		'Set action of form [%s] to [%s]',
					#		$elem->toStr, $TL->escapeTag($uri))
					#);

					# タグをエスケープして設定
					$elem->attr(action => $TL->escapeTag($uri));

					$uri;
				} else {
					# 空でない。
					$TL->unescapeTag($action);
				}
			};

			# このリンクが内部リンクなら$saveの内容を追加
			if(!$elem->attr('EXT')) {
				if( $is_xhtml )
				{
					$context->add($context->newElement('div'));
				}
				foreach my $key ($this->{save}->getKeys) {
					foreach my $value ($this->{save}->getValues($key)) {
						my $e = $context->newElement('input');
						$e->attr(type  => 'hidden');
						$e->attr(name  => $TL->escapeTag($key));
						$e->attr(value => $TL->escapeTag($value));

						if( $is_xhtml ) {
							$e->end('/');
						}

						#$TL->log(
						#	__PACKAGE__,
						#	sprintf(
						#		'Inserted hidden input in the form [%s]: [%s]',
						#		$elem->toStr, $e->toStr)
						#);

						$context->add($e);
					}
				}
				if( $is_xhtml )
				{
					$context->add($context->newElement('/div'));
				}
			} else {
				$elem->attr(EXT => undef);
			}
		} elsif($elem_name_lc eq 'a' && $elem->attr('href')) {
			# hrefがあるなら、リンクを書換える。

			my $newurl = $TL->escapeTag(
				$this->_relink(
					url   => $TL->unescapeTag($elem->attr('href')),
					cache => $relink_cache,
				)
			);

			if($newurl ne $elem->attr('href')) {
				#$TL->log(
				#	__PACKAGE__,
				#	sprintf('Relinked: [%s] => [%s]', $elem->attr('href'), $newurl)
				#);
			}

			$elem->attr(href => $newurl);
		} elsif($elem_name_lc =~ /^(input|br)$/ )
		{
			# ここに来るのは $is_xhtml の時だけ.
			my $end = $elem->end || '';
			if( $end =~ s/checked// && !$elem->attr('checked') )
			{
				$elem->attr('checked' => 'checked');
			}
			$elem->end('/');
		} elsif($elem_name_lc eq 'option' )
		{
			# ここに来るのは $is_xhtml の時だけ.
			my $end = $elem->end || '';
			if( $end =~ s/selected// && !$elem->attr('selected') )
			{
				$elem->attr('selected' => 'selected');
			}
			$elem->end($end =~ /\S/ ? $end : '');
		}
	}

	$filter->toStr;
}

sub _relink {
	my $this = shift;
	my $opts = { @_ };
	my $url = $opts->{url};
	my $cache = $opts->{cache} || [];

	if(!@$cache) {
		# キャッシュがまだ作られていない。
		# $cache->[0] : CCCが常に付いている$save文字列
		# $cache->[1] : $save内にascii文字しか入っていないならCCCが付かない$save文字列
		# どちらも先頭に'&'が付いている事に注意。
		@$cache = ('') x 2;

		my $onlyascii = 1;
		my $CCC;
		foreach my $key ($this->{save}->getKeys) {
			foreach my $value ($this->{save}->getValues($key)) {
				if($key ne 'CCC' && $value =~ m/[\x80-\xff]/) {
					$onlyascii = 0;
				}

				my $add .= sprintf '&%s=%s',
					$TL->encodeURL($TL->charconv($key, 'UTF-8' => $this->{option}{charset})),
					$TL->encodeURL($TL->charconv($value, 'UTF-8' => $this->{option}{charset}));
				$cache->[0] .= $add;

				if($key eq 'CCC') {
					$CCC = $add; # まだ追加しない。
				} else {
					$cache->[1] .= $add;
				}
			}
		}

		if(!$onlyascii) {
			$cache->[1] .= $CCC;
		}
	}

	my $fragment = ($url =~ s/(#.+)$// ? $1 : '');
	my $type = 0;
	if($url =~ m,INT=1,) {
		# 再度正確にチェックする
		my $int = $TL->newForm($url)->get('INT');
		if($int) {
			$type = 1;
		}
	}
	
	if($type == 1) {
		# 内部リンク
		# URLの文字コードを変換する
		
		my ($file, $delim, $param) = split(/(\?)/, $url);
		if($delim) {
			my @pairs;
			my $url2 = $file . $delim;
			foreach my $pair (split(/\&/, $param)) {
				my ($key, $value) = split(/\=/, $pair);
				next if($key eq 'INT');
				$key = $TL->encodeURL($TL->charconv($TL->decodeURL($key), 'UTF-8' => $this->{option}{charset}));
				$value = $TL->encodeURL($TL->charconv($TL->decodeURL($value), 'UTF-8' => $this->{option}{charset}));
				$url2 .= $key . '=' . $value . '&';
			}
			chop $url2;
			$url = $url2;
		}
		my $onlyascii = ($url !~ m/[\x80-\xff]|\%[8-9a-fA-F][0-9a-fA-F]/ ? 1 : 0);
		
		if($url =~ m/\?/) {
			$url .= $cache->[$onlyascii];
		} else {
			# 元のURLにクエリが付いていないなら、ここで付ける。
			(my $add = $cache->[$onlyascii]) =~ s/\&//;
			$url .= '?' . $add;
		}
	} elsif($type == 0) {
		# 弄ってはならないリンク
	}

	$url . $fragment;
}

sub _reset {
	my $this = shift;
	$this->SUPER::_reset;

	$this->{content_printed} = undef;
	$this->{save} = $TL->newForm->set(
		CCC => '愛',
	);
	$this->setHeader('Content-Type' => $this->{option}{contenttype});

	$this->{buffer} = '';

	$this;
}

__END__

=encoding utf-8

=head1 NAME

Tripletail::Filter::HTML - 通常HTML用出力フィルタ

=head1 SYNOPSIS

  $TL->setContentFilter('Tripletail::Filter::HTML', charset => 'UTF-8');
  
  $TL->print($TL->readTextFile('foo.html'));

=head1 DESCRIPTION

HTMLに対して以下の処理を行う。

=over 4

=item *

漢字コード変換（デフォルトShift_JIS、Encode優先）

=item *

HTTPヘッダの管理

=item *

E<lt>form action=""E<gt> が空欄の場合、自分自身のCGI名を埋める

=item *

特定フォームデータを指定された種別のリンクに付与する

=item *

セッション利用時は、クッキーにセッション情報を保存する

=back

=head2 セッション

セッションを利用している場合、http領域用のセッション情報は C<"SID + セッショングループ名">、
https領域用のセッション情報は C<"SIDS + セッショングループ名"> という名称のクッキーに保存する。

=head2 フィルタパラメータ

=over 4

=item charset

  $TL->setContentFilter('Tripletail::Filter::HTML', charset => 'Shift_JIS');

出力文字コードを指定する。省略可能。

使用可能なコードは次の通り。
UTF-8，Shift_JIS，EUC-JP，ISO-2022-JP

デフォルトはShift_JIS。

=item contenttype

  $TL->setContentFilter('Tripletail::Filter::HTML', contenttype => 'text/html; charset=sjis');

Content-Typeを指定する。省略可能。

デフォルトはtext/html; charset=（charasetで指定された文字コード）。

=item type

  $TL->setContentFilter('Tripletail::Filter::HTML', type => 'xhtml');

'html' もしくは 'xhtml' を利用可能。省略可能。

フィルタがHTMLを書換える際の動作を調整する為のオプション。
XHTMLを出力する際に、このパラメータをhtmlのままにした場合、
不正なXHTMLが出力される事がある。

デフォルトは 'html'。

=back

=head2 METHODS

=over 4

=item getSaveForm

  my $SAVE = $TL->getContentFilter->getSaveForm;

出力フィルタが所持している保存すべきデータが入った、
L<Form|Tripletail::Form> オブジェクトを返す。

=item setHeader

  $TL->getContentFilter->setHeader($key => $value)

他の出力の前に実行する必要がある。

同じヘッダを既に出力しようとしていれば、そのヘッダの代わりに指定したヘッダを出力する。（上書きされる）

=item addHeader

  $TL->getContentFilter->addHeader($key => $value)

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

=item L<Tripletail::Filter::MobileHTML>

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
