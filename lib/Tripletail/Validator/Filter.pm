# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter - Filterインターフェイス
# -----------------------------------------------------------------------------
use strict;
use warnings;

1;

package Tripletail::Validator::Filter;
use Tripletail;

#---------------------------------- 一般
sub new {
	my $class = shift;
	return bless {}, $class;
}

sub doFilter {
	die "call to abstract method";
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::CharLen - CharLenフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::CharLen;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	my ( $min, $max ) =
	  defined($args) ? map { $_ ne '' ? $_ : undef } split( ',', $args ) : ();
	return grep { !$TL->newValue($_)->isCharLen( $min, $max ) } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::Email - Emailフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::Email;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isEmail() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::Enum - Enumフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::Enum;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	my @enum = split( /(?<!\\),/, $args );

	foreach (@enum) { $_ =~ s/\\,/,/g }

	return grep {
		my $value = $_;
		( grep { $_ eq $value } @enum ) == 0
	} @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::ExistentDay - ExistentDayフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::ExistentDay;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isExistentDay() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::Gif - Gifフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::Gif;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isGif() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::Hira - Hiraフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::Hira;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isHira() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::HtmlTag - HtmlTagフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::HtmlTag;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isHtmlTag() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::HttpsUrl - HttpsUrlフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::HttpsUrl;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isHttpsUrl() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::HttpUrl - HttpUrlフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::HttpUrl;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	if ( defined($args) && $args eq 's' ) {
		return grep {
			my $value = $TL->newValue($_);
			!( $value->isHttpUrl() || $value->isHttpsUrl() )
		} @$values;
	} else {
		return grep { !$TL->newValue($_)->isHttpUrl() } @$values;
	}
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::Integer - Integerフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::Integer;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	my ( $min, $max ) =
	  defined($args) ? map { $_ ne '' ? $_ : undef } split( ',', $args ) : ();
	return grep { !$TL->newValue($_)->isInteger( $min, $max ) } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::Jpeg - Jpegフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::Jpeg;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isJpeg() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::Kata - Kataフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::Kata;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isKata() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::Len - Lenフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::Len;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	my ( $min, $max ) =
	  defined($args) ? map { $_ ne '' ? $_ : undef } split( ',', $args ) : ();
	return grep { !$TL->newValue($_)->isLen( $min, $max ) } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::MobileEmail - MobileEmailフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::MobileEmail;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isMobileEmail() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::NotEmpty - NotEmptyフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::NotEmpty;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return @$values == 0 || grep { $TL->newValue($_)->isEmpty() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::NotWhitespace - NotWhitespaceフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::NotWhitespace;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { $TL->newValue($_)->isWhitespace() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::Or - Orフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::Or;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	my $form = $TL->newForm( or => $values );
	my @filters =
	  ( $args =~ /((?:\w+)(?:\((?:.*?)\))?(?:\[(?:.*?)\])?)(?:\||$)/g );

	return (
		grep {
			my $validator = $TL->newValidator();
			$validator->addFilter( { or => $_ } );
			defined( $validator->check($form) )
		  } @filters
	) == @filters;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::Password - Passwordフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::Password;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isPassword() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::Png - Pngフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::Png;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isPng() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::PrintableAscii - PrintableAsciiフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::PrintableAscii;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isPrintableAscii() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::Real - Realフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::Real;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	my ( $min, $max ) =
	  defined($args) ? map { $_ ne '' ? $_ : undef } split( ',', $args ) : ();
	return grep { !$TL->newValue($_)->isReal( $min, $max ) } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::RegExp - RegExpフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::RegExp;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	return grep { $TL->newValue($_)->get() !~ /$args/ } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::SjisLen - SjisLenフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::SjisLen;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	my ( $min, $max ) =
	  defined($args) ? map { $_ ne '' ? $_ : undef } split( ',', $args ) : ();
	return grep { !$TL->newValue($_)->isSjisLen( $min, $max ) } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::TelNumber - TelNumberフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::TelNumber;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isTelNumber() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::TrailingSlash - TrailingSlashフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::TrailingSlash;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isTrailingSlash() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::Portable - Portableフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::Portable;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { $TL->newValue($_)->isUnportable() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::Wide - Wideフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::Wide;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isWide() } @$values;
}

# -----------------------------------------------------------------------------
# Tripletail::Validator::Filter::ZipCode - ZipCodeフィルタ
# -----------------------------------------------------------------------------
package Tripletail::Validator::Filter::ZipCode;
use Tripletail;

use base qw{Tripletail::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isZipCode() } @$values;
}

__END__

=encoding utf-8

=head1 NAME

Tripletail::Validator::Filter - Tripletail::Validator フィルタ I/F

=head1 DESCRIPTION

L<Tripletail::Validator> 参照

=head2 METHODS

=over 4

=item doFilter

内部メソッド

=item new

内部メソッド

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
