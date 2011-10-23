# -----------------------------------------------------------------------------
# Tripletail::Mail - メール作成/読み込み
# -----------------------------------------------------------------------------
package Tripletail::Mail;
use strict;
use warnings;
use MIME::Entity;
use MIME::Body;
use MIME::Head;
use MIME::Decoder;
use MIME::QuotedPrint;
use MIME::Base64;
use MIME::Words qw (:all);

our $MAIL_ID_COUNT = 0;
our $BOUNDARY_COUNT = 0;
our $HOSTNAME;

1;

sub _new {
	my $pkg = shift;
	my $this = bless {} => $pkg;

	$this->{entity} = MIME::Entity->new;

	$this;
}

sub parse {
	my $this = shift;
	my $str = shift;

	require MIME::Parser;

	my $parser = MIME::Parser->new;
	$parser->output_to_core(1);
	$parser->tmp_to_core(1);

	$this->{entity} = $parser->parse_data($str);

	$this;
}

sub set {
	my $this = shift;
	my $str = shift;

	# MIME::Parserを使いたい所だが、ヘッダ部が未エンコードなので使えない。
	$this->{entity} = MIME::Entity->new;

	my $parse;
	$parse = sub {
		my $ent = shift;
		my $str = shift;

		my $in_header = 1;
		my $headkey;
		my $headline;
		my $flush = sub {
			return if not defined $headkey;
			$ent->head->add(
				$headkey => $this->_encodeHeader($headline, length($headkey))
			);
			$headkey = undef;
			$headline = undef;
		};
		my $body = '';

		foreach my $line (split /\r?\n|\r/, $str) {
			if($in_header) {
				if(!length($line)) {
					$flush->();

					$in_header = undef;
					next;
				} elsif($line =~ m/^([^:]+):\s?(.*)/) {
					my ($key, $value) = ($1, $2);
					$flush->();

					$headkey = $key;
					$headline = $value;
				} else {
					$line =~ s/^[ \t]+//;
					$headline .= " " . $line;
				}
			} else {
				$body .= $line . "\r\n";
			}
		}

		if($in_header) {
			$flush->();
		}

		my $set_body = sub {
			my $bodystr = shift;

			$bodystr =~ s/\r?\n|\r/\r\n/g;

			my $encoding = $ent->head->mime_attr('Content-Transfer-Encoding');
			if($encoding) {
				my $instr = $bodystr;
				my $in = IO::Scalar->new(\$instr);
				my $outstr;
				my $out = IO::Scalar->new(\$outstr);

				my $decoder = MIME::Decoder->new($encoding);
				$decoder->decode($in, $out);

				if($encoding =~ m/^\d+bit$/) {
					$bodystr = Unicode::Japanese->new($bodystr)->jis;
				} else {
					$bodystr = $outstr;
				}
			} else {
				$bodystr = Unicode::Japanese->new($bodystr)->jis;
			}

			my $obj = MIME::Body::Scalar->new;
			$ent->bodyhandle($obj);

			my $io = $obj->open('w');
			$io->print($bodystr);
			$io->close;
		};

			if(my $boundary = $ent->head->mime_attr('Content-Type.boundary')) {
			# バウンダリがあるので、body部分をパースする。

			my $first = 1;
			while(1) {
				if($body =~ s/^(.+?)\Q--$boundary\E(--)?\r?\n//s) {
					my $last = $2;

					if($first) {
						$set_body->($1);
						$first = undef;
					} else {
						my $part = MIME::Entity->new;
						$parse->($part, $1);
						$ent->add_part($part);
					}

					$last and last;
				} else {
					die __PACKAGE__."#set, invalid multipart: we found no boundaries [$boundary]\n";
				}
			}
		} else {
			$set_body->($body);
		}
	};

	$parse->($this->{entity}, $str);
	$this;
}

sub get {
	my $this = shift;

	# 足りないヘッダがあれば追加する。
	$this->__fillHeader;

	my $header = $this->_decodeHeader($this->{entity}->stringify_header);
	my $body = $this->getBody;

	my $result = $header . "\n" . $body;
	$result =~ s/\r?\n|\r/\n/g;
	$result;
}

