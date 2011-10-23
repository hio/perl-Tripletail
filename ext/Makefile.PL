use strict;
use warnings;
use ExtUtils::MakeMaker;
use ExtUtils::Liblist;

our %OPTS;

require 'Tripletail-SMIME/openssl_config.PL';
my $OPENSSL = &openssl_config();
&check_openssl();

WriteMakefile(
    NAME                => 'Tripletail-ext',
    %OPTS,
);

sub check_openssl
{
  if( !openssl_is_available() )
  {
    $OPTS{DIR} = ['Tripletail-HtmlFilter'];
  }
}

sub openssl_is_available
{
  my $xstest_src = "openssl_check.c";
  my $xstest_out = "openssl_check";
  $^O eq 'MSWin32' and $xstest_out .= '.exe';
  if( !open(FILE, "> $xstest_src") )
  {
    return;
  }
  print FILE <<XSTEST_CODE;
#include <string.h>
#include <openssl/crypto.h>
#include <openssl/pem.h>
#include <openssl/err.h>
#include <openssl/pkcs12.h>
#include <openssl/x509.h>
int main()
{
  return 0;
}
XSTEST_CODE
  close(FILE);
  
  # compile.
  my %argv = map{ /^(\w+)=(.*)$/ } @ARGV;
  use Config;
  my $cc = exists $argv{CC} ? $argv{CC} : $Config{cc};
  my $ccopts = $argv{CCFLAGS}||$Config{ccflags};
  my $libs = ExtUtils::Liblist->ext($OPENSSL->{LIBS}) || '';
  
  my $cmd = "$cc $ccopts $OPENSSL->{CFLAGS} $xstest_src $libs -o $xstest_out";
  print "Checking XS Compiling... : $cmd\n";
  my $rc = 0xffff & system($cmd);
  unlink($xstest_out);
  unlink($xstest_src);
  unlink("openssl_check.ilk"); # MSVC.
  if( $rc )
  {
    if( $rc == 0xffff )
    {
      print "  >> Here environment cannot use XS.\n";
      print "  >> Because : command failed : $!\n";
      return;
    }elsif( $rc > 0x80 )
    {
      print "  >> Here environment cannot use XS.\n";
      print "  >> Because : ran with non-zero exit status $rc\n";
      return;
    }elsif( $rc & 0x80 )
    {
      $rc &= ~0x80;
      print "  >> Compile failed..\n";
      print "  >> Because : ran with coredump from signal $rc\n";
      exit 1;
    }else
    {
      print "  >> Compile failed..\n";
      print "  >> Because : ran with signal $rc\n";
      exit 1;
    }
  }
  print "  >> ok, compile succeed.\n";
  1;
}

# -----------------------------------------------------------------------------
# End of File.
# -----------------------------------------------------------------------------
