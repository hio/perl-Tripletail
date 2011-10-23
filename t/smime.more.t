
use strict;
use Test::More tests => 13;

BEGIN {
use_ok( 'Tripletail::SMIME' );
}

diag( "Testing Tripletail::SMIME $Tripletail::SMIME::VERSION" );

my $key = &KEY;
my $crt = &CRT;
my $password = '';
my $src_mime = "Content-Type: text/plain\r\n"
             . "Subject: S/MIME test.\r\n"
             . "From: alice\@example.com\r\n"
             . "To:   bob\@example.org\r\n"
             . "\r\n"
             . "test message.\r\n";
my $verify = "Content-Type: text/plain\r\n"
           . "Subject: S/MIME test.\r\n"
           . "\r\n"
           . "test message.\r\n";
my $verify_header = "Subject: S/MIME test.\r\n"
                  . "From: alice\@example.com\r\n"
                  . "To:   bob\@example.org\r\n";
my $signed;
my $encrypted;

{
  # smime-sign.
  my $smime = Tripletail::SMIME->new();
  ok($smime, "new instance of Tripletail::SMIME");
  
  $smime->setPrivateKey($key, $crt, $password);
  $signed = $smime->sign($src_mime); # $src_mimeはMIMEメッセージ文字列
  ok($signed, 'got anything from $smime->sign');
  my @lf = $signed=~/\n/g;
  my @crlf = $signed=~/\r\n/g;
  is(scalar@crlf,scalar@lf,'all \n in signed are part of \r\n');
  #diag($signed);
  
  # prepare/sign-only
  my ($prepared,$header) = $smime->prepareSmimeMessage($src_mime);
  is($prepared,$verify,"prepared mime message");
  is($header,$verify_header,"outer headers of prepared mime message");
  ok(index($signed,$prepared)>=0, 'prepared message is apprers in signed message too');
  ok(index($signed,$header)>=0, 'outer headers of prepared message is apprers in signed message too');
  
  my $signed_only = $smime->signonly($src_mime);
  ok($signed_only, 'got anything from $smime->signonly');
  #diag($signed_only);
  @lf = $signed_only=~/\n/g;
  @crlf = $signed_only=~/\r\n/g;
  is(scalar@crlf,scalar@lf,'all \n in signed_only are part of \r\n');
}

{
  # smime-encrypt.
  my $smime = Tripletail::SMIME->new();
  $smime->setPublicKey($crt);
  $encrypted = $smime->encrypt($signed);
  ok($encrypted, 'got anything from $smime->encrypt');
}

{
  # smime-decrypt.
  my $smime = Tripletail::SMIME->new();
  $smime->setPrivateKey($key, $crt, $password);
  my $decrypted = $smime->decrypt($encrypted);
  ok($decrypted, 'got anything from $smime->decrypt');
  
  # and verify.
  $smime->setPublicKey($crt);
  is($smime->check($decrypted),$verify, 'verify result of decrypt.');
}

# end.

