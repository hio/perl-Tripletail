# -----------------------------------------------------------------------------
# Tripletail::Sendmail::Sendmail - Sendmailメール送信
# -----------------------------------------------------------------------------
package Tripletail::Sendmail::Sendmail;
use strict;
use warnings;
use Tripletail;
use IO::Socket::INET;
require Tripletail::Sendmail;
our @ISA = qw(Tripletail::Sendmail);

1;

sub _new {
	my $class = shift;
	my $group = shift;
	my $this = bless {} => $class;

	$this->{group} = $group;
	$this->{log} = $TL->INI->get($group => 'logging');
	$this->{commandline} = $TL->INI->get($group => 'commandline', '/usr/sbin/sendmail -t -i');

	$this;
}

sub send {
	my $this = shift;
	my $data = $this->_getoptSend(@_);

	open my $sendmail, '|' . $this->{commandline}
	  or die __PACKAGE__."#send: failed to execute the sendmail command. [$this->{commandline}] (sendmailコマンドを使用できません)\n";
	
	my $senddata = $data->{data};
	$senddata =~ tr/\r//d;
	
	print $sendmail $senddata;

	$this;
}


__END__

=encoding utf-8

=head1 NAME

Tripletail::Sendmail::Sendmail - Sendmailメール送信

=head1 DESCRIPTION

sendmailコマンドを利用してメールを送信する。

=head2 METHODS

=over 4

=item new

=item send

  $smail->send(-data => $data)
  $smail->send(-data => $data)

宛先は-dataのヘッダからsendmailが抽出し、送信する。

=back


=head2 Ini パラメータ

=over 4

=item commandline

  commandline = /usr/sbin/sendmail -t -i

sendmailコマンドを指定する。オプションも同時に指定する。

ヘッダから送信先を取り出す「-t」オプションと、EOFでメールの終端を認識する「-i」オプションの指定は必須となる。

デフォルトは「/usr/sbin/sendmail -t -i」

=back


=head1 SEE ALSO

=over 4

=item L<Tripletail>

=item L<Tripletail::Sendmail>

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