sub setHeader {
	my $this = shift;

	my $hash;
	if(ref($_[0]) eq 'HASH') {
		$hash = shift;
	} elsif(!ref($_[0])) {
		$hash = { @_ };
	} else {
		my $ref = ref $_[0];
		die __PACKAGE__."#setHeader, ARG[1] was a bad Ref. [$ref]\n";
	}

	while(my ($key, $value) = each(%$hash)) {
		$key =~ s/^-//;
		$this->{entity}->head->replace(
			$key => $this->_encodeHeader($value, length($key))
		);
	}

	$this;
}

sub getHeader {
	my $this = shift;
	my $key = shift;

	if(my $encoded = $this->{entity}->head->get($key)) {
		$encoded =~ s/\r?\n$//;
		$this->_decodeHeader($encoded);
	} else {
		undef;
	}
}

sub deleteHeader {
	my $this = shift;
	my $key = shift;

	$this->{entity}->head->delete($key);
	$this;
}

sub setBody {
	my $this = shift;
	my $bodystr = shift;

	$bodystr =~ s/\r?\n|\r/\r\n/g;
	$this->_setBody(
		Unicode::Japanese->new($bodystr)->jis
	);

	$this;
}

sub _setBody {
	# 文字コード変換を行わない
	my $this = shift;
	my $bodydata = shift;

	my $body = MIME::Body::Scalar->new;
	$this->{entity}->bodyhandle($body);

	my $io = $body->open('w');
	$io->print($bodydata);
	$io->close;

	$this;
}

sub getBody {
	my $this = shift;

	my $handle = $this->{entity}->bodyhandle;
	if(!$handle) {
		'';
	} else {
		my $io = $handle->open('r');

		local $/ = undef;
		my $str = Unicode::Japanese->new(<$io>, 'jis')->utf8;

		$io->close;
		$str;
	}
}

sub attach {
	# $mail->attach(
	#     type     => 'text/html',
	#     data     => $data,
	#     id       => '<00112233>', # 省略可能
	#     encoding => 'base64',     # 省略可能
	# );
	# $mail->attach(
	#     type     => 'image/png',
	#     data     => $data,
	#     filename => 'foo.png',    # 省略可能
	# );
	# $mail->attach(
	#     part     => $TL->newMail,
	# );
	my $this = shift;
	my $opts = { @_ };

	if(defined($opts->{part})) {
		if(ref($opts->{part}) ne __PACKAGE__) {
			die __PACKAGE__."#attach, ARG[part] was not an instance of Tripletail::Mail. [$opts->{part}]\n";
		}

		# Content-Typeがマルチパートでなければ、そのように設定する。
		if(!(defined($this->{entity}->head->mime_attr('Content-Type')) && $this->{entity}->head->mime_attr('Content-Type') =~ m!^multipart/!i)) {
			$this->{entity}->head->replace('Content-Type' => 'multipart/mixed');
		}
	} else {
		if(!defined($opts->{type})) {
			die __PACKAGE__."#attach, ARG[type] was undef.\n";
		} elsif(ref($opts->{type})) {
			die __PACKAGE__."#attach, ARG[type] was a Ref. [$opts->{type}]\n";
		} elsif(!defined($opts->{data})) {
			die __PACKAGE__."#attach, ARG[data] was undef.\n";
		} elsif(ref($opts->{data})) {
			die __PACKAGE__."#attach, ARG[type] was a Ref. [$opts->{data}]\n";
		}

		# Content-Typeがマルチパートでなければ、そのように設定する。
		if(!(defined($this->{entity}->head->mime_attr('Content-Type')) && $this->{entity}->head->mime_attr('Content-Type') =~ m!^multipart/!i)) {
			if($opts->{type} eq 'text/html'
			|| $opts->{type} eq 'application/xhtml+xml') {
				$this->{entity}->head->replace('Content-Type' => 'multipart/alternative');
			} else {
				$this->{entity}->head->replace('Content-Type' => 'multipart/mixed');
			}
		}
	}

	# バウンダリが未設定なら設定する。
	if(!$this->{entity}->head->mime_attr('Content-Type.boundary')) {
		$this->{entity}->head->mime_attr(
			'Content-Type.boundary' => "----------=_".time."-$$-".$BOUNDARY_COUNT++
		);
	}

	if($opts->{part}) {
		my $part = $opts->{part}{entity};

		if(!$part->head->mime_attr('Content-Disposition')) {
			$part->head->mime_attr('Content-Disposition' => 'inline');
		}

		$this->{entity}->add_part($part);
		return $this;
	}

	# エンコーディング方式その他を決定
	my $part = {};
	if($opts->{type} eq 'text/html' || $opts->{type} eq 'application/xhtml+xml') {
		$part->{Type} = 'text/html; charset="ISO-2022-JP"';
		$part->{Data} = Unicode::Japanese->new($opts->{data})->jis;
		$part->{Encoding} = $opts->{encoding} || '7bit';
	} elsif($opts->{type} eq 'text/hdml' || $opts->{type} eq 'text/x-hdml') {
		$part->{Type} = 'text/x-hdml; charset="UTF-8"';
		$part->{Data} = $opts->{data};
		$part->{Encoding} = $opts->{encoding} || 'base64';
	} elsif($opts->{type} eq 'text/plain') {
		$part->{Type} = 'text/plain; charset="ISO-2022-JP"';
		$part->{Data} = Unicode::Japanese->new($opts->{data})->jis;
		$part->{Encoding} = $opts->{encoding} || '7bit';
	} else {
		$part->{Type} = $opts->{type};
		$part->{Data} = $opts->{data};
		$part->{Encoding} = $opts->{encoding} || 'base64';
	}

	my $filename = $opts->{filename};
	if(defined($filename)) {
		$part->{Filename} = $filename;
	}

	my $id = $opts->{id};
	if(defined($id)) {
		$part->{'Content-ID'} = $id;
	}

	$this->{entity}->attach(%$part);
	$this;
}

