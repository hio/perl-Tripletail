# -----------------------------------------------------------------------------
# Tripletail::Ini - 設定ファイルを読み書きする
# -----------------------------------------------------------------------------
package Tripletail::Ini;
use strict;
use warnings;
our $TL;

1;

sub _new {
	my $pkg = shift;
	my $this = {};
	bless $this, $pkg;

	$this->{filename} = undef;
	$this->{ini} = {};

	if(scalar(@_)) {
		$this->read(@_);
	}

	$this;
}

sub const {
	my $this = shift;
	$this->{const} = 1;
	$this;
}

sub read {
	my $this = shift;
	my $filename = shift;

	%{$this->{ini}} = ();

	my $fh = $TL->_gensym;
	if(!open($fh, "$filename")) {
		die "Tripletail::Ini#read, can't open file for read. [$filename] ($!)\n";
	}

	binmode($fh);
	flock($fh, 1);
	seek($fh, 0, 0);
	my $group = '';
	while(<$fh>) {
		next if(m/^#/);
		s/^\s+//;
		s/\s+$//;
		next if(m/^$/);
		if(m/^\[(.+)\]$/) {
			$group = $1;
		} else {
			my ($key, $value) = split(/\s*=\s*/, $_, 2);
			if(defined($group) && defined($key) && defined ($value)) {
				if(!exists($this->{ini}{$group}{$key})) {
					$this->{ini}{$group}{$key} = $value;
				}
			} else {
				die "Tripletail::Ini#read, ini data format error. line [$.]\n";
			}
		}
	}
	close($fh);

	$this->{filename} = $filename;
	$this;
}

sub write {
	my $this = shift;
	my $filename = shift;

	my $fh = $TL->_gensym;
	if(!open($fh, ">$filename")) {
		die "Tripletail::Ini#write, can't open file for write. [$filename] ($!)\n";
	}

	binmode($fh);
	flock($fh, 2);
	seek($fh, 0, 0);
	foreach my $group (keys %{$this->{ini}}) {
		print $fh "[$group]\n";
		foreach my $key (keys %{$this->{ini}{$group}}) {
			print $fh "$key = " . $this->{ini}{$group}{$key} . "\n";
		}
		print $fh "\n";
	}
	close($fh);

	$this;
}

sub existsGroup {
	my $this = shift;
	my $group = shift;
	my $raw = shift;

	if(!defined($group)) {
		die "Tripletail::Ini#existsGroup, ARG[1]: got undef.\n";
	} elsif(ref($group)) {
		die "Tripletail::Ini#existsGroup, ARG[1]: got Ref.[$group]\n";
	}

	$group = ($this->_getrawgroupname($group))[0] if(!$raw);

	return 0 if(!defined($group));

	if(exists($this->{ini}{$group})) {
		return 1;
	} else {
		return 0;
	}
}

sub existsKey {
	my $this = shift;
	my $group = shift;
	my $key = shift;
	my $raw = shift;

	if(!defined($group)) {
		die "Tripletail::Ini#existsKey, ARG[1]: got undef.\n";
	} elsif(ref($group)) {
		die "Tripletail::Ini#existsKey, ARG[1]: got Ref.[$group]\n";
	}
	if(!defined($key)) {
		die "Tripletail::Ini#existsKey, ARG[2]: got undef.\n";
	} elsif(ref($key)) {
		die "Tripletail::Ini#existsKey, ARG[2]: got Ref.[$key]\n";
	}

	my @group;
	if($raw) {
		push(@group,$group);
	} else {
		@group = $this->_getrawgroupname($group);
	}

	foreach my $groupname (@group) {
		if(exists($this->{ini}{$groupname}{$key})) {
			return 1;
		}
	}

	undef;
}

sub getGroups {
	my $this = shift;
	my $raw = shift;
	
	if($raw) {
		keys %{$this->{ini}};
	} else {
		my $groups;
		foreach my $group (keys %{$this->{ini}}) {
			$group =~ /^([^:]+)/;
			foreach my $groupname ($this->_getrawgroupname($1)) {
				$groupname =~ /^([^:]+)/;
				$groups->{$1} = 1;
			}
		}
		keys %{$groups};
	}
}

sub getKeys {
	my $this = shift;
	my $group = shift;
	my $raw = shift;

	if(!defined($group)) {
		die "Tripletail::Ini#getKeys, ARG[1]: got undef.\n";
	} elsif(ref($group)) {
		die "Tripletail::Ini#getKeys, ARG[1]: got Ref.[$group]\n";
	}

	my @group;
	if($raw) {
		push(@group,$group);
	} else {
		@group = $this->_getrawgroupname($group);
	}

	my @result;
	my %occurence;
	foreach my $groupname (@group) {
		if(my $grp = $this->{ini}{$groupname}) {
			foreach my $key (keys %$grp) {
				if(!$occurence{$key}) {
					push(@result,$key);
					$occurence{$key} = 1;
				}
			}
		}
	}

	@result;
}

sub get {
	my $this = shift;
	my $group = shift;
	my $key = shift;
	my $default = shift;
	my $raw = shift;

	if(!defined($group)) {
		die "Tripletail::Ini#get, ARG[1]: got undef.\n";
	} elsif(ref($group)) {
		die "Tripletail::Ini#get, ARG[1]: got Ref.[$group]\n";
	}
	if(!defined($key)) {
		die "Tripletail::Ini#get, ARG[2]: got undef.\n";
	} elsif(ref($key)) {
		die "Tripletail::Ini#get, ARG[2]: got Ref.[$key]\n";
	}

	my @group;
	if($raw) {
		push(@group,$group);
	} else {
		@group = $this->_getrawgroupname($group);
	}

	my $result;
	foreach my $groupname (@group) {
		if(exists($this->{ini}{$groupname}) && exists($this->{ini}{$groupname}{$key})) {
			$result = $this->{ini}{$groupname}{$key};
			last;
		}
	}

	if(!defined($result)) {
		$result = $default;
	}

	$result;
}

sub set {
	my $this = shift;
	my $group = shift;
	my $key = shift;
	my $value = shift;

	if(exists($this->{const})) {
		die "Tripletail::Ini#set, This instance is const object.\n";
	}

	if(!defined($group)) {
		die "Tripletail::Ini#set, ARG[1]: got undef.\n";
	} elsif(ref($group)) {
		die "Tripletail::Ini#set, ARG[1]: got Ref.[$group]\n";
	}
	if(!defined($key)) {
		die "Tripletail::Ini#set, ARG[2]: got undef.\n";
	} elsif(ref($key)) {
		die "Tripletail::Ini#set, ARG[2]: got Ref.[$key]\n";
	}
	if(!defined($value)) {
		die "Tripletail::Ini#set, ARG[3]: got undef.\n";
	} elsif(ref($value)) {
		die "Tripletail::Ini#set, ARG[3]: got Ref.[$value]\n";
	}
	if($group =~ m/[\x00-\x1f]/) {
		die "Tripletail::Ini#set, ARG[1]: contains control code.\n";
	}
	if($key =~ m/[\x00-\x1f]/) {
		die "Tripletail::Ini#set, ARG[2]: contains control code.\n";
	}
	if($value =~ m/[\x00-\x1f]/) {
		die "Tripletail::Ini#set, ARG[3]: contains control code.\n";
	}
	if($group =~ m/^\s+/ or $group =~ m/\s+$/) {
		die "Tripletail::Ini#set, ARG[1]: space will be delete.\n";
	}
	if($key =~ m/^\s+/ or $key =~ m/\s+$/) {
		die "Tripletail::Ini#set, ARG[2]: space will be delete.\n";
	}
	if($value =~ m/^\s+/ or $value =~ m/\s+$/) {
		die "Tripletail::Ini#set, ARG[3]: space will be delete.\n";
	}

	$this->{ini}{$group}{$key} = $value;

	$this;
}

sub delete {
	my $this = shift;
	my $group = shift;
	my $key = shift;
	my $raw = shift;

	if(exists($this->{const})) {
		die "Tripletail::Ini#delete, This instance is const object.\n";
	}

	if(!defined($group)) {
		die "Tripletail::Ini#delete, ARG[1]: got undef.\n";
	} elsif(ref($group)) {
		die "Tripletail::Ini#delete, ARG[1]: got Ref.[$group]\n";
	}
	if(!defined($key)) {
		die "Tripletail::Ini#delete, ARG[2]: got undef.\n";
	} elsif(ref($key)) {
		die "Tripletail::Ini#delete, ARG[2]: got Ref.[$key]\n";
	}

	my @group;
	if($raw) {
		push(@group,$group);
	} else {
		@group = $this->_getrawgroupname($group);
	}

	foreach my $groupname (@group) {
		delete $this->{ini}{$groupname}{$key};
	}


	$this;
}

sub deleteGroup {
	my $this = shift;
	my $group = shift;
	my $raw = shift;

	if(exists($this->{const})) {
		die "Tripletail::Ini#delete, This instance is const object.\n";
	}

	if(!defined($group)) {
		die "Tripletail::Ini#delete, ARG[1]: got undef.\n";
	} elsif(ref($group)) {
		die "Tripletail::Ini#delete, ARG[1]: got Ref.[$group]\n";
	}

	$group = $this->_getrawgroupname($group) if(!$raw);

	delete $this->{ini}{$group};

	$this;
}

sub _filename {
	my $this = shift;
	$this->{filename};
}

#特化指定やIPアドレス指定に適合しているグループを全て返す
sub _getrawgroupname {
	my $this = shift;
	my $group = shift;
	
	my @group;
	foreach my $spec (@Tripletail::specialization, '') {
		my $groupname = (length $spec ? "$group:$spec" : $group);
		foreach my $rawgroup ($this->getGroups(1)) {
			if($rawgroup =~ m/^([^\@]+)/) {
				next if($groupname ne $1);
				my $matchflag = 1;
				if($rawgroup =~ m/\@server:([^\@:]+)/){
					$matchflag = 0;
					my $servermask = $this->get('HOST' => $1,undef,1);
					if(defined($servermask)) {
						my $server = $ENV{SERVER_ADDR};
						if(!defined($server)){
							$server = `hostname -i 2>&1`;
							$server = $server && $server =~ /^\s*([0-9.]+)\s*$/ ? $1 : undef;
						}
						if(defined($server)) {
							if($TL->newValue->set($server)->isIpAddress($servermask)) {
								$matchflag = 1;
							}
						}
					}
				}
				if($matchflag == 1 && $rawgroup =~ m/\@remote:([^\@:]+)/){
					$matchflag = 0;
					my $remotemask = $this->get('HOST' => $1,undef,1);
					if(defined($remotemask)) {
						if(my $remote = $ENV{REMOTE_ADDR}) {
							if($TL->newValue->set($remote)->isIpAddress($remotemask)) {
								$matchflag = 1;
							}
						}
					}
				}
				if($matchflag == 1) {
					push(@group,$rawgroup);
				}
			}
		}
	}
	@group;
}


__END__

=encoding utf-8

=head1 NAME

Tripletail::Ini - 設定ファイルを読み書きする

=head1 SYNOPSIS

  my $ini = $TL->newIni('foo.ini');
  
  print $ini->get(Group1 => 'Key1');
  
  $ini->set(Group2 => 'Key1' => 'value');
  $ini->write('bar.ini');

=head1 DESCRIPTION

以下のような設定ファイルを読み書きする。

  [HOST]
  Debughost = 192.168.10.0/24
  Testuser = 192.168.11.5 192.168.11.50
  [TL@server:Debughost]
  logdir = /home/tl/logs
  errormail = tl@example.org
  [TL:regist@server:Debughost]
  logdir = /home/tl/logs/regist
  [TL]
  logdir = /home/tl/logs
  errormail = tl@example.org
  [TL:regist]
  logdir = /home/tl/logs/regist
  [Debug@remote:Testuser]
  enable_debug=1
  [Group]
  Key=Value
  [DB]
  Type=MySQL
  host=1.2.3.4
  [Cookie]
  expire=30day
  domain=.ymir.jp
  [Smtp]
  host=localhost

=over 4

=item TLのuse及び特化指定も参照する事

=item グループ名には "[" "]" 制御文字(0x00-0x20,0x7f,0x80-0x9f,0xff) 以外の半角英数字が使用可能。

=item グループ名の"@" ":"は特化指定用の文字となる為、任意の項目への使用は出来ない。

=item 空行は無視

=item # で始まる行はコメント

=item 連続行は対応しない

=item 同一グループ名は一つのグループとして扱われる

=item 同一項目は最初に書かれた物が有効

=item 特化指定は グループ名:名称@server:Servermask@remote:Remotemask の順番で記述する必要性がある

=item 適合する特化指定が複数存在する場合、最初に存在する物が有効となる

=item 特化指定が存在する場合、特化指定無しは常に最後に利用される

=item 初期にC<use>で指定されるiniファイル以外のiniファイルにもC<use>で指定した特化指定が有効となる

=item HOSTグループには、特化指定は使用できない

=back


=head2 METHODS

=over 4

=item C<< $TL->newIni >>

  $TL->newIni
  $TL->newIni($filename)

Tripletail::Ini オブジェクトを作成。
設定ファイルを指定してあればreadメソッドで読み込む。

=item C<< read >>

  $ini->read($filename)

指定した設定ファイルを読み込む。

=item C<< write >>

  $ini->write($filename)

指定した設定ファイルに書き込む。
自動的に読み込まれる$INIに関しては書き込みは出来ない。

=item C<< existsGroup >>

  $bool = $ini->existsGroup($group, $raw)

グループの存在を確認する。存在すれば1、しなければundefを返す。
$rawに1を指定した場合、特化指定を含んだグループ文字列で存在を確認する。

=item C<< existsKey >>

  $bool = $ini->existsKey($group => $key, $raw)

指定グループのキーの存在を確認する。存在すれば1、しなければundefを返す。
$rawに1を指定した場合、特化指定を含んだグループ文字列で存在を確認する。

=item C<< getGroups >>
  
  @groups = $ini->getGroups($raw)

グループ一覧を配列で返す。
$rawに1を指定した場合、特化指定を含んだグループ文字列で一覧を返す。

=item C<< getKeys >>

  @keys = $ini->getKeys($group, $raw)

グループのキー一覧を配列で返す。グループがなければ空配列を返す。
$rawに1を指定した場合、特化指定を含んだグループ文字列で確認し一覧を返す。

=item C<< get >>

  $val = $ini->get($group => $key, $default, $raw)

指定されたグループ・キーの値を返す。グループorキーがなければ$defaultで指定された値を返す。
$defaultが指定されなかった場合は、undefを返す。
$rawに1を指定した場合、特化指定を含んだグループ文字列で確認し値を返す。

=item C<< set >>

  $ini->set($group => $key => $value)

指定されたグループ・キーの値を設定する。グループがなければ作成される。

=item C<< const >>

  $ini->const

このメソッドを呼び出すと、以後データの変更は不可能となる。

=item C<< delete >>

  $ini->delete($group => $key, $raw)

指定されたグループ・キーの値を削除する。
$rawに1を指定した場合、特化指定を含んだグループ文字列で確認し削除する。

=item C<< deleteGroup >>

  $ini->deleteGroup($group, $raw)

指定されたグループを削除する。
$rawに1を指定した場合、特化指定を含んだグループ文字列で確認し削除する。

=back


=head1 SEE ALSO

L<Tripletail>

=head1 AUTHOR INFORMATION

=over 4

Copyright 2006 YMIRLINK Inc. All Rights Reserved.

This framework is free software; you can redistribute it and/or modify it under the same terms as Perl itself

このフレームワークはフリーソフトウェアです。あなたは Perl と同じライセンスの 元で再配布及び変更を行うことが出来ます。

Address bug reports and comments to: tl@tripletail.jp

HP : http://tripletail.jp/

=back

=cut
