# -----------------------------------------------------------------------------
# Tripletail::Template - テンプレートを扱う
# -----------------------------------------------------------------------------
package Tripletail::Template;
use Tripletail;
use strict;
use warnings;
require Tripletail::Template::Node;
require File::Spec;

1;

sub _new {
	my $class = shift;
	my $this = bless {} => $class;

	$this->{root} = Tripletail::Template::Node->_new;

	$this->{basepath} = $TL->INI->get('Template' => 'basepath', '.');
	$this->{rootpath} = $TL->INI->get('Template' => 'rootpath', '/');

	$TL->getDebug->_templateLog(
		node => $this->{root},
		type => 'new'
	);

	if(defined($_[0])) {
		$this->loadTemplate(@_);
	}

	$this;
}

sub _checkPath {
	my $this = shift;
	my $path = shift;

	# rootpathチェック
	my @rootpath = File::Spec->splitdir(
		File::Spec->canonpath($this->{rootpath})
	);
	length $rootpath[-1] or pop @rootpath;

	$path = File::Spec->canonpath($path);
	my @path = File::Spec->splitdir($path);

	my @abspath;
	foreach my $dir (@path) {
		if($dir eq '..') {
			pop(@abspath);
			next;
		}
		push(@abspath, $dir);
	}

	for(my $i = 0; $i < @rootpath; $i++) {
		if($rootpath[$i] ne $abspath[$i]) {
			die __PACKAGE__."#_checkPath, loading file [$path] was forbidden ".
				"due to rootpath being [$this->{rootpath}]\n";
		}
	}

	$path;
}

sub _expandInclude {
	my $this = shift;
	my $inccount = shift;
	my $str = shift;
	my $path = shift;

	$$inccount += 1;
	if($$inccount > 20) {
		die __PACKAGE__."#_expandInclude, <!include> file was loop or too deep.\n";
	}

	if(!defined($path)) {
		$path = $this->{basepath};
		$path .= '/' if($path !~ m,/$,);
	}

	my $basedir = $path;
	$basedir  =~ s,[^/]+$,,;

	# <!include>を処理
	$str =~ s{<!include:(.+?)>}{
		my $filepath = $1;
		$filepath = File::Spec->rel2abs($filepath, $basedir);
		$filepath = $this->_checkPath($filepath);
		$this->{loadfile}{$filepath} = 1;
		my $includestr = $TL->readTextFile($filepath);
		$includestr = $this->_expandInclude($inccount, $includestr, $filepath);
		$includestr
	}eg;

	$str;
}

sub setTemplate {
	my $this  = shift;
	my $str = shift;

	if(!defined($str)) {
		die __PACKAGE__."#setTemplate, ARG[1] was undef.\n";
	} elsif(ref($str)) {
		die __PACKAGE__."#setTemplate, ARG[1] was Ref.\n";
	}

	my $inccount = 0;
	$str = $this->_expandInclude(\$inccount, $str);

	$this->{root}->_setTemplate($str);


	$TL->getDebug->_templateLog(
		node => $this->{root},
		type => 'set'
	);

	$this;
}

sub loadTemplate {
	my $this  = shift;
	my $filepath = shift;
	my $icode = shift;

	if(!defined($filepath)) {
		die __PACKAGE__."#loadTemplate, ARG[1] was undef.\n";
	} elsif(ref($filepath)) {
		die __PACKAGE__."#loadTemplate, ARG[1] was Ref.\n";
	}

	$filepath = File::Spec->rel2abs($filepath, $this->{basepath});

	$filepath = $this->_checkPath($filepath);
	$this->_checkPath($filepath);

	my $str = $TL->readTextFile($filepath, $icode);
	my $inccount = 0;
	$str = $this->_expandInclude(\$inccount, $str, $filepath);

	$this->{root}->_setTemplate($str);

	$TL->getDebug->_templateLog(
		node => $this->{root},
		type => 'load'
	);

	$this;
}

sub DESTROY {
	my $this = shift;

	defined $this->{root} and
	  $this->{root}->_finalize;
	$this->{root} = undef;
}

sub isRoot {
	my $this = shift;

	$this->{root}->isRoot(@_);
}

sub getHtml {
	my $this = shift;

	$this->{root}->getHtml(@_);
}

sub setHtml {
	my $this = shift;

	$this->{root}->setHtml(@_);
	$this;
}

sub isXHTML {
	my $this = shift;

	$this->{root}->isXHTML(@_);
}

sub node {
	my $this = shift;

	$this->{root}->node(@_);
}

sub exists {
	my $this = shift;

	$this->{root}->exists(@_);
}

