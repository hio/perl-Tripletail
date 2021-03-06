#! perl -w

use strict;
use warnings;

use Test::More tests =>
  + 4
  + 4
  + 4
  + 4
;
use lib '.';
require t::make_ini;

our $CONTENT = "1\r\n\r\n2";

&test01_ok_nonbuff_implicit_clen; # 4.
&test02_ok_nonbuff_explicit_clen; # 4.
&test03_ng_buffed_implicit_clen;  # 4.
&test04_ok_buffed_explicit_clen;  # 4.

# output_buffering=0 の時はContent-Length自動付与は行わないので発生しない.
# (Content-Lengthの明示的な指定もなしのテスト)
sub test01_ok_nonbuff_implicit_clen
{
	my $ret = t::make_ini::tltest({
		ini => {
			TL => {
			},
		},
		method => 'GET',
		param  => {},
		sub => sub{
			our $TL;
			$TL->startCgi(-main=>sub{
				$TL->getContentFilter()->addHeader('X-Test' => 'test');
				$TL->print($CONTENT);
			});
		},
	});
	SKIP:{
		ok($ret->is_success, "[test1] fetch") or skip("[test1] fetch failed", 3);
		ok($ret->{content}, "[test1] has content");

		is($ret->{content}, $CONTENT, "[test1] valid content");
		is_deeply($ret->{headers}{'Content-Length'}, undef, "[test1] no clen without outputbuffering");
	}
}

# output_buffering=0 の時はContent-Length自動付与は行わないので発生しない.
# (Content-Lengthを明示的に指定してのテスト)
sub test02_ok_nonbuff_explicit_clen
{
	my $ret = t::make_ini::tltest({
		ini => {
			TL => {
			},
		},
		method => 'GET',
		param  => {},
		sub => sub{
			our $TL;
			$TL->startCgi(-main=>sub{
				$TL->getContentFilter()->addHeader('X-Test' => 'test');
				$TL->getContentFilter->addHeader('Content-Length' => length($CONTENT));
				$TL->print($CONTENT);
			});
		},
	});
	SKIP:{
		ok($ret->is_success, "[test2] fetch") or skip("[test2] fetch failed", 3);
		ok($ret->{content}, "[test2] has content");

		is($ret->{content}, $CONTENT, "[test2] valid content");
		my $clen = length($CONTENT);
		is_deeply($ret->{headers}{'Content-Length'}, [$clen], "[test2] no clen without outputbuffering");
	}
}

# output_buffering=1 の時かつContent-Lengthがないとき, 
# そしてContent-Type以外のヘッダを追加してたときに自動付与される
# v0.43ではContent-Lengthの値が間違ってる/v0.44で直ってるのをテスト.
#
# On earlier or equals to 0.42, 
# Content-Length has wrong value.
sub test03_ng_buffed_implicit_clen
{
	my $ret = t::make_ini::tltest({
		ini => {
			TL => {
				outputbuffering => 1,
			},
		},
		method => 'GET',
		param  => {},
		sub => sub{
			our $TL;
			$TL->startCgi(-main=>sub{
				$TL->getContentFilter()->addHeader('X-Test' => 'test');
				$TL->print($CONTENT);
			});
		},
	});
	SKIP:{
		ok($ret->is_success, "[test3] fetch") or skip("[test3] fetch failed", 3);
		ok($ret->{content}, "[test3] has content");

		is($ret->{content}, $CONTENT, "[test3] valid content");
		my $clen = length($CONTENT);
		is_deeply($ret->{headers}{'Content-Length'}, [$clen], "[test3] clen");
	}
}

# output_buffering=1 の時でもContent-Lengthがあれば追加はしないので発生しない.
#
# On earlier or equals to 0.42, 
# Content-Length is shown twice.
sub test04_ok_buffed_explicit_clen
{
	my $ret = t::make_ini::tltest({
		ini => {
			TL => {
				outputbuffering => 1,
			},
		},
		method => 'GET',
		param  => {},
		sub => sub{
			our $TL;
			$TL->startCgi(-main=>sub{
				$TL->getContentFilter()->addHeader('X-Test' => 'test');
				$TL->getContentFilter->addHeader('Content-Length' => length($CONTENT));
				$TL->print($CONTENT);
			});
		},
	});
	SKIP:{
		ok($ret->is_success, "[test4] fetch") or skip("[test4] fetch failed", 3);
		ok($ret->{content}, "[test4] has content");

		is($ret->{content}, $CONTENT, "[test4] valid content");
		my $clen = length($CONTENT);
		is_deeply($ret->{headers}{'Content-Length'}, [$clen], "[test4] clen");
	}
}


# -----------------------------------------------------------------------------
# End of File.
# -----------------------------------------------------------------------------