sub countParts {
	my $this = shift;

	scalar $this->{entity}->parts;
}

sub getPart {
	my $this = shift;
	my $index = shift;

	if(!defined($index)) {
		die __PACKAGE__."#getPart, ARG[1] was undef.\n";
	} elsif(ref($index)) {
		die __PACKAGE__."#getPart, ARG[2] was a Ref. [$index]\n";
	}

	my $ent = $this->{entity}->parts($index);
	if(!$ent) {
		die __PACKAGE__."#getPart, No part [$index] found.\n";
	}

	my $obj = __PACKAGE__->_new;
	$obj->{entity} = $ent;
	$obj;
}

sub deletePart {
	my $this = shift;
	my $index = shift;

	if(!defined($index)) {
		die __PACKAGE__."#getPart, ARG[1] was undef.\n";
	} elsif(ref($index)) {
		die __PACKAGE__."#getPart, ARG[2] was a Ref. [$index]\n";
	}

	my @parts = $this->{entity}->parts;

	if($index < 0 || $index >= @parts) {
		die __PACKAGE__."#getPart, No part [$index] found.\n";
	}

	splice @parts, $index, 1;
	$this->{entity}->parts(\@parts);

	$this;
}

sub toStr {
	my $this = shift;

	# 足りないヘッダがあれば追加する。
	$this->__fillHeader;

	my $str = $this->{entity}->stringify;
	$str =~ s/\r?\n|\r/\r\n/g;
	$str;
}

