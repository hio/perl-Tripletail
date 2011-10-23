# -----------------------------------------------------------------------------
# $Id: openssl_config.PL,v 1.1 2006/08/17 10:04:00 hio Exp $
# -----------------------------------------------------------------------------
use strict;
1;

sub openssl_config
{
  my $OPENSSL = shift;
  $OPENSSL ||=
  {
    LIBS   => $ENV{LDFLAGS} || '',
    CFLAGS => $ENV{CFLAGS}  || '',
  };
  
  if( $^O eq 'MSWin32' )
  {
    _openssl_config_win32($OPENSSL);
  }else
  {
    $OPENSSL->{LIBS} .= " -lcrypto";
  }
  
  $OPENSSL->{LIBS} =~ s/^ +//;
  $OPENSSL;
}

sub _openssl_config_win32
{
  my $OPENSSL = shift;
  
  my $openssl_path='c:/openssl';
  if( -e $openssl_path && -x "$openssl_path/bin/openssl.exe" )
  {
    $OPENSSL->{CFLAGS} .= " -I$openssl_path/include";
    use Config;
    if( -e "$openssl_path/lib/vc" && $Config{cc} eq 'cl' && $Config{ccflags}=~/-(M[DLT])\b/ )
    {
      $OPENSSL->{LIBS}   .= " -L$openssl_path/lib/vc -lssleay32$1 -llibeay32$1";
    }else
    {
      $OPENSSL->{LIBS}   .= " -L$openssl_path/lib -lssleay32 -llibeay32";
    }
    return;
  }
}

# -----------------------------------------------------------------------------
# End of File.
# -----------------------------------------------------------------------------
