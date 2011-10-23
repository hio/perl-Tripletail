package Tripletail::SMIME;
use warnings;
use strict;

our $VERSION = '0.06';

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

__PACKAGE__->_init;

1;

sub sign {
	my $this = shift;
	my $mime = shift;

	if(!defined($mime)) {
		die __PACKAGE__."#sign, ARG[1] was undef.\n";
	} elsif(ref($mime)) {
		die __PACKAGE__."#sign, ARG[1] was a Ref. [$mime]\n";
	}

	$this->_moveHeaderAndDo($mime, '_sign');
}

sub signonly {
	my $this = shift;
	my $mime = shift;

	if(!defined($mime)) {
		die __PACKAGE__."#signonly, ARG[1] was undef.\n";
	} elsif(ref($mime)) {
		die __PACKAGE__."#signonly, ARG[1] was a Ref. [$mime]\n";
	}

	# suppose that $mime is prepared.
	my $result = $this->_signonly($mime);
	$result =~ s/\r?\n|\r/\r\n/g;
	$result;
}

sub encrypt {
	my $this = shift;
	my $mime = shift;

	if(!defined($mime)) {
		die __PACKAGE__."#encrypt, ARG[1] was undef.\n";
	} elsif(ref($mime)) {
		die __PACKAGE__."#encrypt, ARG[1] was a Ref. [$mime]\n";
	}

	$this->_moveHeaderAndDo($mime, '_encrypt');
}

sub isSigned {
	my $this = shift;
	my $mime = shift;

	if(!defined($mime)) {
		die __PACKAGE__."#isSigned, ARG[1] was undef.\n";
	} elsif(ref($mime)) {
		die __PACKAGE__."#isSigned, ARG[1] was a Ref. [$mime]\n";
	}

	my $ctype = $this->_getContentType($mime);
	if($ctype =~ m!^application/(?:x-)?pkcs7-mime! && $ctype =~ m!smime-type=signed-data!) {
		# signed-data署名
		1;
	} elsif($ctype =~ m!^multipart/signed! && $ctype =~ m!protocol="application/(?:x-)?pkcs7-signature"!) {
		# 分離署名 (クリア署名)
		1;
	} else {
		undef;
	}
}

sub isEncrypted {
	my $this = shift;
	my $mime = shift;

	if(!defined($mime)) {
		die __PACKAGE__."#isEncrypted, ARG[1] was undef.\n";
	} elsif(ref($mime)) {
		die __PACKAGE__."#isEncrypted, ARG[1] was a Ref. [$mime]\n";
	}

	my $ctype = $this->_getContentType($mime);
	if($ctype =~ m!^application/(?:x-)?pkcs7-mime!
	&& ($ctype !~ m!smime-type=! || $ctype =~ m!smime-type=enveloped-data!)) {
		# smime-typeが存在しないか、それがenveloped-dataである。
		1;
	} else {
		undef;
	}
}

sub _moveHeaderAndDo {
	my $this = shift;
	my $mime = shift;
	my $method = shift;

	# Content- または MIME- で始まるヘッダはそのままに、
	# それ以外のヘッダはmultipartのトップレベルにコピーしなければならない。
	# (FromやTo、Subject等)
	($mime,my $headers) = $this->prepareSmimeMessage($mime);

	my $result = $this->$method($mime);
	$result =~ s/\r?\n|\r/\r\n/g;

	# コピーしたヘッダを入れる
	$result =~ s/\r\n\r\n/\r\n$headers\r\n/;
	$result;
}

sub _getContentType {
	my $this = shift;
	my $mime = shift;

	my $headkey;
	my $headline = '';

	$mime =~ s/\r?\n|\r/\r\n/g;
	foreach my $line (split /\r\n/, $mime) {
		if(!length($line)) {
			return $headline;
		} elsif($line =~ m/^([^:]+):\s?(.*)/) {
			my ($key, $value) = ($1, $2);
			$headkey = $key;

			if($key =~ m/^Content-Type$/i) {
				$headline = $value;
			}
		} else {
			if($headkey =~ m/^Content-Type$/i) {
				$headline .= "\r\n$line";
			}
		}
	}

	return $headline;
}

# -----------------------------------------------------------------------------
# my ($message,$movedheader) = $smime->prepareSmimeMessage($mime);
#
sub prepareSmimeMessage {
	my $this = shift;
	my $mime = shift;

	$mime =~ s/\r?\n|\r/\r\n/g;

	my $move = '';
	my $rest = '';
	my $is_move = 0;
	my $is_rest = 1;
	while($mime=~/(.*\n?)/g) {
		my $line = $1;
		if($line eq "\r\n") { # end of header.
			$rest .= $line . substr($mime,pos($mime));
			last;
		}
		if($line=~/^(Content-|MIME-)/i) {
			($is_move, $is_rest) = (0,1);
		} elsif( $line =~ /^(Subject:)/i ) {
			($is_move, $is_rest) = (1,1);
		} elsif( $line =~ /^\S/ ) {
			($is_move, $is_rest) = (1,0);
		}
		$is_move and $move .= $line;
		$is_rest and $rest .= $line;
	}
	($rest,$move);
}

