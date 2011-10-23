# -----------------------------------------------------------------------------
# Tripletail::Validator - 値の検証の一括処理
# -----------------------------------------------------------------------------
package Tripletail::Validator;
use strict;
use warnings;
use Tripletail;

use Tripletail::Validator::FilterFactory;

1;

#---------------------------------- 一般
sub _new {
	my $class = shift;
	return bless { _filters => {} }, $class;
}

sub addFilter {
	my $this    = shift;
	my $filters = shift;

	while ( my ( $key, $value ) = each %$filters ) {
		$this->{_filters}->{$key} = [];
		while ( $value =~ s/(\w+)(?:\((.*?)\))?(?:\[(.*?)\])?(?:;|$)// ) {
			my ( $filter, $args, $message ) = ( $1, $2, $3 );
			push(
				@{ $this->{_filters}->{$key} },
				{
					filter  => $filter,
					args    => $args,
					message => $message,
				}
			);
		}
		$TL->log(
			'Tripletail::Validator' => qq/addFilter { $key } : / . join(
				', ',
				map {
					    $_->{filter}
					  . ( defined( $_->{args} )    ? qq{($_->{args})}    : '' )
					  . ( defined( $_->{message} ) ? qq{[$_->{message}]} : '' )
				  } @{ $this->{_filters}->{$key} }
			)
		);
	}

	return $this;
}

sub check {
	my $this = shift;
	my $form = shift;
	my $error;

	foreach my $key ( keys %{ $this->{_filters} } ) {
		foreach my $filter ( @{ $this->{_filters}->{$key} } ) {
			my $e =
			  Tripletail::Validator::FilterFactory::getFilter(
				$filter->{filter} )
			  ->doFilter( [ $form->getValues($key) ], $filter->{args} );
			if (ref($e)) {
				$TL->log(
					'Tripletail::Validator' => qq/ok and skip { $key => ['@{[
						join(q{', '}, $form->getValues($key))
					]}'] } : $filter->{filter}@{[
						( defined( $filter->{args} )    ? qq{($filter->{args})}    : '' ) .
						( defined( $filter->{message} ) ? qq{[$filter->{message}]} : '' )
					]}/
				);
				last;
			} elsif ($e) {
				$TL->log(
					'Tripletail::Validator' => qq/error { $key => ['@{[
						join(q{', '}, $form->getValues($key))
					]}'] } : $filter->{filter}@{[
						( defined( $filter->{args} )    ? qq{($filter->{args})}    : '' ) .
						( defined( $filter->{message} ) ? qq{[$filter->{message}]} : '' )
					]}/
				);
				$error->{$key} =
				  defined( $filter->{message} )
				  ? $filter->{message}
				  : $filter->{filter};
				last;
			} else {
				$TL->log(
					'Tripletail::Validator' => qq/ok { $key => ['@{[
						join(q{', '}, $form->getValues($key))
					]}'] } : $filter->{filter}@{[
						( defined( $filter->{args} )    ? qq{($filter->{args})}    : '' ) .
						( defined( $filter->{message} ) ? qq{[$filter->{message}]} : '' )
					]}/
				);
			}
		}
	}

	return $error;
}

sub getKeys {
	my $this = shift;
	return keys %{ $this->{_filters} };
}

__END__

=encoding utf-8

=head1 NAME

Tripletail::Validator - 値の検証の一括処理

=head1 SYNOPSIS

  my $validator = $TL->newValidator;
  $validator->addFilter(
    {
      name  => 'NotBlank',
      email => 'Email',
      optionemail => 'Blank;Email',  # 入力しなくてもOKとする
      password => 'CharLen(4,8);Password',
    }
  );
  my $error = $validator->check($form);

=head1 DESCRIPTION

Formオブジェクト値の検証の一括処理を行う。

=head1 METHODS

=over 4

=item $TL->newValidator

  $validator = $TL->newValidator

Tripletail::Validator オブジェクトを作成。

=item addFilter

  $validator->addFilter(
    {
      name  => 'NotBlank',
      email => 'Email',
      optionemail => 'Empty;Email',  # 入力しなくてもOKとする
      password => 'CharLen(4,8);Password',
    }
  )

バリデータにフィルタを設定する。
検証対象となるフォームのキーに対し、フィルタリストを指定する。

フィルタ指定形式としては、

  FilterName(args)[message]

を、「;」区切りとする。
「(args)」や、「[message]」は省略可能。
「(args)」を省略した場合は、それぞれのフィルタによりデフォルトのチェックを行う。
「[message]」を省略した場合は、checkの戻り時にフィルタ名を返す。

=item check

  $error = $validator->check($form)

設定したフィルタを利用して、フォームの値を検証する。

それぞれのフォームのキーに対してエラーがあれば、「[message]」、もしくは指定がない場合はフィルタ名を値としたハッシュリファレンスを返す。
エラーがなければ、そのキーは含まれない。

=item getKeys

  @keys = $validator->getKeys

現在設定されているフィルタのキー一覧を返す。

=back

=head2 フィルタ一覧

=head3 組み込みフィルタ

=over 4

=item Empty

値が空（存在しないか0文字）であることをチェックし、そうであれば以降の判定を中止し、検証OKとする。

Email等の形式である必要があるが、入力が任意であるような項目のチェックに使用する。

=item NotEmpty

値が空（存在しないか0文字）でないことをチェックする。

値の形式を問わないが、入力必須としたい場合に使用する。

=item NotWhitespace

半角/全角スペース、タブのみでないことをチェックする。
値が空（存在しないか0文字）の場合は検証NGとなる。

=item Blank

値が空（存在しないか0文字）、半角/全角スペース、タブのみであることをチェックし、そうであれば以降の判定を中止し、検証OKとする。

