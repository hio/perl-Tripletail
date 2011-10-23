# -----------------------------------------------------------------------------
# Tripletail::InputFilter::MobileHTML - 携帯電話向けHTML用CGIクエリ読み取り
# -----------------------------------------------------------------------------
package Tripletail::InputFilter::MobileHTML;
use strict;
use warnings;
use Tripletail;
require Tripletail::InputFilter::HTML;
our @ISA = qw(Tripletail::InputFilter::HTML);

1;

sub _new {
	my $class = shift;
	my $this = $class->SUPER::_new(@_);

	$this;
}

sub decodeCgi {
	my $this = shift;
	my $form = shift;

	my $newform = $this->_formFromPairs(
	$this->__pairsFromCgiInput);

	$form->addForm($newform);

	if(defined(&Tripletail::Session::_getInstance)) {
		# ここで必要に応じてセッションをフォームから読み出す。
		foreach my $group (Tripletail::Session->_getInstanceGroups) {
			Tripletail::Session->_getInstance($group)->_getSessionDataFromForm($form);
		}
	}

	$this;
}

sub _getIncode {
	# CCCよりもUser-Agentからの情報を優先する。
	my $this = shift;
	my $pairs = shift;

	my $CCC;
	for(my $i = 0; $i < @$pairs; $i++) {
		if($pairs->[$i][0] eq 'CCC' && $pairs->[$i][1]) {
			$CCC = $pairs->[$i][1];

			splice @$pairs, $i, 1; # CCCをpairsから消す
			last;
		}
	}

	if(my $agent = $ENV{HTTP_USER_AGENT}) {
		if($agent =~ m/^DoCoMo/i) {
			return 'sjis-imode';
		} elsif($agent =~ m/^ASTEL/i) {
			return 'sjis-doti';
		} elsif($agent =~ m/^J-PHONE/i) {
			return 'sjis-jsky';
		}
	}

	if(defined $CCC) {
		$this->_getIncodeFromCCC($CCC);
	} else {
		'auto';
	}
}

sub _raw2utf8 {
	my $this = shift;
	my $str = shift;
	my $incode = shift;

	$TL->charconv($str, $incode => 'utf8', 1);
}


__END__

=encoding utf-8

=head1 NAME

Tripletail::InputFilter::MobileHTML - 携帯電話向けHTML用CGIクエリ読み取り

=head1 SYNOPSIS

  $TL->setInputFilter('Tripletail::InputFilter::MobileHTML');
  
  $TL->startCgi(
      -main => \&main,
  );
  
  sub main {
      if ($CGI->get('mode') eq 'Foo') {
          ...
      }
  }

=head1 DESCRIPTION

以下の点を除いて L<Tripletail::InputFilter::HTML> と同様。

=over 4

=item 文字コード判別

携帯電話の機種毎の絵文字の違いに対応する為に、C<< User-Agent >> を見て
機種を判別する。

=item 文字コード変換

Encodeは絵文字に対応していない為、文字コード変換には常に Unicode::Japanese
が用いられる。

=item L<セッション|Tripletail::Session>

セッションキーはクッキーでなくクエリから読み取る。

=back

=head2 METHODS

=over 4

=item decodeCgi

内部メソッド

=back

=head1 SEE ALSO

=over 4

=item L<Tripletail>

=item L<Tripletail::InputFilter>

=item L<Tripletail::InputFilter::HTML>

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
