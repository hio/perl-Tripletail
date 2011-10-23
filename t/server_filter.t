use strict;
use warnings;
use Test::More;
use Test::Exception;
use Config;
use Data::Dumper;
use t::test_server;

&setup;
plan tests => 19;
&test_01_html;              #4.
&test_02_mobile_html;       #4.
&test_03_csv;               #1.
&test_04_binary;            #1.
&test_05_input_filter;      #6.
&test_06_seo_filter;        #1.
&test_07_seo_input_filter;  #2.
exit;

# -----------------------------------------------------------------------------
# shortcut.
# 
sub check_requires() { &t::test_server::check_requires; }
sub start_server()   { &t::test_server::start_server; }
sub raw_request(@)   { &t::test_server::raw_request; }

# -----------------------------------------------------------------------------
# setup.
# 
sub setup
{
	my $failmsg = check_requires();
	if( $failmsg )
	{
		plan skip_all => $failmsg;
	}
	
	&start_server;
}

# -----------------------------------------------------------------------------
# Tripletail::Filter::HTML.
# 
sub test_01_html
{
	{
		my $res = raw_request(
			method => 'GET',
			script => q{
				$TL->startCgi(
					-main => \&main,
				);
				
				sub main {
					$TL->print(q{<form></form>});
				}
			},
		);
		is($res->content, qq{<form action="/"><input type="hidden" name="CCC" value="\x88\xa4"></form>}, '[html] CCC');
	}
	
	{
		my $res = raw_request(
			method => 'GET',
			script => q{
				$TL->startCgi(
					-main => \&main,
				);
				
				sub main {
					$TL->print(q{<A HREF="} . $TL->newForm->set('あ' => 'い')->toLink . qq{"></a>\n});
					$TL->print($TL->newTemplate->setTemplate(qq{<a href="<&URL>">link</a>\n})
						->expand(URL => $TL->newForm->set('あ' => 'い')->toLink) ->toStr);
					my $t = $TL->newTemplate->setTemplate(qq{<!begin:node><a href="<&URL>">link</a><!end:node>\n});
					$t->node('node')->add(URL => $TL->newForm->set('あ' => 'い')->toLink);
					$TL->print($t->toStr);
					$TL->print(q{<a href="} . $TL->newForm->set('あ' => 'い')->toExtLink . qq{"></a>\n});
					$TL->print(q{<A HREF="} . $TL->newForm->set('あ' => 'い')->toExtLink(undef, 'Shift_JIS') . qq{"></a>\n});
				}
			},
		);
		is($res->content, qq{<A HREF="./?%82%a0=%82%a2&amp;CCC=%88%a4"></a>\n<a href="./?%82%a0=%82%a2&amp;CCC=%88%a4">link</a>\n<a href="./?%82%a0=%82%a2&amp;CCC=%88%a4">link</a>\n<a href="./?%e3%81%82=%e3%81%84"></a>\n<A HREF="./?%82%a0=%82%a2"></a>\n}, '[html] (toLink/toExtLink)');
	}
	
	{
		my $res = raw_request(
			method => 'GET',
			script => q{
				$TL->startCgi(
					-main => \&main,
				);
				
				sub main {
					$TL->print(q{<form action=""></form>});
				}
			},
		);
		is($res->content, qq{<form action="/"><input type="hidden" name="CCC" value="\x88\xa4"></form>}, '[html] Form output');
	}
	
	{
		my $res = raw_request(
			method => 'GET',
			script => q{
				$TL->startCgi(
					-main => \&main,
				);
				
				sub main {
					my $t = $TL->newTemplate->setTemplate(q{<form action=""></form>})->extForm;
					$TL->print($t->toStr);
				}
			},
		);
		is($res->content, qq{<form action="/"></form>}, '[html] extForm');
	}
}