__END__

=encoding utf-8

=head1 NAME

Tripletail::SMIME - S/MIMEの署名、検証、暗号化、復号化

=head1 SYNOPSIS

  use Tripletail::SMIME;
  
  my $plain = <<'EOF';
  From: alice@example.org
  To: bob@example.com
  Subject: Tripletail::SMIME test
  
  This is a test mail. Please ignore...
  EOF
  
  my $smime = Tripletail::SMIME->new();
  $smime->setPrivateKey($privkey, $crt);
  # $smime->setPublicKey([$icacert]); # if needed.
  
  my $signed = $smime->sign($plain);
  print $signed;
  
=head1 DESCRIPTION

S/MIMEの署名、検証、暗号化、復号化を行うクラス。

cryptoライブラリ(http://www.openssl.org)が必要。

=head2 METHODS

=over 4

=item new

引数無し

=item setPrivateKey

  $smime->setPrivateKey($key, $crt);
  $smime->setPrivateKey($key, $crt, $password);

秘密鍵を設定する。ここで設定された秘密鍵は署名と復号化の際に用いられる。
ファイル名ではなく、鍵本体を渡す。

対応しているフォーマットは PEM のみ。鍵の読み込みに失敗した場合はdieする。

=item setPublicKey

  $smime->setPublicKey($crt);
  $smime->setPublicKey([$crt1, $crt2, ...]);

公開鍵を設定する。ここで設定された公開鍵は署名への添付、署名の検証、
そして暗号化の際に用いられる。

対応しているフォーマットは PEM のみ。鍵の読み込みに失敗した場合はdieする。

=item sign

  $signed_mime = $smime->sign($raw_mime);

署名を行い、MIMEメッセージを返す。可能な署名はクリア署名のみ。

C<Content-*>, C<MIME-*> 及び C<Subject> を除いたヘッダは
multipartのトップレベルにコピーされる。
C<Subject> はS/MIMEを認識できないメーラのために, multipartの
トップレベルと保護されるメッセージの両側に配置される。

=item signonly

  $sign = $smime->signonly($prepared_mime);

署名の計算を行う。
C<$sign> はBASE64でエンコードされて返る。
C<$prepared_mime> には, L</prepareSmimeMessage> で返される値を渡す。

=item prepareSmimeMessage

  ($prepared_mime,$outer_header) = $smime->prepareSmimeMessage($source_mime);

署名用のメッセージを準備する。
C<$mime> には著名用に修正されたMIMEメッセージを返す。
C<$header> は、S/MIMEの外側に付与するヘッダを返す。

C<$prepared_mime> の本文はC<$source_mime>と同じ物となるが、
ヘッダに関してはC<Content-*>, C<MIME-*>, C<Subject> を除く全てが
取り除かれる。取り除かれたヘッダは C<$outer_header> に返される。
S/MIMEメッセージを構築する際にはこれをS/MIMEメッセージのヘッダに追加する。
C<Subject> ヘッダのみは C<$prepared_mime> と C<$outer_header> の両方に
現れる点に注意。

=item check

  $source_mime = $smime->check($signed_mime);

検証を行う。検証に失敗した場合はその理由と共にdieする。

=item encrypt

  $encrypted_mime = $smime->encrypt($raw_mime);

暗号化を行う。

C<Content-*>, C<MIME-*> 及び C<Subject> を除いたヘッダは
multipartのトップレベルにコピーされる。
C<Subject> はS/MIMEを認識できないメーラのために, multipartの
トップレベルと保護されるメッセージの両側に配置される。

=item decrypt

  $decrypted_mime = $smime->decrypt($encrypted_mime);

復号化を行う。復号化に失敗した場合はその理由と共にdieする。

=item isSigned

  $is_signed = $smime->isSigned($mime);

渡されたMIMEメッセージがS/MIMEで署名されたものなら真を返す。
クリア署名かどうかは問わない。
署名後に暗号化したメッセージを渡した場合は、署名が直接見えない為、
偽を返す事に注意。

=item isEncrypted

  $is_encrypted = $smime->isEncrypted($mime);

渡されたMIMEメッセージがS/MIMEで暗号化されたものなら真を返す。
暗号化後に署名したメッセージを渡した場合は、暗号文が直接見えない為、
偽を返す事に注意。

=back

=cut

