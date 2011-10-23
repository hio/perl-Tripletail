# -----------------------------------------------------------------------------
# Tripletail::Filter::Binary - 内容に変更を加えない出力フィルタ
# -----------------------------------------------------------------------------
package Tripletail::Filter::Binary;
use strict;
use warnings;
use Tripletail;
require Tripletail::Filter;
our @ISA = qw(Tripletail::Filter);

# オプション一覧:
# * contenttype => デフォルト: application/octet-stream

1;

sub _new {
	my $pkg = shift;
	my $this = $pkg->SUPER::_new(@_);

	# デフォルト値を埋める
	my $defaults = [
		[contenttype => 'application/octet-stream'],
	];
	$this->_fill_option_defaults($defaults);

	# オプションのチェック
	my $check = {
		contenttype => [qw(defined no_empty scalar)],
	};
	$this->_check_options($check);

	$this->setHeader('Content-Type' => $this->{option}{contenttype});

	$this;
}

sub reset {
	my $this = shift;
	$this->SUPER::reset;

	$this->setHeader('Content-Type' => $this->{option}{contenttype});

	$this;
}


__END__

=encoding utf-8

=head1 NAME

Tripletail::Filter::Binary - 内容に変更を加えない出力フィルタ

=head1 SYNOPSIS

  $TL->setContentFilter('Tripletail::Filter::Binary', contenttype => 'image/png');
  
  $TL->print($TL->readFile('foo.png'));

=head1 DESCRIPTION

バイナリ等、受け取った内容をそのまま出力する。

=head2 フィルタパラメータ

=over 4

=item contenttype

Content-Typeを指定する。省略可能。

=back

=head2 METHODS

=over 4

=item setHeader

  $filter->setHeader($key => $value)

他の出力の前に実行する必要がある．同じヘッダを既に出力しようとしていれば，
そのヘッダの代わりに指定したヘッダを出力する．

=item addHeader

  $filter->addHeader($key => $value)

他の出力の前に実行する必要がある．同じヘッダを既に出力しようとしている場合，
そのヘッダに加えて指定したヘッダを出力する．

=item reset

L<Tripletail::Filter>参照

=back

=head1 SEE ALSO

=over 4

=item L<Tripletail>

=item L<Tripletail::Filter>

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