# -----------------------------------------------------------------------------
# Tripletail::Filter::MobileHTML
# 
sub test_02_mobile_html
{
	{
		my $res = raw_request(
			method => 'GET',
			script => q{
				$TL->setContentFilter('Tripletail::Filter::MobileHTML');
				$TL->startCgi(
					-main => \&main,
				);
				sub main {
					$TL->print(q{<a href="http://www.example.org/">link</a>});
				}
			},
		);
		is $res->content, qq{<a href="http://www.example.org/">link</a>}, '[mobile] normal';
	}
	
	{
		my $res = raw_request(
			method => 'GET',
			script => q{
				$TL->setContentFilter('Tripletail::Filter::MobileHTML');
				$TL->getContentFilter->addHeader('X-TEST',123);
				$TL->startCgi(
					-main => \&main,
				);
				sub main {
					$TL->print(q{<a href="} . $TL->newForm->set('あ' => 'い')->toLink . qq{"></a>\n});
					$TL->print(q{<a href="} . $TL->newForm->set('あ' => 'い')->toExtLink . qq{"></a>\n});
					$TL->print(q{<a href="} . $TL->newForm->set('あ' => 'い')->toExtLink(undef, 'Shift_JIS') . qq{"></a>\n});
				}
			},
		);
		is $res->content, qq{<a href="./?%82%a0=%82%a2&amp;CCC=%88%a4"></a>\n<a href="./?%e3%81%82=%e3%81%84"></a>\n<a href="./?%82%a0=%82%a2"></a>\n}, '[mobile] toLink/toExtLink';
	}
	
	{
		my $res = raw_request(
			method => 'GET',
			script => q{
				$TL->setContentFilter('Tripletail::Filter::MobileHTML');
				$TL->getContentFilter->addHeader('X-TEST',123);
				$TL->getContentFilter->addHeader('X-TEST',1234);
				$TL->startCgi(
					-main => \&main,
				 );
				sub main {
					$TL->print(q{<form action=""></form>});
				}
			},
		);
		is $res->content, qq{<form action="/"><input type="hidden" name="CCC" value="\x88\xa4"></form>}, '[mobile] Form output';
	}
	
	{
		my $res = raw_request(
			method => 'GET',
			script => q{
				$TL->setContentFilter('Tripletail::Filter::MobileHTML');
				$TL->getContentFilter->setHeader('X-TEST',123);
				$TL->getContentFilter->addHeader('X-TEST',1234);
				$TL->startCgi(
					-main => \&main,
				);
				sub main {
					my $t = $TL->newTemplate->setTemplate(q{<form action=""></form>})->extForm;
					$TL->print($t->toStr);
				}
			},
		);
		is($res->content, qq{<form action="/"></form>}, '[mobile] extForm');
	}
}

# -----------------------------------------------------------------------------
# Tripletail::Filter::CSV
# 
sub test_03_csv
{
	SKIP:
	{
		eval{ require Text::CSV_XS; };
		if ($@) {
			skip 'Text::CSV_XS is unavailable', 1;
		}
		my $res = raw_request(
			method => 'GET',
			script => q{
				$TL->setContentFilter(
					'Tripletail::Filter::CSV',
					charset  => 'UTF-8',
					filename => 'foo.csv',
				);
				$TL->startCgi(
					-main => \&main,
				);
				sub main {
					$TL->print(['aaa', 'bb', 'cc,c']);
					$TL->print('AAA,BB,"CC,C"'."\n");
				}
			},
		);
		is $res->content, qq{aaa,bb,"cc,c"\nAAA,BB,"CC,C"\n}, '[csv]';
	}
}

# -----------------------------------------------------------------------------
# Tripletail::Filter::Binary
# 
sub test_04_binary
{
	{
		my $res = raw_request(
			method => 'GET',
			script => q{
				$TL->setContentFilter('Tripletail::Filter::Binary');
				$TL->startCgi(
					-main => \&main,
				 );
				sub main {
					$TL->print("\x{de}\x{ad}\x{be}\x{ef}");
				}
			},
		);
		is $res->content, "\x{de}\x{ad}\x{be}\x{ef}", '[binary]';
	}
}

