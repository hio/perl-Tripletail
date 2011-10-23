# -----------------------------------------------------------------------------
# Tripletail::Filter::MobileHTML - 携帯電話向けHTML出力用フィルタ
# -----------------------------------------------------------------------------
package Tripletail::Filter::MobileHTML;
use strict;
use warnings;
use Tripletail;
require Unicode::Japanese;
require Tripletail::Filter::HTML;
our @ISA = qw(Tripletail::Filter::HTML);

# Tripletail::Filter::MobileHTMLは、
# * 文字コードの変換をする
# * フォームへ"CCC=愛"を追加する
# * 外部リンクの書換えを *する*
# * セッションデータをリンク・フォームに追加 *する*
# * Content-Dispositionを出力しない

# オプション一覧:
# * charset     => 出力の文字コード。(UTF-8から変換される)
#                  常にUniJPを用いて変換される。
#                  デフォルト: Shift_JIS
# * contenttype => デフォルト: text/html; charset=(CHARSET)

1;

sub _new {
	my $class = shift;
	my $this = $class->SUPER::_new(@_);

	$this;
}

sub print {
	my $this = shift;
	my $data = shift;

	if(ref($data)) {
		die __PACKAGE__."#print, ARG[1] was a Ref. [$data]\n";
	}

	if(!$this->{content_printed}) {
		if(defined(&Tripletail::Session::_getInstance)) {
			# Tripletail::Sessionが有効になっているので、データが有れば、それを$this->{save}に加える。
			foreach my $group (Tripletail::Session->_getInstanceGroups) {
				Tripletail::Session->_getInstance($group)->_setSessionDataToForm($this->{save});
			}
		}
	}

	$this->SUPER::print($data);
}


sub _make_header {
	# Tripletail::Filter::HTMLがクッキーを出力するのをやめさせる。
	return {};
}

__END__

=encoding utf-8

=head1 NAME

Tripletail::Filter::MobileHTML - 携帯電話向けHTML出力用フィルタ

=head1 SYNOPSIS

  $TL->setContentFilter('Tripletail::Filter::MobileHTML', charset => 'Shift_JIS');
  
  $TL->print($TL->readTextFile('foo.html'));

=head1 DESCRIPTION

HTMLに対して以下の処理を行う。

=over 4

=item *

漢字コード変換（デフォルトShift_JIS、常にUnicode::Japaneseを使う）

=item *

HTTPヘッダの管理

=item *

E<lt>form action=""E<gt> が空欄の場合、自分自身のCGI名を埋める

=item *

特定フォームデータを指定された種別のリンクに付与する

=back

L<Tripletail::Filter::HTML> との違いは以下の通り。

=over 4

=item *

文字コード変換にEncodeを使わず、常にUnicode::Japaneseを使用。

=item *

セッション用のデータを全てのリンクに追記し、クッキーでの出力はしない。

=back

=head2 セッション

携帯端末ではクッキーが利用できない場合があるため、セッション情報を
クッキーではなくフォームデータとして引き渡す必要がある。

TripletaiL では、L<Tripletail::Filter::MobileHTML> フィルタを使うことで
この作業を半自動化することができる。

L<Tripletail::Filter::MobileHTML> フィルタは、出力時にリンクやフォームを
チェックし、セッション情報を付与すべきリンク・フォームであれば、
自動的にパラメータを追加する。

セッション情報を付与すべきかどうかは、以下のように判断する。

=over 4

=item *

リンクの場合は、リンクの中に INT というキーが存在すれば、セッション情報を
付与し、INT キーを削除する。
INT キーがなければ、セッション情報は付与されない。

 <a href="tl.cgi?INT=1">セッション情報が付与されるリンク</a>
 <a href="tl.cgi">セッション情報が付与されないリンク</a>

INT キーは、Form クラスの toLink メソッドを利用すると自動的に付与される。
toExtLink メソッドを利用すると、INT キーは付与されない。

 <a href="<&LINKINT>">セッション情報が付与されるリンク</a>
 <a href="<&LINKEXT>">セッション情報が付与されないリンク</a>
 
 $template->expand({
   LINKINT => $TL->newForm({ KEY => 'data' })->toLink,
   LINKEXT => $TL->newForm({ KEY => 'data' })->toExtLink,
 });

=item *

フォームの場合は、基本的にセッション情報を付与する。

セッション情報を付与したくない場合は、フォームタグを以下のように記述する。

 <form action="" EXT="1">

C<EXT="1"> が付与されているフォームに関しては、セッション情報の付与を行わない。
また、C<EXT="1"> は出力時には削除される。

=back

セッション情報は、http領域用のセッション情報は C<"SID + セッショングループ名">、
https領域用のセッション情報は C<"SIDS + セッショングループ名"> という名称で保存する。

=head2 フィルタパラメータ

=over 4

=item charset

  $TL->setContentFilter('Tripletail::Filter::MobileHTML', charset => 'Shift_JIS');

出力文字コードを指定する。省略可能。

使用可能なコードは次の通り。
UTF-8，Shift_JIS，EUC-JP，ISO-2022-JP
	
デフォルトはShift_JIS。

=item contenttype

  $TL->setContentFilter('Tripletail::Filter::MobileHTML', contenttype => 'text/html; charset=sjis');

Content-Typeを指定する。省略可能。

デフォルトはtext/html; charset=（charasetで指定された文字コード）。

=item type

  $TL->setContentFilter('Tripletail::Filter::MobileHTML', type => 'xhtml');

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

=item setDecideLink

  $TL->getContentFilter->setDecideLink(\&func);

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

  $TL->getContentFilter->setHeader($key => $value)

他の出力の前に実行する必要がある。

同じヘッダを既に出力しようとしていれば、そのヘッダの代わりに指定したヘッダを出力する。（上書きされる）

=item addHeader

  $TL->getContentFilter->addHeader($key => $value)

他の出力の前に実行する必要がある。

同じヘッダを既に出力しようとしていれば、そのヘッダに加えて指定したヘッダを出力する。（追加される）

=item print

L<Tripletail::Filter>参照

=back

=head1 SEE ALSO

=over 4

=item L<Tripletail>

=item L<Tripletail::Filter>

=item L<Tripletail::Filter::HTML>

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