sub setAttr {
	my $this = shift;

	$this->{root}->setAttr(@_);
	$this;
}

sub expand {
	my $this = shift;

	$this->{root}->expand(@_);
	$this;
}

sub expandAny {
	my $this = shift;

	$this->{root}->expandAny(@_);
	$this;
}

sub toStr {
	my $this = shift;

	$this->{root}->toStr(@_);
}

sub getForm {
	my $this = shift;

	$this->{root}->getForm(@_);
}

sub setForm {
	my $this = shift;

	$this->{root}->setForm(@_);
	$this;
}

sub extForm {
	my $this = shift;

	$this->{root}->extForm(@_);
	$this;
}

sub addHiddenForm {
	my $this = shift;

	$this->{root}->addHiddenForm(@_);
	$this;
}

sub flush {
	my $this = shift;

	$this->{root}->flush(@_);
	$this;
}

sub addSessionCheck {
	my $this = shift;

	$this->{root}->addSessionCheck(@_);
	$this;
}

__END__

=encoding utf-8

=head1 NAME

Tripletail::Template - テンプレート

=head1 SYNOPSIS

  my $t = $TL->newTemplate
    ->setTemplate(qq{
	<html>
	  <title><&TITLE></title>
	  
	  <!begin:LOOP>
	    <&LINE><br>
	  <!end:LOOP>
	</html>
      });

  $t->expandAny(TITLE => 'Title');
  
  $t->node('LOOP')->add(LINE => 'line 1');
  $t->node('LOOP')->add(LINE => 'line 2');
  
  my $str = $t->toStr;
  
  # $str:
  # <html>
  #   <title>Title</title>
  #
  #
  #     line 1<br>
  #
  #     line 2<br>
  #
  # </html>

=head1 DESCRIPTION

コードとデザインを分離するためのテンプレートを扱うクラスです。

HTMLやメールの原稿をテンプレートとしてプログラム外部に
用意し、コードとデザインを分離するようにします。

=head2 テンプレート書式

=over 4

=item ブロックタグ

  <!begin:????> .... <!end:????>

beginとendで囲まれた部分をノードとします。
???? 部分は、同じ階層のノードでユニークでなければなりません。
また、begin/end が交差したり、対応が取れていないことが無いよ
うに注意しなければなりません。 

ノードとして指定されたブロックに対しては、node メソッドを使用
してアクセスすることが出来ます。
また、Template::Node クラスの add メソッドを呼ぶことで、ノード
を繰り返して展開することが可能です。

=item 展開タグ

  <&????>

expand/add メソッドで、文字列を展開する場所を指定します。

=item Includeタグ

  <!include:????>

タグのある場所に、指定されたファイルを読み込み、展開します。
ファイルは、最後に loadTemplate したファイル名のディレクトリ
からの相対パスとして扱われます。
loadTemplate が呼ばれていない場合は、カレントディレクトリから
の相対パスとして扱われます。 

Includeタグはネストして使用可能ですが、自分自身を読み込むと
永久ループすることになるので使用には注意が必要です。


=item コピータグ

  <!copy:????>

????は既存のノード名を指します。
<!begin:????> .... <!end:????> で囲まれた部分のコピーを別の
場所に展開します。
<!copy:????> タグは、<!begin:????> .... <!end:????> と同じ
階層に存在し、かつコピー元のブロックより後ろに位置しなければ
なりません。 

ただし、"flush" を使用しない場合は、コピー元のブロックより
手前にあっても問題ありません。

=back


=head2 METHODS

=over 4

=item $TL->newTemplate

  $t = $TL->newTemplate
  $t = $TL->newTemplate($filepath)
  $t = $TL->newTemplate($filepath, $icode)
  $t = $TL->newTemplate($filepath, $icode, $prefer_encode)

Tripletail::Template オブジェクトを作成。
引数があれば、その引数で loadTemplate が実行される。

=item loadTemplate

  $t->loadTemplate($filepath)
  $t->loadTemplate($filepath, $icode)
  $t->loadTemplate($filepath, $icode, $prefer_encode)

指定されたファイルをテンプレートとして読み込む。

$icode が省略された場合は 'auto' 文字コード自動判別となる。
指定できる文字コードは、UTF-8，Shift_JIS，EUC-JP，ISO-2022-JP。

$prefer_encode を真にすると Encode が利用可能な場合は Encode で変換する。

=item setTemplate

  $t->setTemplate($str)

指定された文字列をテンプレートとしてセットする。

=item node

  $child = $t->node($nodename)

指定されたノード名のノードオブジェクトを返す。
存在しないノード名が要求されたらエラー。

