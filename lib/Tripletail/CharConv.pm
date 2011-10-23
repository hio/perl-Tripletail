# -----------------------------------------------------------------------------
# Tripletail::CharConv - 文字コードクラス（内部用）
# -----------------------------------------------------------------------------
package Tripletail::CharConv;
use strict;
use warnings;

# $TL->charconv('文字列', 'utf8', 'sjis');

our $INSTANCE;
our %MAP_ENCODE_TO_UNIJP = (
	'UTF-8' => 'utf8',
	'ISO-2022-JP' => 'jis',
	'Shift_JIS' => 'sjis',
	'CP932' => 'sjis',
	'EUC-JP' => 'euc',
	'UCS-2' => 'ucs2',
	'UTF-32' => 'ucs4',
	'UTF-16' => 'utf16',
	'UTF-32' => 'utf32',
	'UTF-16BE' => 'utf16-be',
	'UTF-16LE' => 'utf16-le',
	'UTF-32BE' => 'utf32-be',
	'UTF-32LE' => 'utf32-le',
   );
our @GUESS_TABLE = (
	'7bit-jis',
	'euc-jp',
	'cp932',
	'utf8',
	'ascii',
   );

1;

sub _getInstance {
	my $class = shift;

	if (!$INSTANCE) {
		$INSTANCE = $class->__new(@_);
	}

	$INSTANCE;
}

sub _charconv {
	my $this = shift;
	my $str = shift;
	my $from = shift;
	my $to = shift;
	my $prefer_encode = shift;

	local($_);

	if(!defined($str)) {
		die "TL#charconv, ARG[1] was undef.\n";
	} elsif(ref($str)) {
		die "TL#charconv, ARG[2] was a Ref. [$str]\n";
	}

	if(!defined($from)) {
		$from = 'auto';
	} elsif(ref($from) && ref($from) ne 'ARRAY') {
		die "TL#charconv, ARG[3] was neither SCALAR nor ARRAY Ref. [$from]\n";
	}

	if(!defined($to)) {
		$to = 'UTF-8';
	} elsif(ref($to)) {
		die "TL#charconv, ARG[3] was a Ref. [$to]\n";
	}

	if(ref($prefer_encode)) {
		die "TL#charconv, ARG[4] was a Ref. [$prefer_encode]\n";
	}

	if (not $prefer_encode or not $this->_encodeAvailable) {
		require Unicode::Japanese;
		# UniJPでコード変換。

		if (ref $from) {
			# 配列が指定されても'auto'と見做す。
			$from = 'auto';
		}

		if ($_ = $MAP_ENCODE_TO_UNIJP{$from}) {
			$from = $_;
		}
		
		if ($_ = $MAP_ENCODE_TO_UNIJP{$to}) {
			$to = $_;
		}

		Unicode::Japanese->new($str, $from)->conv($to);
	} else {
		# Encodeでコード変換。
		$from = 'cp932' if($from eq 'Shift_JIS');
		$to = 'cp932' if($to eq 'Shift_JIS');

		if ($from eq 'auto') {
			# デフォルトの推測表を使う
			$from = \@GUESS_TABLE;
		}

		my $encoding;
		if(ref($from)) {
			# Encode::Guessを利用して自動判別。
			foreach my $enc (@$from) {
				$enc = 'cp932' if($enc eq 'Shift_JIS');
			}

			my $guessed = Encode::Guess::guess_encoding($str, @$from);

			if(ref($guessed)) {
				# 判別成功
				$encoding = $guessed;
			} else {
				# "エンコード名 or エンコード名 or ..." になっている。
				my $candidates = {
					map { $_ => 1 } split /\s+or\s+/, $guessed,
				};

				foreach my $cand (@$from) {
					if($candidates->{$cand}) {
						# 見付かった
						$encoding = Encode::find_encoding($cand);
						last;
					}
				}

				if(!$encoding) {
					# 見付からなかった
					$encoding = Encode::find_encoding('binary');

					if(!$encoding) {
						$encoding = Encode::find_encoding('null');
					}
				}
			}
		} else {
			$encoding = Encode::find_encoding($from);
		}

		my $utf8 = $encoding->decode($str);
		Encode::find_encoding($to)->encode($utf8);
	}
}

sub _encodeAvailable {
	my $this = shift;

	local($_);

	if(defined($_ = $this->{encode_is_available})) {
		$_;
	} else {
		eval {
			require Encode;
			require Encode::Alias;
			require Encode::Guess;
		};
		$this->{encode_is_available} = $@ ? 0 : 1;
	}
}

sub __new {
	my $class = shift;

	my $this = bless {} => $class;
	$this->{encode_is_available} = undef;

	$this;
}

sub __getEncodeAliases {
    # UniJPエンコード名 => 一般エンコード名(Encode.pm互換)のHASH Refを作って返す。
    # オプション:
    #   sjis_is_cp932 => 真ならsjisをCP932に。偽ならShift_JISに。
    my $this = shift;
    my $option = { @_ };

    my $sjis = $option->{sjis_is_cp932} ? 'CP932' : 'Shift_JIS';
    
    my $alias = {
		utf8  => 'UTF-8',
		jis   => 'ISO-2022-JP',
		sjis  => $sjis,
		euc   => 'EUC-JP',
		ucs2  => 'UCS-2',
	
		# Encodeにはucs4に直接対応するエンコード名が存在しない為、
		# 代わりにUTF-32を用いる。(Unicodeの範囲内ではどちらも同じ？)
		ucs4  => 'UTF-32',
	
		utf16 => 'UTF-16',
		'utf16-be' => 'UTF-16BE',
		'utf16-le' => 'UTF-16LE',
		utf32 => 'UTF-32',
		'utf32-be' => 'UTF-32BE',
		'utf32-le' => 'UTF-32LE',
		
		# sjis絵文字は変換出来ないので普通のsjisにフォールバック
		'sjis-imode' => $sjis,
		'sjis-doti'  => $sjis,
		'sjis-jsky'  => $sjis,
    };

    $alias;
}

__END__

=encoding utf-8

=head1 NAME

Tripletail::CharConv - 内部クラス

=head1 DESCRIPTION

L<Tripletail> によって内部的に使用される。

=head1 SEE ALSO

L<Tripletail>

=head1 AUTHOR INFORMATION

=over 4

Copyright 2006 YMIRLINK Inc. All Rights Reserved.

This framework is free software; you can redistribute it and/or modify it under the same terms as Perl itself

このフレームワークはフリーソフトウェアです。あなたは Perl と同じライセンスの 元で再配布及び変更を行うことが出来ます。

Address bug reports and comments to: tl@tripletail.jp

HP : http://tripletail.jp/

=back

=cut