# -----------------------------------------------------------------------------
# Tripletail::InputFilter::HTML (default input filter)
# 
sub test_05_input_filter
{
	{
		my $res = raw_request(
			method => 'GET',
			script => q{
				$TL->startCgi(
					-main => \&main,
				 );
				sub main {
					$TL->print(
						sprintf('%s-%s', $TL->CGI->getSliceValues(qw[foo bar])),
				 );
				}
			},
			env => {
				QUERY_STRING => 'foo=A%20B&bar=C%20D&CCC=%88%A4',
			},
		);
		is $res->content, 'A B-C D', '[input] get';
	}
	
	{
		my $res = raw_request(
			method => 'POST',
    	stdin  => 'foo=a%20b&bar=c%20d',
		);
		is $res->content, 'a b-c d', '[input] post';
	}
	
	{
		my $res = raw_request(
			method => 'POST',
			script => q{
				$TL->startCgi(
					-main => \&main,
				);
				sub main {
				$TL->print(join ',', $CGI->getKeys);
				$TL->print('---');
				$TL->print(join ',', $CGI->getFileKeys);
				}
			},
			env => {},
			ini => {
				TL => {
					trap => 'diewithprint',
					stacktrace => 'none',
				},
			},
			stdin =>
				qq{This is a preamble.\r\n}.
				qq{\r\n}.
				qq{--BOUNDARY\r\n}.
				qq{Content-Disposition: form-data; name="Command"\r\n}.
				qq{\r\n}.
				qq{DoUpload\r\n}.
				qq{--BOUNDARY\r\n}.
				qq{Content-Disposition: form-data;\r\n}.
				qq{    name="File";\r\n}.
				qq{    filename="data.txt"\r\n}.
				qq{\r\n}.
				qq{Ged a sheo'l mi fada bhuaip\r\n}.
				qq{Air long nan crannaibh caola\r\n}.
				qq{--BOUNDARY--\r\n}.
				qq{\r\n}.
				qq{This is a epilogue.},
			params => [
				'Content-Type' => 'multipart/form-data; boundary="BOUNDARY"',
			],
		);
		is $res->content, 'Command---File', '[input] multipart/form-data [0]';
	}
	
	{
		my $res = raw_request(
			method => 'POST',
			script => q{
				$TL->startCgi(
					-main => \&main,
				);
				sub main {
					$TL->print($CGI->getFileName('File'));
				}
			},
			params => [
				'Content-Type' => 'multipart/form-data; boundary="BOUNDARY"',
			],
		);
		is $res->content, 'data.txt', '[input] multipart/form-data [1]';
	}
	
	{
		my $res = raw_request(
			method => 'POST',
			script => q{
				$TL->startCgi(
					-main => \&main,
				);
				sub main {
					local $/ = undef;
					my $fh = $CGI->getFile('File');
					$TL->print(<$fh>);
				}
			},
			params => [
				'Content-Type' => 'multipart/form-data; boundary="BOUNDARY"',
			],
		);
		is $res->content,
			 qq{Ged a sheo'l mi fada bhuaip\r\n}.
			 qq{Air long nan crannaibh caola}, '[input] multipart/form-data [2]';
	}
	
	{
		my $res = raw_request(
			method => 'POST',
			ini => {
				TL => {
					'trap' => 'diewithprint',
					'stacktrace' => 'none',
					'tempdir' => '.',
				},
			},
			params => [
				'Content-Type' => 'multipart/form-data; boundary="BOUNDARY"',
			],
		);
		is $res->content,
			 qq{Ged a sheo'l mi fada bhuaip\r\n}.
			 qq{Air long nan crannaibh caola}, '[input] multipart/form-data [3]';
	}
}

# -----------------------------------------------------------------------------
# SEO出力
# 
sub test_06_seo_filter
{
	{
		my $res = raw_request(
			method => 'GET',
			script => q{
				$TL->setContentFilter(['Tripletail::Filter::SEO', 1001]);
				$TL->startCgi(
					-main => \&main,
				 );
				sub main {
					$TL->getContentFilter(1001)->setOrder(qw(ID Name));
					$TL->getContentFilter(1001)->toLink($TL->newForm(KEY => 'VALUE'));
					$TL->print(q{<head><base href="http://www.example.org/"></head><body><a href="foo.cgi?SEO=1&aaa=111">link</a></body>});
				}
			},
		);
		is $res->content,
			 q{<head><base href="http://localhost/"></head><body><a href="foo/aaa/111">link</a></body>}, '[seo]';
	}
}

# -----------------------------------------------------------------------------
# SEO入力
# 
sub test_07_seo_input_filter
{
	{
		my $res = raw_request(
			method => 'GET',
			script => q{
				$TL->setInputFilter(['Tripletail::InputFilter::SEO', 999]);
				$TL->startCgi(
					-main => \&main,
				 );
				sub main {
					$TL->print("--" . $TL->CGI->get('aaa') . "--");
				}
			},
			env => {
				PATH_INFO => '/aaa/SEO',
			},
		);
		is $res->content, '--SEO--', '[seo-in]';
	}
	
	{
		my $res = raw_request(
			method => 'GET',
			script => q{
				$TL->setInputFilter(['Tripletail::InputFilter::SEO', 999]);
				$TL->startCgi(
					-main => \&main,
				 );
				sub main {
					$TL->print("--" . $TL->CGI->get('aaa') . "--");
				}
			},
			env => {
				PATH_INFO => '/aaa/',
			},
		);
		is $res->content, '----', '[seo-in]';
	}
}

# -----------------------------------------------------------------------------
# End of File.
# -----------------------------------------------------------------------------
