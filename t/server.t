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
plan tests => 7;

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

						$ENV{REQUEST_URI} = '/';
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
# location
install(
	script => q{
		$TL->startCgi(
			-main => \&main,
		   );

		sub main {
			$TL->location('http://www.example.org/');
		}
	},
);
is(rget->header('Location'), 'http://www.example.org/', 'location');

# ------------------------------
# Template
install(
    script => q{
		$TL->startCgi(
			-main => \&main,
		   );

		sub main {
			my $t = $TL->newTemplate;
			$t->setTemplate(q{<&DATA>})->expand(DATA => qq{testdata});
			$TL->setContentFilter('Tripletail::Filter::TEXT');
			$t->flush;
		}
    },
   );
is(rget->content, 'testdata', 'Tripletail::Template (flush)');

install(
    script => q{
		$TL->startCgi(
			-main => \&main,
		   );

		sub main {
			$TL->setContentFilter('Tripletail::Filter::HTML');
			my $t = $TL->newTemplate;
			$t->setTemplate(q{<!begin:foo><&TEST><!end:foo><&DATA>});
			$t->node('foo')->add(TEST => 'test')->flush;
			$t->expand(DATA => qq{testdata});
			$t->flush;
		}
    },
   );
is(rget->content, 'testtestdata', 'Tripletail::Template (flush)');


# ------------------------------
# RawCookie
install(
    script => q{
		$TL->startCgi(
			-main => \&main,
		   );

		sub main {
			my $c = $TL->getRawCookie;

			if ($TL->CGI->get('setcookie')) {
				$c->set(foo => '111');
		
				$TL->print('[set]');
			}
			else {
				$TL->print($c->get('foo') || '[undef]');
			}
		}
    },
    env => {
		QUERY_STRING => 'setcookie=1',
    },
   );
is(rget->content, '[set]', 'Tripletail::RawCookie (set)');

install(
    env => {
		QUERY_STRING => '',
    },
   );
is(rget->content, '111', 'Tripletail::RawCookie (get)');

# ------------------------------
# Cookie
install(
    script => q{
		$TL->startCgi(
			-main => \&main,
		   );

		sub main {
			my $c = $TL->getCookie;
			
			if ($TL->CGI->get('setcookie')) {
				$c->set(I_AM => $TL->newForm(COOKIE => 'MONSTER'));

				$TL->print('[set]');
			}
			else {
				$TL->print($c->get('I_AM')->get('COOKIE') || '[undef]');
			}
		}
    },
    env => {
		QUERY_STRING => 'setcookie=1',
    },
   );
is(rget->content, '[set]', 'Tripletail::Cookie (set)');

install(
    env => {
		QUERY_STRING => '',
    },
   );
is(rget->content, 'MONSTER', 'Tripletail::Cookie (get)');

# ------------------------------
# stop
END {
    stop_server;
}
