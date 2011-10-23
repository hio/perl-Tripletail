# -----------------------------------------------------------------------------
# Tripletail::Filter::MemCached - MemCachedを使用するときに使用するフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Filter::MemCached;
use strict;
use warnings;
use Tripletail;
require Tripletail::Filter;
our @ISA = qw(Tripletail::Filter);

# このフィルタは必ず最後に呼び出されなければならない。
# オプション一覧:
# * key     => MemCachedから読み込む際のキー
# * mode     => MemCachedへの書き込み(write)か、MemCachedからの出力(read)か。
# * param    => 書き込み時に埋め込むデータ。Tripletail::Fromクラスの形で渡す。
# * charset     => 書き込み時に埋め込むデータを変換するための、出力の文字コード。(UTF-8から変換される)
#                  Encode.pmが利用可能なら利用する。(UniJP一部互換エンコード名、sjis絵文字使用不可)
#                  デフォルト: Shift_JIS


1;

sub _new {
	my $class = shift;
	my $this = $class->SUPER::_new(@_);

	# デフォルト値を埋める。
	my $defaults = [
		[charset => 'Shift_JIS'],
		[key     => undef],
		[mode    => 'in'],
		[param   => undef],
	];
	$this->_fill_option_defaults($defaults);

	# オプションのチェック
	my $check = {
		charset     => [qw(defined no_empty scalar)],
		key     => [qw(defined no_empty scalar)],
		mode     => [qw(defined no_empty scalar)],
		param     => [qw(no_empty)],
	};
	$this->_check_options($check);

	if($this->{option}{mode} ne 'write' && $this->{option}{mode} ne 'read') {
		die "TL#setContentFilter: option [mode] for [Tripletail::Filter::MemCache] ".
			"must be 'write' or 'read' instead of [$this->{option}{mode}].".
			" (modeはwriteかreadのいずれかを指定してください)\n";
	}

	$this->{buffer} = '';

	$this;
}

sub print {
	my $this = shift;
	my $data = shift;

	if(ref($data)) {
		die __PACKAGE__."#print: arg[1] is a Ref. [$data] (第1引数がリファレンスです)\n";
	}
	
	return '' if($data eq '');
	
	if($this->{option}{mode} eq 'write') {
		$this->{buffer} .= $data;
	} else {
		if($this->{buffer} eq '') {
			$this->{buffer} = $data;
		} else {
			die __PACKAGE__."#print: already output. (既に何らかの出力がされています)\n";
		}
	}
	
	'';
}

sub flush {
	my $this = shift;

	my $output;
	if($this->{option}{mode} eq 'write') {
		my $nowtime = time;
		$output = q{Last-Modified: } . $TL->newDateTime->setEpoch($nowtime)->toStr('rfc822') . qq{\r\n} . $this->{buffer};
		my $value = $nowtime . q{,} . $output;
		$TL->newMemCached->set($this->{option}{key},$value);
		if(defined($this->{option}{param})) {
			foreach my $key2 ($this->{option}{param}->getKeys){
				my $val = $TL->charconv($this->{option}{param}->get($key2), 'UTF-8' => $this->{option}{charset});
				$output =~ s/$key2/$val/g;
			}
		}
	} else {
		$output = $this->{buffer};
	}

	$this->_reset;
	
	$output;
}

sub _reset {
	my $this = shift;
	$this->SUPER::_reset;
	
	$this->{buffer} = '';
	
	$this;
}



__END__

=encoding utf-8

=head1 NAME

Tripletail::Filter::MemCached - MemCachedを使用するときに使用するフィルタ

=head1 SYNOPSIS

  $TL->setContentFilter('Tripletail::Filter::MemCached',key => 'key', mode => 'read', param => $param,  charset => 'Shift_JIS');

=head1 DESCRIPTION

MemCachedの使用を支援する。
このフィルタを使用する場合、最後に使用しなければならない。

=head2 METHODS

=over 4

=item flush

L<Tripletail::Filter>参照

=item print

L<Tripletail::Filter>参照

=back

=head2 フィルタパラメータ

=over 4

=item key

MemCachedで使用するkeyを設定する。

=item mode

MemCachedへの書き込みか、MemCachedからの読み込みかを選択する。

writeで書き込み、readで読み込み。省略可能。

デフォルトはwrite。

=item param

inで書き込みをする際に、出力文字列中に最後に埋め込みを行う情報をL<Tripletail::Form> クラスのインスタンスで指定する。
L<Tripletail::Form>クラスのキーが出力文字列中に存在している場合、値に置換する。省略可能。

=item charset

paramの値をUTF-8から変換する際の文字コードを指定する。省略可能。

使用可能なコードは次の通り。
UTF-8，Shift_JIS，EUC-JP，ISO-2022-JP

デフォルトはShift_JIS。

=back

=head1 SEE ALSO

=over 4

=item L<Tripletail>

=item L<Tripletail::Filter>

=item L<Tripletail::MemCached>

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
