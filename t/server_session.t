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
plan tests => 19;

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
# Session
SKIP: {
    my ($name) = getpwuid($<);
    my $ini = qq{
[DB]
type    = mysql
Default = DBRW1

[DBRW1]
host   = localhost
user   = $name
dbname = test

[Session]
mode    = http
dbgroup = DB
dbset   = Default
sessiontable = TripletaiL_Session_Test
csrfkey = TripletaiL_Key
};
    
    install(
        ini => $ini,
        script => q{
            $TL->startCgi(
			    -main    => \&main,
				-DB      => 'DB',
				-Session => 'Session',
			   );

            sub main {
				$TL->print("ok");
			}
		},
    );
    if (rget->content =~ m!(DBI connect.+?)<br!) {
		$_ = $1;
		s/&#39;/'/g;
		
        skip $_, 11;
    }

    my $template = sub {
        my $code = shift;

        q[
			$TL->startCgi(
				-main    => \&main,
				-DB      => 'DB',
				-Session => 'Session',
			   );

			sub main {
				$TL->print(Data::Dumper->new([_main()])
					->Purity(1)->Useqq(1)->Terse(1)->Dump);
			}

			sub _main {
				
				].$code.q[

			}
		   ];
    };

    my $ok = sub {
        my $code = shift;
        my $name = shift;

        install(
            script => $template->($code),
           );

        my $retstr = rget->content;
        my $ret = eval $retstr;
        if ($@) {
            diag($retstr);
            fail($name);
        }
        else {
            ok($ret, $name);
        }
    };

    my $dies_ok = sub {
        my $code = shift;
        my $name = shift;

        install(
            script => $template->($code),
           );

        my $retstr = rget->content;
        if($retstr =~ /error/){
             ok(1, $name);
        } else {
            my $ret = eval $retstr;
            if ($@) {
                diag($retstr);
                fail($name);
            } else {
                is($ret, undef, $name);
            }
        }
    };

    my $is = sub {
        my $code = shift;
        my $scalar = shift;
        my $name = shift;

        install(
            script => $template->($code),
           );

        my $retstr = rget->content;
        my $ret = eval $retstr;
        if ($@) {
            diag($retstr);
            fail($name);
        }
        else {
            is($ret, $scalar, $name);
        }
    };

    my $is_deeply = sub {
        my $code = shift;
        my $scalar = shift;
        my $name = shift;

        install(
            script => $template->($code),
           );

        my $retstr = rget->content;
        my $ret = eval $retstr;
        if ($@) {
            diag($retstr);
            fail($name);
        }
        else {
            is_deeply($ret, $scalar, $name);
        }
    };

    $ok->(q{
			  $TL->getSession;
		}, '[Session] getSession');

    $ok->(q{
			  my $s = $TL->getSession;
			  not $s->isHttps;
		}, '[Session] isHttps');

    $ok->(q{
			  my $s = $TL->getSession;
			  my $first = $s->get;
			  my $next = $s->get;

			  $first eq $next;
		}, '[Session] get');

    $ok->(q{
			  my $s = $TL->getSession;
			  my $old = $s->get;
			  my $new = $s->renew;
			
			  $old ne $new;
		}, '[Session] renew');

    $ok->(q{
			  my $s = $TL->getSession;
			  my $old = $s->get;
			  $s->discard;
			  my $new = $s->get;

			  $old ne $new;
			}, '[Session] discard');

    $ok->(q{
			  my $s = $TL->getSession;

			  not defined $s->getValue;
		}, '[Session] getValue [0]');

    $is->(q{
			  my $s = $TL->getSession;
			  $s->setValue('666');
			  $s->getValue;
		}, '666', '[Session] setValue');

    $is->(q{
			  my $s = $TL->getSession;
			  $s->getValue;
		}, '666', '[Session] getValue [1]');

    $ok->(q{
			  my $s = $TL->getSession;
			  [$s->getSessionInfo];
		}, '[Session] getSessionInfo');

    $ok->(q{
			  my $t = $TL->newTemplate->setTemplate(q{
				  <form name="TEST" method="post">
				  </form>
				 });
			  $t->addSessionCheck('Session', 'TEST');

			  my $form = $t->getForm('TEST');
			  $form->haveSessionCheck('Session');
		}, '[Template/Form] addSessionCheck/haveSessionCheck');

    $ok->(q{
			  my $t = $TL->newTemplate->setTemplate(q{
<?xml version="1.0" encoding="UTF-8" ?>
				  <form method="post">
				  </form>
				 });
			  $t->addSessionCheck('Session');

			  my $form = $t->getForm;
			  $form->haveSessionCheck('Session');
		}, '[Template/Form] addSessionCheck/haveSessionCheck');

    $dies_ok->(q{
			  my $t = $TL->newTemplate->setTemplate(q{
				  <form name="TEST" method="post">
				  </form>
				 });
			  $t->addSessionCheck;
		}, '[Template] addSessionCheck die');

    $dies_ok->(q{
			  my $t = $TL->newTemplate->setTemplate(q{
				  <form name="TEST" method="post">
				  </form>
				 });
			  $t->addSessionCheck('Session2', 'TEST');
		}, '[Template] addSessionCheck die');

    $dies_ok->(q{
			  my $t = $TL->newTemplate->setTemplate(q{
				  <form name="TEST" method="post">
				  </form>
				 });
			  $t->addSessionCheck('Session', 'TEST2');
		}, '[Template] addSessionCheck die');

    $dies_ok->(q{
			  my $t = $TL->newTemplate->setTemplate(q{
				  <form name="TEST" method="post">
				  </form>
				 });
			  $t->addSessionCheck('Session', \123);
		}, '[Template] addSessionCheck die');

    $dies_ok->(q{
			  my $t = $TL->newTemplate->setTemplate(q{
				  <form name="TEST" method="post">
				  </form>
				 });
			  $t->addSessionCheck('Session', 'TEST' , \123);
		}, '[Template] addSessionCheck die');

    $dies_ok->(q{
			  my $t = $TL->newTemplate->setTemplate(q{
				  <form name="TEST" method="post">
				  </form>
				 });
			  $t->addSessionCheck('Session', 'TEST' , \123);
		}, '[Template] addSessionCheck die');

    $dies_ok->(q{
			  my $t = $TL->newTemplate->setTemplate(q{
				  <form name="TEST" method="get">
				  </form>
				 });
			  $t->addSessionCheck('Session', 'TEST');
		}, '[Template] addSessionCheck die');

    install(
        script => q{
			  $TL->startCgi(
				-main    => \&main,
				-DB      => 'DB',
			   );

			sub main {
				my $DB = $TL->getDB('DB');
				$DB->execute(\'Default' => q{
					DROP TABLE IF EXISTS TripletaiL_Session_Test
				});
				$TL->print('ok');
			}
		});
    is(rget->content, 'ok', '[Session] - cleanup -');
}


# ------------------------------
# stop
END {
    stop_server;
}