通常のTripletail::Templateオブジェクトとノードオブジェクトの違いは次の通り。

=over 8

=item loadTemplateメソッド利用不可能

=item addメソッド利用可能

=back

=item exists

  $t->exists($nodename)

指定された名前を持つノードが存在するなら1を、しないならundefを返す。

=item setAttr

  $t->setAttr(\%hash)
  $t->setAttr(%hash)

expand/addメソッドで渡すデータの展開方法を指定する。
指定がないものは plain 指定とみなす。

=over 8

=item plain または指定無し

L<< $TL->escapeTag|Tripletail/"escapeTag" >> を適用後、出力する

=item br

L<< $TL->escapeTag|Tripletail/"escapeTag" >> を適用後、
改行の前に E<lt>brE<gt> もしくは E<lt>br /E<gt> を挿入し、出力する。

=item raw

そのまま出力する

=item js

L<< $TL->escapeJs|Tripletail/"escapeJs" >> を適用後、出力する


=back

=item expand

  $t->expand(\%hash)
  $t->expand(%hash)

指定されたハッシュのデータを元に、展開タグを展開する。

渡されたハッシュのキーの中に、展開タグが存在しないものがあっても
エラーにはならない。
一回のexpandの呼び出しで未展開のタグが残った場合はエラーとなる。

=item expandAny

  $t->expandAny(\%hash)
  $t->expandAny(%hash)

expandと同様だが、テンプレートに未展開のタグがあってもエラーとしない。
但し、toStrを行うまでには全てのタグを展開する必要性がある。

=item add

  $t->node('foo')->add
  $t->node('foo')->add(\%hash)
  $t->node('foo')->add(%hash)

このメソッドはノードオブジェクトでのみ利用可能。

子ノードを親ノードに挿入する。
このメソッドが呼ばれた後は、子ノードは展開前の状態に戻る。

引数が指定された場合は親ノードへの挿入前に expand される。

=item getForm

  $form = $t->getForm($name)

HTMLテンプレート中のフォームを解析し、中にセットされている
データを L<Tripletail::Form> オブジェクトの形式で取り出す。

引数はフォームの name="..." で指定される名前。
省略された場合は、name属性の存在しないform要素が取り出される。

=item setForm

  $t->setForm($form)
  $t->setForm($form, $name)
  $t->setForm($hashref)
  $t->setForm($hashref, $name)

渡された L<Tripletail::Form> オブジェクトを、HTMLテンプレート中のフォームに
展開する。

L<Tripletail::Form>オブジェクトの代わりにハッシュのリファレンスを渡すことも出来る。
ハッシュのリファレンスを渡した場合は、$TL->newForm($hashref) した結果のフォームオブジェクトをセットする。

第2引数はフォームの name="..." で指定される名前。
省略された場合は、name属性の存在しないform要素が対象となる。

テンプレートに存在し、フォームオブジェクトに存在しない
キーがあったり、その逆の状態のキーが存在しても、
エラー等は発生しない。

テンプレートに存在して、フォームオブジェクトに存在
しないキーの関しては、テンプレートの元のデータが
保存される。

=item extForm

  $t->extForm
  $t->extForm($name)

HTMLテンプレート中のフォームが外部アプリケーションに対するものであることを指定する。

第1引数はフォームの name="..." で指定される名前。
省略された場合は、name属性の存在しないform要素が対象となる。

通常のフォームはTLフレームワークに対するものとして、いくつかの操作が行われるが、
extForm を行った場合はそれらの操作を行わない。

=item addHiddenForm

  $t->addHiddenForm($form)
  $t->addHiddenForm($form, $name)
  $t->addHiddenForm($hashref)
  $t->addHiddenForm($hashref, $name)

渡された L<Tripletail::Form> オブジェクトを、HTMLテンプレート中のフォームに
E<lt>input type="hidden"E<gt> 要素として追加する。

L<Tripletail::Form>オブジェクトの代わりにハッシュのリファレンスを渡すことも出来る。
ハッシュのリファレンスを渡した場合は、$TL->newForm($hashref) した結果のフォームオブジェクトを追加する。

第2引数はフォームの name="..." で指定される名前。
省略された場合は、name属性の存在しないform要素が対象となる。

渡されたフォームデータの全てのキーがhiddenとして追加される。
既存の値に上書きはされず、 単純に追加される。

=item addSessionCheck

  $t->addSessionCheck($sessiongroup)
  $t->addSessionCheck($sessiongroup, $name)
  $t->addSessionCheck($sessiongroup, $name, $issecure)

