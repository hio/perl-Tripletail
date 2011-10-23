# -----------------------------------------------------------------------------
# Tripletail::Value - 値の検証や変換
# -----------------------------------------------------------------------------
package Tripletail::Value;
use strict;
use warnings;
use Tripletail;

#---------------------------------- 正規表現

my $atext = qr{[\w\!\#\$\%\&\'\*\+\-\/\=\?\^\_\`\{\|\}\~]+};
my $dotString = qr{[\w\!\#\$\%\&\'\*\+\-\/\=\?\^\_\`\{\|\}\~\.]*};
my $pcmailexp = qr{^
	((?:
	  (?:$atext(?:\.?$atext)*) # Dot-string
	 |
	  (?:"(\\[\x20-\x7f]|[\x21\x23-\x5b\x5d-\x7e])+")   # Quoted-string
	)) # Local-part
	\@
	([\w\-]+(?:\.[\w\-]+)+) # Domain-part
\z}x;
my $mobilemailexp = qr{^
	((?:
	  (?:$atext(?:$dotString)) # Dot-string
	 |
	  (?:"(\\[\x20-\x7f]|[\x21\x23-\x5b\x5d-\x7e])+")   # Quoted-string
	)) # Local-part
	\@
	([\w\-]+(?:\.[\w\-]+)+) # Domain-part
\z}x;

my $re_hira = qr/(\xe3\x81\x81|\xe3\x81\x82|\xe3\x81\x83|\xe3\x81\x84|\xe3\x81\x85|\xe3\x81\x86|\xe3\x81\x87|\xe3\x81\x88|\xe3\x81\x89|\xe3\x81\x8a|\xe3\x81\x8b|\xe3\x81\x8c|\xe3\x81\x8d|\xe3\x81\x8e|\xe3\x81\x8f|\xe3\x81\x90|\xe3\x81\x91|\xe3\x81\x92|\xe3\x81\x93|\xe3\x81\x94|\xe3\x81\x95|\xe3\x81\x96|\xe3\x81\x97|\xe3\x81\x98|\xe3\x81\x99|\xe3\x81\x9a|\xe3\x81\x9b|\xe3\x81\x9c|\xe3\x81\x9d|\xe3\x81\x9e|\xe3\x81\x9f|\xe3\x81\xa0|\xe3\x81\xa1|\xe3\x81\xa2|\xe3\x81\xa3|\xe3\x81\xa4|\xe3\x81\xa5|\xe3\x81\xa6|\xe3\x81\xa7|\xe3\x81\xa8|\xe3\x81\xa9|\xe3\x81\xaa|\xe3\x81\xab|\xe3\x81\xac|\xe3\x81\xad|\xe3\x81\xae|\xe3\x81\xaf|\xe3\x81\xb0|\xe3\x81\xb1|\xe3\x81\xb2|\xe3\x81\xb3|\xe3\x81\xb4|\xe3\x81\xb5|\xe3\x81\xb6|\xe3\x81\xb7|\xe3\x81\xb8|\xe3\x81\xb9|\xe3\x81\xba|\xe3\x81\xbb|\xe3\x81\xbc|\xe3\x81\xbd|\xe3\x81\xbe|\xe3\x81\xbf|\xe3\x82\x80|\xe3\x82\x81|\xe3\x82\x82|\xe3\x82\x83|\xe3\x82\x84|\xe3\x82\x85|\xe3\x82\x86|\xe3\x82\x87|\xe3\x82\x88|\xe3\x82\x89|\xe3\x82\x8a|\xe3\x82\x8b|\xe3\x82\x8c|\xe3\x82\x8d|\xe3\x82\x8e|\xe3\x82\x8f|\xe3\x82\x90|\xe3\x82\x91|\xe3\x82\x92|\xe3\x82\x93)/;
my $re_kata = qr/(\xe3\x82\xa1|\xe3\x82\xa2|\xe3\x82\xa3|\xe3\x82\xa4|\xe3\x82\xa5|\xe3\x82\xa6|\xe3\x82\xa7|\xe3\x82\xa8|\xe3\x82\xa9|\xe3\x82\xaa|\xe3\x82\xab|\xe3\x82\xac|\xe3\x82\xad|\xe3\x82\xae|\xe3\x82\xaf|\xe3\x82\xb0|\xe3\x82\xb1|\xe3\x82\xb2|\xe3\x82\xb3|\xe3\x82\xb4|\xe3\x82\xb5|\xe3\x82\xb6|\xe3\x82\xb7|\xe3\x82\xb8|\xe3\x82\xb9|\xe3\x82\xba|\xe3\x82\xbb|\xe3\x82\xbc|\xe3\x82\xbd|\xe3\x82\xbe|\xe3\x82\xbf|\xe3\x83\x80|\xe3\x83\x81|\xe3\x83\x82|\xe3\x83\x83|\xe3\x83\x84|\xe3\x83\x85|\xe3\x83\x86|\xe3\x83\x87|\xe3\x83\x88|\xe3\x83\x89|\xe3\x83\x8a|\xe3\x83\x8b|\xe3\x83\x8c|\xe3\x83\x8d|\xe3\x83\x8e|\xe3\x83\x8f|\xe3\x83\x90|\xe3\x83\x91|\xe3\x83\x92|\xe3\x83\x93|\xe3\x83\x94|\xe3\x83\x95|\xe3\x83\x96|\xe3\x83\x97|\xe3\x83\x98|\xe3\x83\x99|\xe3\x83\x9a|\xe3\x83\x9b|\xe3\x83\x9c|\xe3\x83\x9d|\xe3\x83\x9e|\xe3\x83\x9f|\xe3\x83\xa0|\xe3\x83\xa1|\xe3\x83\xa2|\xe3\x83\xa3|\xe3\x83\xa4|\xe3\x83\xa5|\xe3\x83\xa6|\xe3\x83\xa7|\xe3\x83\xa8|\xe3\x83\xa9|\xe3\x83\xaa|\xe3\x83\xab|\xe3\x83\xac|\xe3\x83\xad|\xe3\x83\xae|\xe3\x83\xaf|\xe3\x83\xb0|\xe3\x83\xb1|\xe3\x83\xb2|\xe3\x83\xb3)/;
my $re_char = qr/[\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5}/;
my $re_widenum = qr/(\xef\xbc\x90|\xef\xbc\x91|\xef\xbc\x92|\xef\xbc\x93|\xef\xbc\x94|\xef\xbc\x95|\xef\xbc\x96|\xef\xbc\x97|\xef\xbc\x98|\xef\xbc\x99)/;

my $re_ipv4_addr = qr{^
    (?: :: (?:f{4}:)? )?
	(
	    (?: 0* (?: 2[0-4]\d  |
				   25[0-5]   |
				   [01]?\d\d |
				   \d)
			    \.){3}
		0*
		(?: 2[0-4]\d   |
			25[0-5]    |
			[01]?\d\d  |
			\d)
	)
$}ix;

# IPv4 射影 IPv6 アドレス は未サポート
my $re_ipv6_addr = qr{^
    [:a-fA-F0-9]{2,39}
$}x;

1;

#---------------------------------- 一般

sub _new {
	my $class = shift;
	my $this = bless {} => $class;

	$this->{value} = undef;

	if(@_) {
		$this->set(@_);
	}

	$this;
}

sub set {
	my $this = shift;
	my $value = shift;

	if(!defined($value)) {
		die __PACKAGE__."#set, ARG[1] was undef.\n";
	} elsif(ref($value)) {
		die __PACKAGE__."#set, ARG[1] was a Ref. [$value]\n";
	}

	$this->{value} = $value;
	$this;
}

sub get {
	my $this = shift;

	$this->{value};
}

#---------------------------------- set系

sub setDate {
	my $this = shift;
	my $year = shift;
	my $mon = shift;
	my $day = shift;

	if($this->_isExistentDay($year, $mon, $day)) {
		$this->{value} = sprintf '%04d-%02d-%02d', $year, $mon, $day;
	} else {
		$this->{value} = undef;
	}

	$this;
}

sub setDateTime {
	my $this = shift;
	my $year = shift;
	my $mon = shift;
	my $day = shift;
	my $hour = shift;
	my $min = shift || 0;
	my $sec = shift || 0;

	if($this->_isExistentDay($year, $mon, $day)
	&& $this->_isExistentTime($hour, $min, $sec)) {
		$this->{value} = sprintf(
			'%04d-%02d-%02d %02d:%02d:%02d',
			$year, $mon, $day,
			$hour, $min, $sec,
		);
	} else {
		$this->{value} = undef;
	}

	$this;
}

sub setTime {
	my $this = shift;
	my $hour = shift;
	my $min = shift || 0;
	my $sec = shift || 0;

	if($this->_isExistentTime($hour, $min, $sec)) {
		$this->{value} = sprintf '%02d:%02d:%02d', $hour, $min, $sec;
	} else {
		$this->{value} = undef;
	}

	$this;
}

#---------------------------------- get系

sub getLen {
	my $this = shift;

	length $this->{value};
}

sub getSjisLen {
	my $this = shift;

	length Unicode::Japanese->new($this->{value})->sjis;
}

sub getCharLen {
	my $this = shift;

	my @chars = grep {defined && length} split /($re_char)/, $this->{value};
	scalar @chars;
}

sub getAge {
	my $this = shift;
	my $date = shift;

	my @from = $this->_parseDate($this->{value});
	my @to = do {
		if(defined($date)) {
			$this->_parseDate($date);
		} else {
			my @lt = localtime;
			$lt[5] += 1900;
			$lt[4]++;
			@lt[5, 4, 3];
		}
	};

	if(!@to || !$this->_isExistentDay(@to)) {
		return undef;
	}

	my $age = $to[0] - $from[0];
	if($to[1] < $from[1] || ($to[1] == $from[1] && $to[2] < $from[2])) {
		$age--;
	}
	$age;
}

sub getRegexp {
	my $this = shift;
	my $type = shift;
	
	if(!defined($type)) {
		die __PACKAGE__."#getRegexp, ARG[1] was undef.\n";
	} elsif(ref($type)) {
		die __PACKAGE__."#getRegexp, ARG[1] was a Ref. [$type]\n";
	}

	my $regexp;

	$type = lc($type);
	if($type eq 'hira') {
		$regexp = $re_hira;
	} elsif($type eq 'kata') {
		$regexp = $re_kata;
	} elsif($type eq 'numbernarrow') {
		$regexp = qr{\d};
	} elsif($type eq 'numberwide') {
		$regexp = $re_widenum;
	} else {
		die __PACKAGE__."#getRegexp, ARG[1] was no mache. [$type]\n";
	}
	
	$regexp;
}

#---------------------------------- is系
sub isEmpty {
	my $this = shift;

	not length $this->{value};
}

sub isWhitespace {
	# 半角/全角スペース、タブのみで構成されているなら1。
	# 空文字列やundefならundef。
	my $this = shift;

	if(length($this->{value})) {
		$this->{value} =~ /\A(?:\s|　)+\z/ ? 1 : undef;
	} else {
		undef;
	}
}

sub isBlank {
	my $this = shift;

	if($this->isEmpty || $this->isWhitespace) {
		1;
	} else {
		undef;
	}
}

sub isPrintableAscii {
	my $this = shift;

	if(length($this->{value})) {
		$this->{value} =~ /\A[\x20-\x7e]*\z/ ? 1 : undef;
	} else {
		undef;
	}

}

sub isWide {
	my $this = shift;

	if(length($this->{value})) {
	
		my $sjisvalue = $TL->charconv($this->{value}, 'UTF-8' => 'Shift_JIS');
		
		my $re_char = '[\x81-\x9f\xe0-\xef\xfa-\xfc][\x40-\x7e\x80-\xfc]|[\xa1-\xdf]|[\x00-\x7f]';
		
		my @chars = grep {defined && length} split /($re_char)/, $sjisvalue;
		
		!grep { length($_) == 1 } @chars;
	} else {
		undef;
	}
}

sub isPassword {
	my $this = shift;

	($this->isPrintableAscii &&
		$this->{value} =~ m/[a-z]/ &&
		$this->{value} =~ m/[A-Z]/ &&
		$this->{value} =~ m/[0-9]/ &&
		$this->{value} =~ m/[\x20-\x2f\x3a-\x40\x5b-\x60\x7b-\x7e]/) ? 1 : undef;
}

sub isZipCode {
	my $this = shift;

	$this->{value} =~ /\A\d{3}-\d{4}\z/ ? 1 : undef;
}

sub isTelNumber {
	my $this = shift;

	$this->{value} =~ /\A\d[\d-]+\d\z/ ? 1 : undef;
}

sub isEmail {
	my $this = shift;

	$this->{value} =~ /$pcmailexp/ ? 1 : undef;
}

sub isMobileEmail {
	my $this = shift;

	$this->{value} =~ /$mobilemailexp/ ? 1 : undef;
}

sub isInteger {
	my $this = shift;
	my $min = shift;
	my $max = shift;

	if($this->{value} =~ m/\A-?\d+\z/) {
		if(defined($min)) {
			$this->{value} >= $min or return undef;
		}
		if(defined($max)) {
			$this->{value} <= $max or return undef;
		}

		1;
	} else {
		undef;
	}
}

sub isReal {
	my $this = shift;
	my $min = shift;
	my $max = shift;

	if($this->{value} =~ m/\A-?\d+(?:\.\d+)?\z/) {
		if(defined($min)) {
			$this->{value} >= $min or return undef;
		}
		if(defined($max)) {
			$this->{value} <= $max or return undef;
		}

		1;
	} else {
		undef;
	}
}

sub isHira {
	my $this = shift;

	$this->{value} =~ m/\A$re_hira+\z/ ? 1 : undef;
}

sub isKata {
	my $this = shift;

	$this->{value} =~ m/\A$re_kata+\z/ ? 1 : undef;
}

sub isExistentDay {
	# YYYY-MM-DD この日が存在するなら1
	my $this = shift;

	my @date = $this->_parseDate($this->{value});
	@date ? $this->_isExistentDay(@date) : undef;
}

sub isGif {
	my $this = shift;

	$this->{value} =~ /\AGIF8[79]a/ ? 1 : undef;
}

sub isJpeg {
	my $this = shift;

	$this->{value} =~ /\A\xFF\xD8/ ? 1 : undef;
}

sub isPng {
	my $this = shift;

	$this->{value} =~ /\A\x89PNG\x0D\x0A\x1A\x0A/ ? 1 : undef;
}

sub isHttpUrl {
	my $this = shift;

	$this->{value} =~ m!\Ahttp://! ? 1 : undef;
}

sub isHttpsUrl {
	my $this = shift;

	$this->{value} =~ m!\Ahttps://! ? 1 : undef;
}

sub isLen {
	my $this = shift;
	my $min = shift;
	my $max = shift;

	my $len = $this->getLen;

	if(defined($min)) {
		$len >= $min or return undef;
	}
	if(defined($max)) {
		$len <= $max or return undef;
	}

	1;
}

sub isSjisLen {
	my $this = shift;
	my $min = shift;
	my $max = shift;

	my $len = $this->getSjisLen;

	if(defined($min)) {
		$len >= $min or return undef;
	}
	if(defined($max)) {
		$len <= $max or return undef;
	}

	1;
}

sub isCharLen {
	my $this = shift;
	my $min = shift;
	my $max = shift;

	my $len = $this->getCharLen;

	if(defined($min)) {
		$len >= $min or return undef;
	}
	if(defined($max)) {
		$len <= $max or return undef;
	}

	1;
}

sub isPortable {
	# 機種依存文字を含んでいないなら1
	my $this = shift;
	my $str  = $this->{value};

	my $unijp = Unicode::Japanese->new;

	# XXXX 一旦eucへ変換して１文字ずつに区切りを入れる
	my $str_euc = $unijp->set($str)->euc;

	my $ascii = '[\x00-\x7F]';
	my $twoBytes = '[\x8E\xA1-\xFE][\xA1-\xFE]';
	my $threeBytes = '\x8F[\xA1-\xFE][\xA1-\xFE]';

	my @str_euc = split(/($ascii|$twoBytes|$threeBytes)/o, $str_euc);

	# 機種依存文字
	my $dep_regex 
		= '\xED[\x40-\xFF]|\xEE[\x00-\xFC]'              # NEC選定IBM拡張文字(89-92区)
		. '|[\xFA\xFB][\x40-\xFF]|\xFC[\x40-\x4B]'     # IBM拡張文字(115-119区)
		. '|[\x85-\x87][\x40-\xFF]|\x88[\x40-\x9E]'    # 特殊文字エリア
		. '|[\xF0-\xF8][\x40-\xFF]|\xF9[\x40-\xFC]'    # JIS外字エリア
		. '|\xEA[\xA5-\xFF]|[\xEB-\xFB][\x40-\xFF]|\xFC[\x40-\xFC]' # MAC外字及び縦組用
		. '|\x81[\xBE\xBF\xDA\xDB\xDF\xE0\xE3\xE6\xE7]'; # 13区の記号は一部2区と重複している

	# SJIS
	foreach my $str (@str_euc) {
		next if(!defined($str) || ($str eq ''));
		my $str_sjis = $unijp->set($str, 'euc')->sjis . '';
		return undef if($str_sjis =~ m/\A(?:$dep_regex)\z/o);
	}

	return 1;
}

sub isIpAddress {
	my $this = shift;
	my $checkmask = shift;
	my $checkip  = $this->{value};
	
	if(!defined($checkmask)) {
		return undef;
	} elsif(ref($checkmask)) {
		return undef;
	}

	my @masks = split /\s+/, $checkmask;
	
	my @ip = $this->_parse_addr($checkip);

	if(@ip != 4 && @ip != 16) {
		# パース失敗
		return undef;
	} else {
		foreach my $mask (@masks) {
			my $bits;
			if($mask =~ s!/(\d+)$!!) {
				$bits = $1;
			}

			my @mask = $this->_parse_addr($mask);
			if(@mask != 4 and @mask != 16) {
				# パース失敗
				return undef;
			}

			if(@mask != @ip) {
				# IPバージョン違い
				next;
			}

			# ビット数が指定されたなかった場合は /32 または /128 と見做す。
			defined $bits or
			  $bits = (@mask == 4 ? 32 : 128);

			if($this->_ip_match(\@ip, \@mask, $bits)) {
				# マッチした
				return 1;
			}
		}

		# どれにもマッチしなかった。
		return undef;
	}
}


#---------------------------------- conv系
sub convHira {
	my $this = shift;

	my $unijp = Unicode::Japanese->new($this->{value});
	$this->{value} = $unijp->kata2hira->get;

	$this;
}

sub convKata {
	my $this = shift;

	my $unijp = Unicode::Japanese->new($this->{value});
	$this->{value} = $unijp->hira2kata->get;

	$this;
}

sub convNumber {
	my $this = shift;

	my $unijp = Unicode::Japanese->new($this->{value});
	$this->{value} = $unijp->z2hNum->get;

	$this;
}

sub convNarrow {
	my $this = shift;

	my $unijp = Unicode::Japanese->new($this->{value});
	$this->{value} = $unijp->z2h->get;

	$this;
}

sub convWide {
	my $this = shift;

	my $unijp = Unicode::Japanese->new($this->{value});
	$this->{value} = $unijp->h2z->get;

	$this;
}

sub convComma {
	my $this = shift;

	$this->{value} =~ s/\G((?:^[-+])?\d{1,3})(?=(?:\d\d\d)+(?!\d))/$1,/g;

	$this;
}

sub convLF {
	my $this = shift;

	$this->{value} =~ s/\r\n/\n/g;
	$this->{value} =~ s/\r/\n/g;

	$this;
}

sub convBR {
	my $this = shift;

	$this->{value} =~ s/\r\n/\n/g;
	$this->{value} =~ s/\r/\n/g;
	$this->{value} =~ s/\n/<BR>\n/g;

	$this;
}

#---------------------------------- force系
sub forceHira {
	my $this = shift;

	my @chars = split /($re_char)/, $this->{value};
	$this->{value} = '';

	foreach my $c (@chars) {
		length($c) or next;

		if($c =~ m/$re_hira/) {
			# 変換せずにそのまま
			$this->{value} .= $c;
		}
	}

	$this;
}

sub forceKata {
	# forceHiraの逆
	my $this = shift;

	my @chars = split /($re_char)/, $this->{value};
	$this->{value} = '';

	foreach my $c (@chars) {
		length($c) or next;

		if($c =~ m/$re_kata/) {
			# 変換せずにそのまま
			$this->{value} .= $c;
		}
	}

	$this;
}

sub forceNumber {
	my $this = shift;

	my @chars = split /($re_char)/, $this->{value};
	$this->{value} = '';

	foreach my $c (@chars) {
		length($c) or next;

		if($c =~ m/^\d$/) {
			# 変換しない
			$this->{value} .= $c;
		}
	}

	$this;
}

sub forceMin {
	my $this = shift;
	my $min = shift;
	my $val = shift;

	if(!defined($min)) {
		die __PACKAGE__."#forceMin, ARG[1] was undef.\n";
	} elsif(ref($min)) {
		die __PACKAGE__."#forceMin, ARG[1] was a Ref. [$min]\n";
	}

	$this->forceNumber;
	if($this->{value} < $min) {
		$this->{value} = $val;
	}

	$this;
}

sub forceMax {
	my $this = shift;
	my $max = shift;
	my $val = shift;

	if(!defined($max)) {
		die __PACKAGE__."#forceMax, ARG[1] was undef.\n";
	} elsif(ref($max)) {
		die __PACKAGE__."#forceMax, ARG[1] was a Ref. [$max]\n";
	}

	$this->forceNumber;
	if($this->{value} > $max) {
		$this->{value} = $val;
	}

	$this;
}

sub forceMaxLen {
	my $this = shift;
	my $maxlen = shift;

	if(length($this->{value}) > $maxlen) {
		substr($this->{value}, $maxlen) = '';
	}

	$this;
}

sub forceMaxUtf8Len {
	my $this = shift;
	my $maxlen = shift;

	if(length($this->{value}) > $maxlen) {
		# $maxlenバイトに入りきるまで一文字ずつ入れていく

		my @chars = split /($re_char)/, $this->{value};
		$this->{value} = '';
		my $current_len = 0;

		foreach my $c (@chars) {
			if($current_len + length($c) <= $maxlen) {
				$this->{value} .= $c;
				$current_len += length($c);
			} else {
				# これ以上入らない
				last;
			}
		}
	}

	$this;
}

sub forceMaxSjisLen {
	my $this = shift;
	my $maxlen = shift;

	my $unijp = Unicode::Japanese->new;

	if(length($unijp->set($this->{value})->sjis) > $maxlen) {
		# $maxlenバイトに入りきるまで一文字ずつ入れていく

		my @chars = split /($re_char)/, $this->{value};
		$this->{value} = '';
		my $current_len = 0;

		foreach my $c (@chars) {
			my $sjis_c = $unijp->set($c)->sjis;

			if($current_len + length($sjis_c) <= $maxlen) {
				$this->{value} .= $c;
				$current_len += length($sjis_c);
			} else {
				# これ以上入らない
				last;
			}
		}
	}

	$this;
}

sub forceMaxCharLen {
	my $this = shift;
	my $maxlen = shift;

	my @chars = grep {defined && length} split /($re_char)/, $this->{value};
	if(@chars > $maxlen) {
		splice @chars, $maxlen;
		$this->{value} = join '', @chars;
	}

	$this;
}

#---------------------------------- その他

sub trimWhitespace {
	# 文字列前後の半角/全角スペース、タブを削除
	my $this = shift;

	$this->{value} =~ s/\A(?:\s|　)+//;
	$this->{value} =~ s/(?:\s|　)+\z//;

	$this;
}

sub countWords {
	my $this = shift;

	my @words = split /(?:\s|　)+/, $this->{value};
	scalar @words;
}

sub strCut {
	my $this = shift;
	my $charanum = shift;

	my $v = $TL->newValue;
	
	my $value = $this->{value};
	my @output;

	while(length($value)) {
		$v->{value} = $value;
		my $temp = $v->forceMaxCharLen($charanum)->get;
		$value = substr($value,length($temp));
		push(@output,$temp);
	}

	@output;
}

#---------------------------------- 内部メソッド

sub _isLeapYear {
	my $this = shift;
	my $y = shift;

	($y % 4 == 0 &&
		$y % 100 != 0) ||
			$y % 400 == 0;
}

sub _isExistentDay {
	my $this = shift;
	my $year = shift;
	my $mon = shift;
	my $day = shift;

	if($mon < 1 || $mon > 12) {
		return 0;
	}

	my $maxday = do {
		if($this->_isLeapYear($year) && $mon == 2) {
			29;
		} else {
			[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]->[$mon - 1];
		}
	};

	$day <= $maxday;
}

sub _isExistentTime {
	# うるう秒のチェックはしない。不規則に挿入されるので予期出来ない。
	my $this = shift;
	my $hour = shift;
	my $min = shift;
	my $sec = shift;

	$hour >= 0 && $hour <= 23 &&
		$min >= 0 && $min <= 59 &&
			$sec >= 0 && $sec <= 59;
}

sub _parseDate {
	my $this = shift;
	my $str = shift;

	if($str =~ m!^(\d{4})-(\d{2})-(\d{2})$!) {
		return ($1, $2, $3);
	} else {
		return ();
	}
}

sub _parse_addr {
	my $this = shift;
	my $addr = shift;

	if($addr =~ m/$re_ipv4_addr/) {
		# IPv4
		$1 =~ m/\A(\d+)\.(\d+)\.(\d+)\.(\d+)\z/;
		($1, $2, $3, $4);
	} elsif($addr =~ m/$re_ipv6_addr/) {
		# IPv6
		my $word2bytes = sub {
			my $word = hex shift;
			(($word >> 8) & 0xff, $word & 0xff);
		};
		
		if($addr =~ /::/) {
			# 短縮形式を展開
			my ($left, $right) = split /::/, $addr;
			
			my @left = split /:/, $left;
			my @right = split /:/, $right;
			
			foreach(scalar @left .. 7 - scalar @right) {
				push @left, 0
			};
			
			map { $word2bytes->($_) } (@left, @right);
		} else {
			map { $word2bytes->($_) } split /:/, $addr;
		}
	} else {
		();
	}
}


sub _ip_match {
	my $this = shift;
	my $a = shift;
	my $b = shift;
	my $bits = shift;
	my $i = 0;

	# $bits == 0 ならば何の比較もせずに「一致」として判定。
	# $bits == 最大値 ならば完全一致するかどうかで判定。
	while($bits > 0) {
		if($bits >= 8) {
			$a->[$i] != $b->[$i]
			  and return 0;

			$bits -= 8;
		} else {
			# 上位 $bits ビットのみ比較
			(($a->[$i] >> (8 - $bits)) & (2 ** $bits - 1)) !=
			  (($b->[$i] >> (8 - $bits)) & (2 ** $bits - 1))
				and return 0;

			$bits = 0;
		}
		$i++;
	}
	
	1;
}

__END__

=encoding utf-8

=head1 NAME

Tripletail::Value - 値の検証や変換

=head1 SYNOPSIS

  my $value = $TL->newValue('null@example.org');
  
  if ($value->isEmail) {
      print $value->get . " is a valid email address.\n";
  }

  # ｎｕｌｌ＠ｅｘａｍｐｌｅ．ｏｒｇ を表示
  print $value->convWide->get . "\n";

=head1 DESCRIPTION

セットした値１つの形式をチェックし、または形式を矯正する。

値を文字列として扱う場合は、常に UTF-8 である事が前提となる。

=head2 METHODS

=head3 一般

=over 4

=item C<< $TL->newValue >>

  $val = $TL->newValue
  $val = $TL->newValue($value)

Tripletail::Value オブジェクトを作成。
引数があれば、その引数で set が実行される。

=item set

  $val->set($value)

値をセット。

=item get

  $value = $val->get

矯正後の値を取得。

=back


=head3 set系

=over 4

=item C<< setDate >>

  $val->setDate($year, $month, $day)

年月日を指定してYYYY-MM-DD形式でセットする。
日付として不正である場合はundefがセットされる。

=item C<< setDateTime >>

  $val->setDateTime($year, $month, $day, $hour, $min, $sec)

各値を指定して時刻をYYYY-MM-DD HH:MM:SS形式でセットする。
時刻として不正である場合はundefがセットされる。
$min、$secは省略でき、省略時は0が使用される。

=item C<< setTime >>

  $val->setTime($hour, $min, $sec)

各値を指定して時刻をHH:MM:SS形式でセットする。
範囲は00:00:00～23:59:59までで、時刻として正しくない場合はundefがセットされる。
$min、$secは省略でき、省略時は0が使用される。

=back


=head3 get系

=over 4

=item getLen

  $n_bytes = $val->getLen

バイト数を返す。

=item getSjisLen

  $n_bytes = $val->getSjisLen

Shift_Jisでのバイト数を返す。

=item getCharLen

  $n_chars = $val->getCharLen

文字数を返す。

=item getAge

  $age = $val->getAge
  $age = $val->getAge($date)

YYYY-MM-DD形式の値として、$date の日付での年齢を返す。省略可能。
日付の形式が間違っている場合はundefを返す。

デフォルトは現在の日付。

=item getRegexp

  $regexp = $val->getRegexp($type)

指定された$typeに対応する正規表現を返す。
対応する$typeは次の通り。

hira
ひらがなに対応する正規表現を返す。

kata
カタカナに対応する正規表現を返す。

numbernarrow
半角数字に対応する正規表現を返す。

numberwide
全角数字に対応する正規表現を返す。

=back


=head3 is系

=over 4

=item isEmpty

  $bool = $val->isEmpty

値が空（undefまたは0文字）なら1。
そうでなければundefを返す。

=item isWhitespace

  $bool = $val->isWhitespace

半角/全角スペース、タブのみで構成されていれば1。
そうでなければundefを返す。値が0文字やundefの場合もundefを返す。

=item isBlank

  $bool = $val->isBlank

値が空（undefまたは0文字）であるか、半角/全角スペース、タブのみで構成されていれば1。
そうでなければundefを返す。値が0文字やundefの場合もundefを返す。


=item isPrintableAscii

  $bool = $val->isPrintableAscii

文字列が制御コードを除くASCII文字のみで構成されているなら1。
そうでなければundefを返す。値が0文字やundefの場合もundefを返す。

=item isWide

  $bool = $val->isWide

文字列が全角文字のみで構成されているなら1。
そうでなければundefを返す。値が0文字やundefの場合もundefを返す。

=item isPassword

  $bool = $val->isPassword

文字列が半角の数字、アルファベット大文字、小文字、記号を全て最低1ずつ含んでいるなら1。
そうでなければundefを返す。

=item isZipCode

  $bool = $val->isZipCode

7桁の郵便番号（XXX-XXXX形式）なら1。
そうでなければundefを返す。

実在する郵便番号かどうかは確認しない。

=item isTelNumber

  $bool = $val->isTelNumber

電話番号（/^\d[\d-]+\d$/）なら1。
そうでなければundefを返す。

数字で始まり、数字で終わり、ハイフン(-)が一つ以上あり、その間が数字とハイフン(-)のみで構成されていれば電話番号とみなす。

=item isEmail

  $bool = $val->isEmail

メールアドレスとして正しい形式であれば1。
そうでなければundefを返す。

=item isMobileEmail

  $bool = $val->isMobileEmail

メールアドレスとして正しい形式であれば1。
そうでなければundefを返す。

但し携帯電話のメールアドレスでは、アカウント名の末尾にピリオドを含んでいる場合がある為、これも正しい形式であるとみなす。

携帯電話キャリアのドメイン名を判別するわけではないため、通常のメールアドレスも 1 を返す。

=item isInteger($min,$max)

  $bool = $val->isInteger
  $bool = $val->isInteger($min,$max)

整数で、かつ$min以上$max以下なら1。$mix,$maxは省略可能。
そうでなければundefを返す。
空もしくはundefの場合は、undefを返す。

デフォルトでは、最大最小のチェックは行わなず整数であれば1を返す。

=item isReal($min,$max)

  $bool = $val->isReal
  $bool = $val->isReal($min,$max)

整数もしくは小数で、かつ$min以上$max以下なら1。$mix,$maxは省略可能。
そうでなければundefを返す。
空もしくはundefの場合は、undefを返す。

デフォルトでは、最大最小のチェックは行わなず、整数もしくは小数であれば1を返す。

=item isHira

  $bool = $val->isHira

平仮名だけが含まれている場合は1。
そうでなければundefを返す。値が0文字やundefの場合もundefを返す。

=item isKata

  $bool = $val->isKata

片仮名だけが含まれている場合は1。
そうでなければundefを返す。値が0文字やundefの場合もundefを返す。

=item isExistentDay

  $bool = $val->isExistentDay

YYYY-MM-DDで設定された日付が実在するものなら1。
そうでなければundefを返す。

=item isGif

  $bool = $val->isGif

=item isJpeg

  $bool = $val->isJpeg

=item isPng

  $bool = $val->isPng

それぞれの形式の画像なら1。
そうでなければundefを返す。

画像として厳密に正しい形式であるかどうかは確認しない。
( L<file(1)> 程度の判断のみ。)

=item isHttpUrl

  $bool = $val->isHttpUrl

"http://" で始まる文字列なら1。
そうでなければundefを返す。

=item isHttpsUrl

  $bool = $val->isHttpsUrl

"https://" で始まる文字列なら1。
そうでなければundefを返す。

=item isLen($min,$max)

  $bool = $val->isLen($min,$max)

バイト数の範囲が指定値以内かチェックする。$mix,$maxは省略可能。
範囲内であれば1、そうでなければundefを返す。

=item isSjisLen($min,$max)

  $bool = $val->isSjisLen($min,$max)

Shift-Jisでのバイト数の範囲が指定値以内かチェックする。$mix,$maxは省略可能。
範囲内であれば1、そうでなければundefを返す。

=item isCharLen($min,$max)

  $bool = $val->isCharLen($min,$max)

文字数の範囲が指定値以内かチェックする。$mix,$maxは省略可能。
範囲内であれば1、そうでなければundefを返す。

=item isPortable

  $bool = $val->isPortable

機種依存文字以外のみで構成されていれば1。
そうでなければ（機種依存文字を含んでいれば）undefを返す。

値が0文字やundefの場合は1を返す。

=item isIpAddress

  $bool = $val->isIpAddress($checkmask)

$checkmaskに対して、設定されたIPアドレスが一致すれば1。そうでなければundef。

$checkmaskは空白で区切って複数個指定する事が可能。

例：'10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.1 fe80::/10 ::1'。

=back


=head3 conv系

=over 4

=item convHira

  $val->convHira

ひらがなに変換する。

=item convKata

  $val->convKata

カタカナに変換する。

=item convNumber

  $val->convNumber

半角数字に変換する。

=item convNarrow

  $val->convNarrow

全角文字を半角に変換する。

=item convWide

  $val->convWide

半角文字を全角に変換する。

=item convComma

  $val->convComma

半角数字を3桁区切りのカンマ表記に変換する。

=item convLF

  $val->convLF

改行コードを LF (\n) に変換する。

=item convBR

  $val->convBR

改行コードを <BR>\n に変換する。

=back


=head3 force系

=over 4

=item forceHira

  $val->forceHira

ひらがな以外の文字は削除。

=item forceKata

  $val->forceKata

カタカナ以外の文字は削除。

=item forceNumber

  $val->forceNumber

半角数字以外の文字は削除。

=item forceMin($max,$val)

  $val->forceMin($max,$val)

半角数字以外の文字を削除し、min未満なら$valをセットする。$val省略時はundefをセットする。

=item forceMax($max,$val)

  $val->forceMax($max,$val)

半角数字以外の文字を削除し、maxより大きければ$valをセットする。$val省略時はundefをセットする。

=item forceMaxLen($max)

  $val->forceMaxLen($max)

最大バイト数を指定。超える場合はそのバイト数までカットする。

=item forceMaxUtf8Len($max)

  $val->forceMaxUtf8Len($max)

UTF-8での最大バイト数を指定。
超える場合はそのバイト数以下まで
UTF-8の文字単位でカットする。

=item forceMaxSjisLen($max)

  $val->forceMaxSjisLen($max)

SJISでの最大バイト数を指定。超える場合はそのバイト数以下まで
SJISの文字単位でカットする。

=item forceMaxCharLen($max)

  $val->forceMaxCharLen($max)

最大文字数を指定。超える場合はその文字数以下までカットする。


=back


=head3 その他

=over 4

=item trimWhitespace

  $val->trimWhitespace

値の前後に付いている半角/全角スペース、タブを削除する。

=item countWords

全角/半角スペースで単語に区切った時の個数を返す。

=item strCut
  @str = $val->strCut($charanum)

指定された文字数で文字列を区切り、配列に格納する。

=back

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