sub _encodeHeader {
	my $this = shift;
	my $str = shift;			# 文字列本体
	my $keylen = shift;			# ヘッダーキー長
	my $charcode = 'ISO-2022-JP';

	$str=Unicode::Japanese->new($str)->h2zKana->jis;

	# MIME::Words を使ってエンコードする。
	# ただエンコードするだけではRFC推奨の76文字改行が施されないため、
	# 以下の処理を含め、可能な限り推奨内に納める用努力する。
	# ・半角40文字無条件分割(('=?ISO-2022-JP?B?'+エンコード後データ+'?=')<76)
	#   ※43文字までいけるがギリギリなので、ある程度余裕を…
	# 分割された文字列それぞれをエンコードして\t\nで結合し、それを返す
	# 参考：MIME-Bエンコード後のサイズは元のサイズの約1.333倍(4/3倍)。
	# サイズ換算は文字コードの因果があるので注意
	# （例：JISの場合はASCII<->漢字などで、間に2〜3バイト程の切替シーケンスが入る）

	my $result = '';
	my $maxlinelength = 76;		# RFC上は78文字。今回は76文字。
	my $length = 0;

	my $atext = qr{[\w\!\#\$\%\&\'\*\+\-\/\=\?\^\_\`\{\|\}\~]+};
	my $ascii = qr{[\x00|\x20-\x7e]+};
	my $spbuf='';
	my $before_tag=0;			# 前の処理がタグ時だったら1
	my $before_enc=0;			# 前の処理でエンコードしてたら1
	foreach my $parts (split(/(\s+)/,$str)) {
		if ($parts=~/^\s+$/) {
			# 空白のみだったらエンコード内に含めるので待避
			$spbuf=$parts;
			# 前の処理でエンコードしていればskip。
			next if($before_enc);
		}

		if ($parts=~/^$ascii$/) { # 全部ASCII
			# そのまま展開
			if (($length+length($parts)) > $maxlinelength) {
				if ($result) {
					$result=~s/^(.*?)\s+$/$1/s;
					$result.="\n\t";
					$length=0;
				}
			}
			if ($before_enc) { # encdata + ASCII の場合は間のスペースがskipされているので補完
				$parts=($spbuf.$parts);
			}
			$result.=$parts;
			$length+=length($parts);
			$before_enc=0;
		} else {				# マルチバイトあり
			my $encdata=encode_mimeword($parts, 'B', $charcode);
			if (($length+length($encdata)) > $maxlinelength) {
				$result.="\n\t" if($result);
				$length=0;
			}
			if ($before_enc) { # encdata + encdata の場合は間のスペースが消えるので補完
				$encdata=encode_mimeword(($spbuf.$parts), 'B', $charcode);
			}
			$result.=$encdata;
			$length+=length($encdata);
			$before_enc=1;
		}
	}

	$result =~ s/^(.+)\n\t$/$1/s;
	$result;
}

sub _decodeHeader {
	my $this = shift;
	my $str = shift;
	my $result;

	my $mime_start = '=\?[Ii][Ss][Oo]-2022-[Jj][Pp]\?[Bb]\?';
	my $mime_body = '[A-Za-z0-9\+\/\=]+';
	my $mime_end = '\?=';

	my $mime_regex = "$mime_start$mime_body$mime_end";

	my $jis_start_regex = '\e(?:\$\@|\$B|\&\@\e\$B|\$\(D|\(I)';
	my $jis_end_regex = '\e(?:\$B|\$\(D|\([BJ])';

	while($str =~ s/($mime_regex)[ \t]*\n?[ \t]+($mime_regex)/$1$2/) {
	}

	$str =~ s/$mime_start($mime_body)$mime_end/
	Unicode::Japanese->new($1, 'binary', 'base64')->get/eg;

	$str =~ s/$jis_end_regex$jis_start_regex//g;

	$str = Unicode::Japanese->new($str, 'jis')->utf8;

	$str;
}

sub _makeMailDate {
	my $this = shift;
	my $time = shift;

	my @wdaystr = qw(Sun Mon Tue Wed Thu Fri Sat);
	my @monthstr = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

	my $TZone = '+0900';
	$TZone =~ m/\+(..)(..)/;
	my $tzone = $1 * 60 * 60 + $2 * 60;

	my ($sec, $min, $hour, $mday, $mon, $year, $wday) = (gmtime($time + $tzone))[0..6];

	sprintf("%s, %d %s %d %02d:%02d:%02d %s", 
		$wdaystr[$wday], $mday, $monthstr[$mon],
		1900 + $year, $hour, $min, $sec, $TZone);

}

sub _getHostname {
	my $this = shift;

	if(!defined($HOSTNAME)) {
		$HOSTNAME = `hostname`;
		chomp $HOSTNAME;
	}

	$HOSTNAME;
}

sub __fillHeader {
	my $this = shift;

	my $h = $this->{entity}->head;
	if(!($h->count('Date'))) {
		$h->add(Date => $this->_makeMailDate(time));
	}
	if(!$h->count('Message-Id')) {
		$h->add(
			'Message-Id' => sprintf(
				'<%d.%d.%d.tmmlib7@%s>',
				$MAIL_ID_COUNT++,
				time,
				$$,
				$this->_getHostname
			)
		);
	}
	if(!$h->count('MIME-Version')) {
		$h->add('MIME-Version' => '1.0');
	}
	if(!$h->count('Content-Type')) {
		$h->mime_attr('Content-Type' => 'text/plain');
		$h->mime_attr('Content-Type.charset' => 'ISO-2022-JP');
	}
	if(!$h->count('Content-Transfer-Encoding')) {
		$h->add('Content-Transfer-Encoding' => '7bit');
	}

	$this;
}


__END__

=encoding utf-8

=head1 NAME

Tripletail::Mail - メール作成/読み込み

=head1 SYNOPSIS

  my $mail = $TL->newMail
    ->setHeader(
	From => 'null@example.org',
	To   => 'null@example.org',
	Subject => 'This is a test mail...',
       )
    ->setBody("+----------------------------+\n".
	      "|                            |\n".
	      "|      Tripletail::Mail - Test       |\n".
	      "|                            |\n".
	      "+----------------------------+\n")
    ->toStr;

  my $mail = $TL->newMail->set("From: 差出人 <null\@example.org>\n".
             "To: 受取人 <null\@example.org>\n".
             "Subject: メール件名\n".
             "\n".
             "メール本文")
  ->toStr;

=head1 DESCRIPTION

メールの文書を生成し、読み込むクラス。
文字コードはISO-2022-JP(jis)のみ対応。

マルチパートのメールを生成する事も可能。

=head2 METHODS

=over 4

=item $TL->newMail

  $mail = $TL->newMail

Tripletail::Mail オブジェクトを作成。

=item parse

  $mail->parse("From: =?ISO-2022-JP?B?GyRCOjk9UD9NGyhC?=\r\n".
               " =?ISO-2022-JP?B?IA==?=<null\@example.org>\r\n".
               "To: =?ISO-2022-JP?B?GyRCOjk9UD9NGyhC?=\r\n".
               " =?ISO-2022-JP?B?IA==?=<null\@example.org>\r\n".
               "Subject: =?ISO-2022-JP?B?GyRCJWEhPCVrN29MPhsoQg==?=\r\n".
               "\r\n".
               "mail body")

メール本文全体をセットする。文字コードはISO-2022-JP、
エンコード済みであること。
改行コードは C<\r\n> もしくは C<\n> であること。

=item set

  $mail->set("From: 差出人 <null\@example.org>\n".
             "To: 受取人 <null\@example.org>\n".
             "Subject: メール件名\n".
             "\n".
             "メール本文")

メール本文全体をセットする。ヘッダ部はUTF-8文字列であること。
改行コードは C<\r\n> もしくは C<\n> であること。

=item get

  $str = $mail->get

メール本文全体をデコード状態で取得する。改行コードは \n となる。
set メソッドの逆の操作。

=item setHeader

  $mail->setHeader($key => $value, ...)
  $mail->setHeader({$key => $value, ...})

ヘッダを設定する。UTF-8文字列でなければならない。

=item getHeader

  $str = $mail->getHeader($key)

ヘッダを取得する。UTF-8文字列で返る。

=item deleteHeader

  $mail->deleteHeader($key)

ヘッダを削除する。

=item setBody

  $mail->setBody($text)

メール本文を設定する。UTF-8文字列でなければならない。

=item getBody

  $text = $mail->getBody

メール本文を取得する。UTF-8で返される。

=item attach

  $mail->attach(%opts)

メールオブジェクトをマルチパートとし、パートを追加する。
本文は捨てられる。

別のTripletail::Mailオブジェクトをパートとして追加する場合:

  $mail->attach(part => $TL->newMail->...);

それ以外の場合:

  $mail->attach(
      type => 'text/html',
      data => $html,
      id => '<00112233>', # Content-ID, 省略可能
      filename => 'index.html', # 省略可能
      encoding => 'base64', # 省略可能
  );

=item countParts

  $count = $mail->countParts

メールに含まれるパート数を返す。multipartでない場合は常に0。

=item getPart

  $part = $mail->getPart($index)

指定されたパートを返す。戻り値はTripletail::Mailのインスタンスである。

=item deletePart

  $mail->deletePart($index)

指定されたパートを削除する。 

=item toStr

  $mail->toStr

エンコード済みメール本文を返す。
改行コードは C<\r\n> 、文字コードはISO-2022-JP(jis)となる。

parse メソッドの逆の操作。

=back


=head1 SEE ALSO

=over 4

=item L<Tripletail>

=item L<Tripletail::Mail>

=item L<Tripletail::Sendmail>

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
