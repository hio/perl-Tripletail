use strict;
use warnings;
use Test::More;
use Test::Exception;
use Config;
use Data::Dumper;

our $HTTP_PORT = 8967;

eval "use POE";
if ($@) {
    plan skip_all => "POE required for various tests using http server...";
}

eval "use POE::Component::Server::HTTP";
if ($@) {
    plan skip_all => "PoCo::Server::HTTP required for various tests using http server...";
}

eval q{
    use LWP::UserAgent;
    use HTTP::Status;
    use HTTP::Message;
    use HTTP::Cookies;
    use URI::QueryParam;
};
if ($@) {
    plan skip_all => "LWP required for various tests using http server...";
}

eval q{
    use Crypt::CBC;
    use Crypt::Rijndael;
};
if ($@) {
    plan skip_all => "Crypt::CBC and Crypt::Rijndael are required for these tests...";
}

eval {
    use IO::Socket::INET;
    my $sock = IO::Socket::INET->new(
		LocalPort => $HTTP_PORT,
		Proto => 'tcp',
		Listen => 1,
		ReuseAddr => 1,
       );
    $sock or die;
};
if ($@) {
    plan skip_all => "port $HTTP_PORT/tcp required not to be in use for these tests...";
}

# ------------------------------
# plan
#
plan tests => 20;

# ------------------------------
# server
#
our $SERVER_PID;
our $KEY;
sub start_server () {
    # 子プロセスでPoCo::Server::HTTPを立てる。

    $KEY = '';
    for (1 .. 10) {
		$KEY .= int(rand 0xffffffff);
    }

    if ($_ = fork) {
		$SERVER_PID = $_;

		# サーバーが起動するまで1秒待つ
		#diag("Waiting 1 sec for the coming of server... [pid:$SERVER_PID]");
		sleep 1;
    } else {
		my $script;
		my $ini;
		my $stdin;
		my $env;
	
		POE::Component::Server::HTTP->new(
			Port => $HTTP_PORT,
			ContentHandler => {
				'/' => sub {
					my ($req, $resp) = @_;

					my $script = "use Tripletail qw(tmp$$.ini);\n" . $script;
					do {
						open my $fh, '>', "tmp$$.ini";
						if ($ini) {
							print $fh $ini;
						}
					};

					# その子プロセスでスクリプトをevalする。

					pipe my $p_read, my $c_write;
					pipe my $c_read, my $p_write;
					my $received_data = '';
					if (fork) {
						close $c_write;
						close $c_read;
			
						if (defined $stdin) {
							print $p_write $stdin;
						}
						close $p_write;
			
						while (defined($_ = <$p_read>)) {
							$received_data .= $_;
						}
			
						wait;
					} else {
						close $p_read;
						close $p_write;

						open STDIN,  '<&' . fileno $c_read;
						open STDOUT, '>&' . fileno $c_write;

						if ($env) {
							while (my ($key, $val) = each %$env) {
								$ENV{$key} = $val;
							}
						}

						$ENV{SCRIPT_NAME} = '/';
						$ENV{SERVER_NAME} = 'localhost';
						$ENV{REQUEST_METHOD} = $req->method;
						$ENV{CONTENT_TYPE} = defined $req->header('Content-Type') ?
						  $req->header('Content-Type') : 'application/x-www-form-urlencoded';
						$ENV{CONTENT_LENGTH} = defined $stdin ? length($stdin) : 0;

						if ($_ = $req->header('Cookie')) {
							$ENV{HTTP_COOKIE} = $_;
						} else {
							delete $ENV{HTTP_COOKIE};
						}
			
						eval $script;
						exit;
					}

					unlink "tmp$$.ini";

					# 結果をパースしてhttpdへ渡す。

					my $msg = HTTP::Message->parse($received_data);
					my $retval = $msg->headers->header('Status') || 200;
					$resp->code($retval);
					$resp->message(status_message($resp->code));

					foreach my $key ($msg->headers->header_field_names) {
						$resp->headers->header(
							$key => $msg->headers->header($key));
					}
		    
					$resp->content($msg->content);
					return $retval;
				},

				'/install' => sub {
					my ($req, $resp) = @_;
					my $uri = $req->uri;

					my $cipher = Crypt::CBC->new({
						key    => $KEY,
						cipher => 'Rijndael',
					});

					if (defined($_ = $uri->query_param('ini'))) {
						if ($_ = $cipher->decrypt($_)) {
							$ini = $_;
						}
					}

					if (defined($_ = $uri->query_param('stdin'))) {
						if ($_ = $cipher->decrypt($_)) {
							$stdin = $_;
						}
					}

					if (defined($_ = $uri->query_param('script'))) {
						if ($_ = $cipher->decrypt($_)) {
							$script = $_;
						}
					}

					if (defined($_ = $uri->query_param('env'))) {
						$env = eval $cipher->decrypt($_);
					}

					$resp->code(204);
					$resp->message(status_message($resp->code));
					return 204;
				},
			},
		   );
		POE::Kernel->run;
		exit;
    }
}