sub CRT
{
  <<EOF;
-----BEGIN CERTIFICATE-----
MIIDgzCCAuygAwIBAgIBADANBgkqhkiG9w0BAQQFADCBjjELMAkGA1UEBhMCSlAx
DjAMBgNVBAgTBVRva3lvMRAwDgYDVQQHEwdTaGlidXlhMRcwFQYDVQQKEw5ZbWly
TGluaywgSW5jLjEMMAoGA1UECxQDUiZEMRcwFQYDVQQDFA5oaW9AeW1pci5jby5q
cDEdMBsGCSqGSIb3DQEJARYOaGlvQHltaXIuY28uanAwHhcNMDUwODA5MDM0ODUz
WhcNMDgxMjMxMDM0ODUzWjCBjjELMAkGA1UEBhMCSlAxDjAMBgNVBAgTBVRva3lv
MRAwDgYDVQQHEwdTaGlidXlhMRcwFQYDVQQKEw5ZbWlyTGluaywgSW5jLjEMMAoG
A1UECxQDUiZEMRcwFQYDVQQDFA5oaW9AeW1pci5jby5qcDEdMBsGCSqGSIb3DQEJ
ARYOaGlvQHltaXIuY28uanAwgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBAM68
pI0XZ7T3gJyTcTYtXJdvWBw4h7MfmfovHH1aD2aAIL/Vid79JT64FCCOf7xFEqRV
CjYz0/MdhrduqE9fBrZh6E5dOK8iP2DEiYMI/Ivo6iyRnVVtl1ya8/nVt0u4648G
O8iNmJNGUfbJUqlucn9Ga373FhdYa1Q6Ks/98msnAgMBAAGjge4wgeswHQYDVR0O
BBYEFOLomzer+1O38qlVKXfbmlYOtVawMIG7BgNVHSMEgbMwgbCAFOLomzer+1O3
8qlVKXfbmlYOtVawoYGUpIGRMIGOMQswCQYDVQQGEwJKUDEOMAwGA1UECBMFVG9r
eW8xEDAOBgNVBAcTB1NoaWJ1eWExFzAVBgNVBAoTDlltaXJMaW5rLCBJbmMuMQww
CgYDVQQLFANSJkQxFzAVBgNVBAMUDmhpb0B5bWlyLmNvLmpwMR0wGwYJKoZIhvcN
AQkBFg5oaW9AeW1pci5jby5qcIIBADAMBgNVHRMEBTADAQH/MA0GCSqGSIb3DQEB
BAUAA4GBAIGjYcQp7VG76bvFEIutubLiFVk1t9TKPZAu+Ni8doPLMK9zFK8VT8qP
Kp0T4CvdAS9MntTU0uQ/H47kaFf/6rTCKcfiQ5rnCQJ2m5cW798RqJPORxU8Ne72
Gq9q8iO3oH6clIexh37NKxHn2xHp3bsNy0U/TS+3WjLv5SHzhy7p
-----END CERTIFICATE-----
EOF
}
sub KEY
{
  <<EOF;
-----BEGIN RSA PRIVATE KEY-----
MIICXQIBAAKBgQDOvKSNF2e094Cck3E2LVyXb1gcOIezH5n6Lxx9Wg9mgCC/1Yne
/SU+uBQgjn+8RRKkVQo2M9PzHYa3bqhPXwa2YehOXTivIj9gxImDCPyL6OoskZ1V
bZdcmvP51bdLuOuPBjvIjZiTRlH2yVKpbnJ/Rmt+9xYXWGtUOirP/fJrJwIDAQAB
AoGAJ4d0YzHtd3G3mriqdfR4dtAoZcT9VWeednLZnLJCrZOkL2nyIbv/ih2CY7M7
g1ElvlwwRqrkROEJaDt1XS/LRW3Ciwy2HOZ7swOO88fm9jXNimYiF9dpW6mAIkzo
enewaaFLnZReZe4772gFtVgEHq9k2TZBBsAU5T2JaDJYeiECQQD/IP3vvCh87PWN
qkwcUYin369shD35yHvunNTWMELhb4HyP46xD0kGrqALtaPHi2UCNDYYvrG08DF6
IN2tmOcRAkEAz3FZ9oXpNITzaVVEzIm16dVOokyipcYxk4Xe18wESFazIjgwTQVK
PFTLniZca8VRjuULUBZJ5LLcQpbqFf1etwJBAIpme1rx14Tthsey+lbiZB+tWJyl
oHlAKProWQ1YYO+qbfPcRqwGfrcBRBEWGCLHm6P2buI9kGl3Y1+9NIRXzgECQD+X
9Udg+AQUufZRoJy/ntgHf2q76aS+ZJZgFNe9AJcYlSPpa81A0Og76owaIH0daYpP
5y7vFkoZFvMHBs4k9XMCQQCQyuSIm4HxBbgsnnRli7XRfltPQvpCoMvI+jz9eMZC
6BNQfc6wyG/j00DIXNQkZ+6WfxHJXwlyMrG9wEf+oJxm
-----END RSA PRIVATE KEY-----
EOF
}