Email等の形式である必要があるが、入力が任意であるような項目のチェックに使用する。空白のみなら入力無しとみなす。

=item NotBlank

値が空（存在しないか0文字）、半角/全角スペース、タブのみでないことをチェックする。

値の形式を問わないが、入力必須としたい場合に使用する。空白のみなら入力無しとみなす。

=item PrintableAscii

文字列が制御コードを除くASCII文字のみで構成されているかチェックする。
値が空（存在しないか0文字）なら検証NGとなる。

=item Wide

文字列が全角文字のみで構成されているかチェックする。
値が空（存在しないか0文字）なら検証NGとなる。

=item Password

文字列が半角の数字、アルファベット大文字、小文字、記号を 全て最低1ずつ含んでいるかチェックする。
値が空（存在しないか0文字）なら検証NGとなる。

=item ZipCode

7桁の郵便番号（XXX-XXXX形式）かチェックする。

実在する郵便番号かどうかは確認しない。

=item TelNumber

電話番号（/^\d[\d-]+\d$/）かチェックする。

数字で始まり、数字で終わり、その間が数字とハイフン(-)のみで構成されていれば電話番号とみなす。

=item Email

メールアドレスとして正しい形式かチェックする。

=item MobileEmail

メールアドレスとして正しい形式かチェックする。

但し携帯電話のメールアドレスでは、アカウント名の末尾にピリオドを含んでいる場合がある為、これも正しい形式であるとみなす。 

携帯電話キャリアのドメイン名を判別するわけではないため、通常のメールアドレスも正しい形式であるとみなす。

=item Integer($min,$max)

整数で、かつ$min以上$max以下かチェックする。指定値は省略可能。

デフォルトでは、最大最小のチェックは行わなず整数であれば正しい形式であるとみなす。

値が空（存在しないか0文字）なら検証NGとなる。

=item Real($min,$max)

整数もしくは小数で、かつ$min以上$max以下かチェックする。指定値は省略可能。 

デフォルトでは、最大最小のチェックは行わなず、整数もしくは小数であれば正しい形式であるとみなす。

値が空（存在しないか0文字）なら検証NGとなる。

=item Hira

平仮名だけが含まれているかチェックする。

値が空（存在しないか0文字）なら検証NGとなる。

=item Kata

片仮名だけが含まれているかチェックする。

値が空（存在しないか0文字）なら検証NGとなる。

=item ExistentDay

YYYY-MM-DDで設定された日付が実在するかチェックする。

=item Gif

=item Jpeg

=item Png

それぞれの形式の画像かチェックする。

画像として厳密に正しい形式であるかどうかは確認しない。

=item HttpUrl($mode)

"http://" で始まる文字列かチェックする。

$modeにs を指定した場合、"https://" で始まる文字列も正しい形式とみなす。

=item HttpsUrl

"https://" で始まる文字列かチェックする。

=item Len($min,$max)

バイト数の範囲が指定値以内かチェックする。 指定がない場合はチェックを行わない。

=item SjisLen($min,$max)

Shift-Jisでのバイト数の範囲が指定値以内かチェックする。指定がない場合はチェックを行わない。

=item CharLen($min,$max)

文字数の範囲が指定値以内かチェックする。 指定値がない場合はチェックを行わない。

=item Portable

機種依存文字以外を含んでいないかチェックする。

値が空（存在しないか0文字）なら検証OKとなる。

=item IpAddress

  IpAddress($checkmask)

$checkmaskに対して、設定されたIPアドレスが一致すれば1。そうでなければundef。
	
$checkmaskは空白で区切って複数個指定する事が可能。

例：'10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.1 fe80::/10 ::1'。

=item Enum($a,$b,$c)

値が指定値のいずれかであることをチェックする。指定値がない場合にはいずれにも該当しないとみなす。

=item Or($filter1|$filter2|$filter3)

指定のフィルタのいずれかに該当するかをチェックする。指定値がない場合にはいずれにも該当しないとみなす。

=item RegExp($regexp)

指定の正規表現に該当するかをチェックする。指定値がない場合には、エラー。

=back

=head3 ユーザー定義フィルタについて

組み込みフィルタに含まれないフィルタを、ユーザーで実装し、組み込むことができる。

=head4 フィルタの構築

Tripletail::Validator::Filterクラスを継承し、doFilterメソッドをオーバーライドする。

doFilterメソッドに渡される引数は、以下の通り。

=over 4

=item $this

フィルタオブジェクト自身

=item $values

チェック対象となる値の配列の参照。

=item $args

フィルタに与えられる引数。

=back

doFilterメソッドの戻り値をスカラで評価し、結果が真であれば検証OK、偽であれば検証NGと判断する。
検証OKであれば次のフィルタへ処理が移り、NGであればその項目の検証は終了する。

doFilterメソッドの戻り値がリファレンスであった場合は、検証OKとし、それ以降のフィルタの処理を行わず、その項目の検証を終了する。

=head4 フィルタの組み込み

IniパラメータのValidatorグループに、

  フィルタ名 = フィルタクラス名

として指定する。

=head4 例

チェック対象となる値の配列に、'Test'以外の文字列が含まれていればエラー。

=over 4

=item TestFilter.pm

  package TestFilter;
  use Tripletail;
  
  use base qw{Tripletail::Validator::Filter};
  
  sub doFilter {
    my $this   = shift;
    my $values = shift;
    my $args   = shift;
    
    return grep { $_ ne 'Test' } @$values > 0;
  }

=item Iniファイル

  [Validator]
  Test = TestFilter

=item 使い方

  $validator->addFilter(
    {
      test => 'Test',
    }
  )

=back

=head1 SEE ALSO

=over 4

=item L<Tripletail>

=item L<Tripletail::Value>

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