sub stop_server () {
    if ($SERVER_PID) {
		#diag("Waiting for the going of server... [pid:$SERVER_PID]");
		
		kill 9, $SERVER_PID;
		wait;

		$SERVER_PID = undef;
    }
}

# ------------------------------
#
my $ua = LWP::UserAgent->new;
my $cookie_jar = HTTP::Cookies->new;
$ua->cookie_jar($cookie_jar);

sub rget {
    $ua->get("http://localhost:$HTTP_PORT/", @_);
}
sub rpost {
    $ua->post("http://localhost:$HTTP_PORT/", @_);
}

sub install (@) {
    my $opts = { @_ };
    my $ini = $opts->{ini};
    my $script = $opts->{script};
    my $env = $opts->{env};
    my $stdin = $opts->{stdin};

    my $cipher = Crypt::CBC->new({
		key    => $KEY,
		cipher => 'Rijndael',
    });

    my $uri = URI->new("http://localhost:$HTTP_PORT/install");
    $uri->query_param(ini    => $cipher->encrypt(defined $ini ? $ini : ''));
    $uri->query_param(script => $cipher->encrypt(defined $script ? $script : ''));
    $uri->query_param(stdin  => $cipher->encrypt(defined $stdin ? $stdin : ''));
    if ($env) {
		$uri->query_param(
			env => $cipher->encrypt(
				Data::Dumper->new([$env])
					->Purity(1)->Useqq(1)->Terse(1)->Dump));
    }

	$ua->get($uri);
}

# ------------------------------
# start
start_server;

# ------------------------------
# Tripletail::Filter::HTML
install(
    script => q{
	    $TL->startCgi(
			-main => \&main,
		   );

		sub main {
			$TL->print(q{<form></form>});
		}
    },
   );
is(rget->content, qq{<form action="/"><input type="hidden" name="CCC" value="\x88\xa4"></form>}, 'Tripletail::Filter::HTML');

