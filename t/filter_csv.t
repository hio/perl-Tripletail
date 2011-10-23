#! /usr/bin/perl -w
## ----------------------------------------------------------------------------
#  t/filter_csv.t
# -----------------------------------------------------------------------------
# Mastering programmed by YAMASHINA Hio
#
# Copyright 2006 YAMASHINA Hio
# -----------------------------------------------------------------------------
# $Id: filter_csv.t,v 1.1 2006/10/10 06:31:13 hio Exp $
# -----------------------------------------------------------------------------
use strict;
use warnings;

use Test::More tests => 5;
use Test::Exception;
use File::Spec;
our $TL;

&test_001;

sub run_cgi(&;$)
{
	my $code  = shift;
	my $param = shift || {};
	
	my $pid = open(my $stdout, "-|");
	defined($pid) or die "open failed: $!";
	if( !$pid )
	{	# child.
		$ENV{GATEWAY_INTERFACE} = 'RUN/0.1';
		$ENV{REQUEST_URI}       = '/';
		$ENV{REQUEST_METHOD}    = 'GET';
		$ENV{QUERY_STRING}      = join('&', map{"$_=$param->{$_}"}keys %$param);
		eval
		{
			require Tripletail;
			Tripletail->import(File::Spec->devnull);
			$TL->startCgi(-main=>sub{
				&$code;
			});
			exit 0;
		};
		exit 1;
	}
	my $out = join('', <$stdout>);
	my $kid = waitpid($pid, 0);
	$kid==$pid or die "catch another process (pid:$kid), expected $pid";
	my $sig = $?&127;
	my $core = $?&128 ? 1 : 0;
	my $ret = $?>>8;
	$?==0 or die "fail with $ret (sig:$sig, core:$core)";
	$out =~ s/.*\r?\n\r?\n//;
	$out;
}

sub _set_csv_filter(;$)
{
	my $filename = shift;
	$TL->setContentFilter(
		'Tripletail::Filter::CSV',
		charset  => 'UTF-8',
		#($filename ? (filename => $filename) : ())
	);
}

sub test_001
{
	is(run_cgi(sub{$TL->print("test run")}), "test run", "test run.");
	
	is(run_cgi(sub{
		_set_csv_filter();
	  $TL->print( 'aaa,"b,b,b",ccc,ddd' . "\n");
	}),qq/aaa,"b,b,b",ccc,ddd\n/, "print with string");
	
	is(run_cgi(sub{
		_set_csv_filter();
	  $TL->print( ['aaa', 'b,b,b', 'ccc', 'ddd'] );
	}),qq/aaa,"b,b,b",ccc,ddd\n/, "print with arrayref");
	
	is(run_cgi(sub{
		_set_csv_filter();
	  $TL->print( ['aaa', '"b,b,b"', 'ccc', 'ddd'] );
	}),qq/aaa,"""b,b,b""",ccc,ddd\n/, "print with arrayref with escape");
	
	is(run_cgi(sub{
		_set_csv_filter();
	  $TL->print( 'aaa,"b,b,b",' );
	  $TL->print( 'CCC,DDD' );
	  $TL->print( "\n" );
	}), qq/aaa,"b,b,b",CCC,DDD\n/, "print as some strings");
}

# -----------------------------------------------------------------------------
# End of File.
# -----------------------------------------------------------------------------