指定したセッショングループのセッションIDを利用したキーをフォームに埋め込む。
埋め込むフォームはPOSTメソッドでなければエラーとなる。
また、事前にセッションIDを発行（SessionクラスのsetValue）してなければエラーとなる。
$CGI->haveSessionCheck とペアで使用する。

指定したセッショングループのIniで設定するcsrfkeyを必要とする。未設定の場合エラーとなる。
csrfkeyとセッションIDを利用してキーを作成する為、csrfkeyはサイト毎に違う値を用い、外部に漏れないようにする事。

第2引数はフォームの name="..." で指定される名前。
省略もしくはundefが指定された場合は、name属性の存在しないform要素が対象となる。

使用中のセッションの mode が 'double' の場合は、
第3引数に 0 または 1 を指定すると、http側、https側を指定できる。
省略した場合は、そのときの通信が http/https のどちらであるかによって選択される。

=item getHtml

  $html = $t->getHtml

特定のノードの現在の内容を返す。置換済みのタグは置換されており、未置換
のタグは未置換のまま残っている。

=item setHtml

  $t->setHtml($html)

特定のノードの現在の内容を変更する。L</getHtml> と逆の働きをする。

=item flush

  $t->flush

ノードの場合、そのノードの終端までを L<出力|Tripletail/"print"> する。
Templateの場合、全体を出力する。

テンプレートの最初から順にflushしていかないと、テンプレートの
一部分が重複出力されるので注意が必要。

=item toStr

  $str = $t->toStr

テンプレート(展開結果)を文字列として返す。

=item isRoot

  $is_root = $t->isRoot

ノードの場合は undef を返し、Template の場合は 1 を返す。

=item isXHTML

  $is_xhtml = $t->isXHTML

テンプレートが XHTML のように見える場合は 1 を、そうでない場合は undef
を返す。厳密なチェックは行わない。

=back


=head2 Ini パラメータ

グループ名は "Template" でなければならない。

例:

  [Template]
  basepath = /home/www/template/

=over 4

=item basepath

  basepath = /home/www/template/

相対パス指定時に基準となるパス。省略可能。

デフォルトは "." 。
すなわちカレントディレクトリ。

=item rootpath

  rootpath = /home/www/

特定のディレクトリ階層よりも下位にあるファイルのみ、
アクセスを許可する場合に指定する。省略可能。

デフォルトは "/"。
すなわち全ファイルをテンプレートとして使用許可。

=back


=head2 flush サンプル

=head3 ソースコード

 $TL->setContentFilter('Tripletail::Filter::Binary');
 
 my $t = $TL->newTemplate->setTemplate(
 qq{This is a header.
 
 <!begin:AAA>
   node AAA begins...
 
   <!begin:BBB>
     node BBB begins...
 
       <!begin:CCC>
       value of node CCC: <&val>
       <!end:CCC>
 
     node BBB ends...
   <!end:BBB>
 <!end:AAA>
 
 This is a footer.
 });
 
 print "\n#--- node('CCC')->add; (twice)\n";
 $t->node('AAA')->node('BBB')->node('CCC')->add(
     val => 100,
    );
 $t->node('AAA')->node('BBB')->node('CCC')->add(
     val => 200,
    );
 
 print "\n#--- node('CCC')->flush;\n";
 $t->node('AAA')->node('BBB')->node('CCC')->flush;
 
 print "\n#--- node('BBB')->add;\n";
 $t->node('AAA')->node('BBB')->add;
 
 print "\n#--- node('CCC')->add;\n";
 $t->node('AAA')->node('BBB')->node('CCC')->add(
     val => 200,
    );
 
 print "\n#--- node('CCC')->flush;\n";
 $t->node('AAA')->node('BBB')->node('CCC')->flush;
 
 print "\n#--- node('BBB')->add;\n";
 $t->node('AAA')->node('BBB')->add;
 
 print "\n#--- node('AAA')->add;\n";
 $t->node('AAA')->add;
 
 print "\n#--- root->flush;\n";
 $t->flush;

=head3 実行結果

 #--- node('CCC')->add; (twice)
 
 #--- node('CCC')->flush;
 Content-Type: application/octet-stream
 
 This is a header.
 
 
   node AAA begins...
 
   
     node BBB begins...
 
       
       value of node CCC: 100
       
       value of node CCC: 200
       
 #--- node('BBB')->add;
 
 #--- node('CCC')->add;
 
 #--- node('CCC')->flush;
 
 
     node BBB ends...
   
     node BBB begins...
 
       
       value of node CCC: 200
       
 #--- node('BBB')->add;
 
 #--- node('AAA')->add;
 
 #--- root->flush;
 
 
     node BBB ends...
   
 
 
 This is a footer.


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