install(
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
is(rget->content, qq{<A HREF="./?%82%a0=%82%a2&amp;CCC=%88%a4"></a>\n<a href="./?%82%a0=%82%a2&amp;CCC=%88%a4">link</a>\n<a href="./?%82%a0=%82%a2&amp;CCC=%88%a4">link</a>\n<a href="./?%e3%81%82=%e3%81%84"></a>\n<A HREF="./?%82%a0=%82%a2"></a>\n}, 'Tripletail::Filter::HTML (toLink/toExtLink)');

install(
    script => q{
	    $TL->startCgi(
			-main => \&main,
		   );

		sub main {
			$TL->print(q{<form action=""></form>});
		}
    },
   );
is(rget->content, qq{<form action="/"><input type="hidden" name="CCC" value="\x88\xa4"></form>}, 'Tripletail::Filter::HTML (Form output)');

install(
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
is(rget->content, qq{<form action="/"></form>}, 'Tripletail::Filter::HTML (extForm)');


# ------------------------------
# Tripletail::Filter::MobileHTML
install(
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
is(rget->content, qq{<a href="http://www.example.org/">link</a>}, 'Tripletail::Filter::MobileHTML');

install(
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
is(rget->content, qq{<a href="./?%82%a0=%82%a2&amp;CCC=%88%a4"></a>\n<a href="./?%e3%81%82=%e3%81%84"></a>\n<a href="./?%82%a0=%82%a2"></a>\n}, 'Tripletail::Filter::MobileHTML (toLink/toExtLink)');

install(
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
is(rget->content, qq{<form action="/"><input type="hidden" name="CCC" value="\x88\xa4"></form>}, 'Tripletail::Filter::MobileHTML (Form output)');

install(
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
is(rget->content, qq{<form action="/"></form>}, 'Tripletail::Filter::MobileHTML (extForm)');


# ------------------------------
# Tripletail::Filter::CSV
SKIP: {
    eval {
        require Text::CSV_XS;
    };
    if ($@) {
        skip 'Text::CSV_XS is unavailable', 1;
    }
    
    install(
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
    is(rget->content, qq{aaa,bb,"cc,c"\nAAA,BB,"CC,C"\n}, 'Tripletail::Filter::CSV');
}

# ------------------------------
# Tripletail::Filter::Binary
install(
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
is(rget->content, "\x{de}\x{ad}\x{be}\x{ef}", 'Tripletail::Filter::Binary');

# ------------------------------
# Tripletail::InputFilter::HTML
install(
    script => q{
		$TL->startCgi(
			-main => \&main,
		   );
		sub main {
			$TL->print(
				sprintf(
					'%s-%s',
					$TL->CGI->getSliceValues(qw[foo bar]),
				   ),
			   );
		}
    },
    env => {
		QUERY_STRING => 'foo=A%20B&bar=C%20D&CCC=%88%A4',
    },
   );
is(rget->content, 'A B-C D', 'Tripletail::InputFilter::HTML (get)');

install(
    stdin => 'foo=a%20b&bar=c%20d',
   );
is(rpost->content, 'a b-c d', 'Tripletail::InputFilter::HTML (post)');

install(
    stdin => 'foo=a%20b;bar=c%20d',
   );
is(rpost->content, 'a b-c d', 'Tripletail::InputFilter::HTML (post)');

install(
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
    ini => qq{
[TL]
trap = diewithprint
stacktrace = none
},
    stdin => qq{This is a preamble.\r\n}.
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
);
is(rpost('Content-Type' => 'multipart/form-data; boundary="BOUNDARY"')->content,
   'Command---File', 'multipart/form-data [0]');

install(
    script => q{
		$TL->startCgi(
			-main => \&main,
		   );
		sub main {
			$TL->print($CGI->getFileName('File'));
		}
    });
is(rpost('Content-Type' => 'multipart/form-data; boundary="BOUNDARY"')->content,
   'data.txt', 'multipart/form-data [1]');

install(
    script => q{
		$TL->startCgi(
			-main => \&main,
		   );
		sub main {
			local $/ = undef;
			my $fh = $CGI->getFile('File');
			$TL->print(<$fh>);
		}
	});
is(rpost('Content-Type' => 'multipart/form-data; boundary="BOUNDARY"')->content,
   qq{Ged a sheo'l mi fada bhuaip\r\n}.
   qq{Air long nan crannaibh caola}, 'multipart/form-data [2]');

install(
    ini => qq{
[TL]
trap = diewithprint
stacktrace = none
tempdir = .
},
);
is(rpost('Content-Type' => 'multipart/form-data; boundary="BOUNDARY"')->content,
   qq{Ged a sheo'l mi fada bhuaip\r\n}.
   qq{Air long nan crannaibh caola}, 'multipart/form-data [3]');

# ------------------------------
# SEO出力
install(
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
is(rget->content,
   q{<head><base href="http://localhost/"></head><body><a href="foo/aaa/111">link</a></body>}, 'Tripletail::Filter::SEO');

# ------------------------------
# SEO入力
install(
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
is(rget->content, '--SEO--', 'Tripletail::InputFilter::SEO');

install(
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
is(rget->content, '----', 'Tripletail::InputFilter::SEO');

# ------------------------------
# stop
END {
    stop_server;
}
