# -----------------------------------------------------------------------------
# Tripletail::TagCheck - HTMLのタグのチェック
# -----------------------------------------------------------------------------
package Tripletail::TagCheck;
use strict;
use warnings;
use Tripletail;

1;

sub _new {
	my $pkg = shift;
	my $this = bless {} => $pkg;

	$this->{target} = undef;
	$this->{allowed} = {}; # {要素名 => Tripletail::TagCheck::TagInfo}
	$this->{autolink} = undef;
	$this->{tagbreak} = undef;

	$this->setATarget('_blank');
	$this->setAllowTag(qq{
		:HR
		:BR
		;B
		;S
		;STRONG
		;I
		;U
		;EM
		;A(HREF,TARGET,NAME)
	});
	$this->setAutoLink(1);
	$this->setTagBreak('line');

	$this;
}

sub setATarget {
	my $this = shift;
	my $target = shift;

	if(ref($target)) {
		die __PACKAGE__."#setATarget, ARG[1] was a Ref. [$target]\n";
	}

	$this->{target} = $target;
	$this;
}

sub setAllowTag {
	my $this = shift;
	my $list = shift;

	if(!defined($list)) {
		die __PACKAGE__."#setAllowTag, ARG[1] was undef.\n";
	} elsif(ref($list)) {
		die __PACKAGE__."#setAllowTag, ARG[1] was a Ref. [$list]\n";
	}

	%{$this->{allowed}} = ();
	$this->addAllowTag($list);
}

sub addAllowTag {
	my $this = shift;
	my $list = shift;

	if(!defined($list)) {
		die __PACKAGE__."#addAllowTag, ARG[1] was undef.\n";
	} elsif(ref($list)) {
		die __PACKAGE__."#addAllowTag, ARG[1] was a Ref. [$list]\n";
	}

	while($list =~ s/([:;!])(\w+)([^:;\s]*)//) {
		my $type = $1;
		my $tag = lc($2);
		my $opt = lc($3);

		if($type eq '!') {
			# 削除
			delete $this->{allowed}{$tag};
			next;
		}

		my $info = $this->{allowed}{$tag} = Tripletail::TagCheck::TagInfo->new($tag);

		if($type eq ':') {
			$info->mustBeEmpty(1);
		}

		if($opt =~ s/\((.*?)\)//) {
			# 可能な属性のリスト
			$info->setAllowedAttributes(split /,/, $1);
		}

		if($opt =~ s/\[(.*?)\]//) {
			# 可能な子要素のリスト
			$info->textIsAllowed(0);
			$info->setAllowedChildren(split /,/, $1);
		}

		if($opt =~ s/\{(.*?)\}//) {
			# tag breakのオーバーライド
			$info->tagbreak($1);
		}
	}

	$this;
}

sub setAutoLink {
	my $this = shift;
	my $flag = shift;

	if(ref($flag)) {
		die __PACKAGE__."#setAutoLink, ARG[1] was a Ref. [$flag]\n";
	}

	$this->{autolink} = $flag;
	$this;
}

sub setTagBreak {
	my $this = shift;
	my $type = shift;

	if(!defined($type)) {
		die __PACKAGE__."#setTagBreak, ARG[1] was undef.\n";
	} elsif(ref($type)) {
		die __PACKAGE__."#setTagBreak, ARG[1] was a Ref. [$type]\n";
	} elsif($type ne 'line' && $type ne 'block' && $type ne 'none') {
		die __PACKAGE__."#setTagBreak, invalid tag-break type: [$type]\n";
	}

	$this->{tagbreak} = $type;
	$this;
}

sub check {
	my $this = shift;
	my $html = shift;

	if(!defined($html)) {
		die __PACKAGE__."#check, ARG[1] was undef.\n";
	} elsif(ref($html)) {
		die __PACKAGE__."#check, ARG[1] was a Ref. [$html]\n";
	}

	my $filter = $TL->newHtmlFilter(
		interest    => [qr/.+/], # 全てのタグに興味がある
		filter_text => 1,
	);
	$filter->set($html);

	my $open_stack = []; # 開いたままになっているタグのスタック
	while(my ($context, $elem) = $filter->next) {
		if($elem->isText) {
			if($elem->str =~ m/\r?\n\r?\n/) {
				# 改行が二つ続いているので、この位置で
				# blockまたはlineでtagbreakするタグを閉じる。

				my $old = $elem->str;
				$old =~ s/(\r?\n\r?\n)/$this->__break(['block', 'line'] => $open_stack) . $1/e;
				$elem->str($old);
			} elsif($elem->str =~ m/\r?\n/) {
				# 改行があるので、この位置でlineでtagbreakするタグを閉じる。

				my $old = $elem->str;
				$old =~ s/(\r?\n)/$this->__break(['line'] => $open_stack) . $1/e;
				$elem->str($old);
			}

			# 自動リンクが有効になっているなら自動リンク実行。
			if($this->{autolink}) {
				if(@$open_stack
				&& $this->{allowed}{$open_stack->[-1]->name}
				&& !$this->{allowed}{$open_stack->[-1]->name}->isAllowedChild('a')) {
					# 親タグがAタグの存在を許していないので、自動リンクしない。
				} else {
					$elem->str($this->__autoLink($elem->str));
				}
			}

			# 親タグがテキストの存在を許していなければ、これを消す。
			if(@$open_stack
			&& $this->{allowed}{$open_stack->[-1]->name}
			&& !$this->{allowed}{$open_stack->[-1]->name}->textIsAllowed) {
				$context->delete;
			}
		} elsif($elem->isElement) {
			$elem->name =~ m!^(/?)(.+)$!;
			my $close = $1;
			my $name = $2;
			my $taginfo = $this->{allowed}{$name};

			my $forbidden;
			if(!$taginfo) {
				# このタグはそもそも許されていない。
				$forbidden = 1;
			} elsif($close && @$open_stack && $open_stack->[-1]->name eq $name) {
				# 自分の閉じタグ
			} elsif(@$open_stack
			&& $this->{allowed}{$open_stack->[-1]->name}
			&& !$this->{allowed}{$open_stack->[-1]->name}->isAllowedChild($name)) {
				# 親タグがこのタグを許していない。
				$forbidden = 1;
			}

			if(!$forbidden && $close) {
				if($taginfo->mustBeEmpty) {
					# 閉じタグの存在が許されていない
					$context->delete;
					$this->__close($name => $open_stack);
					next;
				} elsif(!grep {$_->name eq $name} @$open_stack) {
					# 対応する開始タグが存在しない。
					$forbidden = 1;
				} else {
					# 対応する最近の開始タグが閉じられた事にする
					$this->__close($name => $open_stack);
				}
			}

			if($forbidden) {
				# 許されていないタグはエスケープする。
				# 但し親タグがテキストの存在を許している場合のみ。
				$context->delete;

				if(@$open_stack
				&& $this->{allowed}{$open_stack->[-1]->name}
				&& !$this->{allowed}{$open_stack->[-1]->name}->textIsAllowed) {
					# 許していない
				} else {
					$context->add($TL->escapeTag($elem->toStr));
				}
				next;
			}

			# この要素の存在が許されているなら、ここへ来ている。

			if(!$close) {
				# 属性のチェック
				foreach my $attrkey ($elem->attrList) {
					if(!$taginfo->isAllowedAttribute($attrkey)) {
						# この属性は許されていないので消す。
						$elem->attr($attrkey => undef);
					}
				}

				# Aタグの場合の特別処理。target指定があればそれを設定する。
				if($elem->name eq 'a' && defined($this->{target})) {
					$elem->attr(target => $this->{target});
				}

				# スタックにプッシュ
				push @$open_stack, $elem;
			}
		}
	}

	$filter->toStr;
}

sub __close {
	my $this = shift;
	my $name = shift;
	my $stack = shift;

	for(my $i = @$stack-1; $i >= 0; $i--) {
		if($stack->[$i]->name eq $name) {
			splice @$stack, $i, 1;
			last;
		}
	}
}

sub __break {
	my $this = shift;
	my $types = shift;
	my $stack = shift;
	my $result = '';

	for(my $i = @$stack-1; $i >= 0; $i--) {
		my $taginfo = $this->{allowed}{$stack->[$i]->name};
		my $tagbreak = $taginfo ? $taginfo->tagbreak : undef;
		if(!$tagbreak) {
			$tagbreak = $this->{tagbreak};
		}

		if(grep {$_ eq $tagbreak} @$types) {
			# 実際に閉じる
			$result = sprintf '</%s>%s', $stack->[$i]->name, $result;
			splice @$stack, $i, 1;
		}
	}

	$result;
}

sub __autoLink {
	my $this = shift;
	my $str = shift;

	$str =~ s{((?:https?|ftp|mailto)://[\x21-\x7e]+)}{
		if(defined(my $target = $this->{target})) {
			sprintf '<a href="%s" target="%s">%s</a>',
				$TL->encodeURL($1),
				$target,
				$TL->escapeTag($1);
		} else {
			sprintf '<a href="%s">%s</a>',
				$TL->encodeURL($1),
				$TL->escapeTag($1);
		}
	}eg;

	$str;
}

package Tripletail::TagCheck::TagInfo;
sub new {
	my $class = shift;
	my $tag = shift;
	my $this = bless {} => $class;

	$this->{tag} = $tag;
	$this->{must_be_empty} = undef;
	$this->{allowed_attributes} = undef; # 属性名 => 1
	$this->{allowed_children} = undef; # 要素名 => 1
	$this->{is_text_allowed} = 1;
	$this->{tagbreak} = undef; # undefでなければtag breakをオーバーライド

	$this;
}

sub mustBeEmpty {
	my $this = shift;

	if(@_) {
		$this->{must_be_empty} = shift;
	}

	$this->{must_be_empty};
}

sub setAllowedAttributes {
	my $this = shift;

	$this->{allowed_attributes} = { map {$_ => 1} @_ };

	$this;
}

sub isAllowedAttribute {
	my $this = shift;
	my $attr = shift;

	my $allow_attr = $this->{allowed_attributes};
	if($allow_attr) {
		$allow_attr->{$attr};
	} else {
		1;
	}
}

sub setAllowedChildren {
	my $this = shift;

	$this->{allowed_children} = { map {$_ => 1} @_ };

	if($this->{allowed_children}{'*'}) {
		$this->{is_text_allowed} = 1;
		delete $this->{allowed_children};
	}

	$this;
}

sub isAllowedChild {
	my $this = shift;
	my $elem = shift;

	my $child = $this->{allowed_children};
	if($child) {
		$child->{$elem};
	} else {
		1;
	}
}

sub textIsAllowed {
	my $this = shift;

	if(@_) {
		$this->{is_text_allowed} = shift;
	}

	$this->{is_text_allowed};
}

sub tagbreak {
	my $this = shift;

	if(@_) {
		$this->{tagbreak} = shift;
	}

	$this->{tagbreak};
}


__END__

=encoding utf-8

=head1 NAME

Tripletail::TagCheck - HTMLのタグのチェック

=head1 SYNOPSIS

  my $tc = $TL->newTagCheck;
  $tc->setAllowTag(':BR;SMALL;STRONG');
  
  my $checked_html = $tc->check('<font size="+7">foo</font><small>bar</small>');
  if ($check_html eq 'foo<small>bar</small>') {
      # true
  }

=head1 DESCRIPTION

HTML のタグのチェックを行い、不必要なタグを削除する。

=head2 METHODS

=over 4

=item $TL->newTagCheck

  $checker = $TL->newTagCheck

Tripletail::TagCheck オブジェクトを作成。

=item check

  $checked_html = $checker->check($html)

渡されたHTMLを処理し、その結果を返す。

=item setTagBreak

  $checker->setTagBreak('line')

'none', 'line', 'block'が指定可能。デフォルトは'line'。
タグを自動で閉じるかどうかを設定する。

=over 8

=item none

自動で閉じない。

=item line

行末で閉じる。

=item block

改行が二つ続いた位置で閉じる。

=back

=item setAutoLink

  $checker->setAutoLink(1)

テキスト中に含まれるURLを自動でE<lt>a href="..."E<gt>でリンクにするかどうか。
0の場合、リンクにしない。
1の場合、リンクにする。

デフォルトは1。

=item setAllowTag

  $checker->setAllowTag(':HR:BR;STRONG')

使用を許可するタグを指定する。ここで指定されなかったタグは許可されていないもの
として、"E<lt>"と"E<gt>"を"&lt;"と"&gt;"にエンコードする。書式は次の通り。

":TAG"または";TAG"で一つのタグを表す。
このような指定を任意の個数だけ繋げる事が出来る。

":"で指定されたタグは、その閉じタグの存在が禁止される。
禁止された閉じタグは削除される。

";"で指定されたタグは、その閉じタグの存在が要求される。
閉じタグが存在しない場合は、setTagBreakで指定された方法に従って
閉じタグが追加される。

";A(HREF,TARGET)"のように"(...)"で属性の種類を制限可能。
列挙しなかった属性は削除される。

";TR[TD,TH]"のように"[...]"で子要素の種類を制限可能。
列挙しなかった子要素はエスケープされる。また、このようにして子要素の種類を
制限した場合は、要素がテキストを持つ事も禁止される。禁止されたテキストは
削除される。";TR[TD,TH,*]"のように要素名として"*"を指定すると、子要素としての
テキストが禁止されない。

";TD{none}"のように"{...}"でsetTagBreakの指定を部分的に上書き可能。
このようにしてTagBreakが例外指定された要素については、setTagBreakでの設定が
適用されない。

上記"(...)", "[...]", "{...}"のオプションは任意の順序で同時に指定する事が可能。
但し同じ種類のオプションを一つのタグに対し複数個指定する事は出来ない。

デフォルト値は次の通り:

  ":HR:BR;S;STRONG;I;U;EM;A(HREF,TARGET,NAME)"

=item addAllowTag

  $checker->addAllowTag('!EMBED;TABLE[TR];TR[TD,TH];TD{none};TH{none}')

既存のタグの許可情報が消されない事を除き、setAllowTagと同様。
また、このメソッドでのみ意味のある指定方式として、
"!TAG"のように特定のタグを改めて禁止する事が出来る。

=item setATarget

  $checker->setATarget('_blank')

a要素のtarget属性を書換えるかどうか。undefを指定すると書換えが行われない。
setATargetを実行しない状態では'_blank'として設定されている。

=back

=head1 SEE ALSO

=over 4

=item L<Tripletail>

=item L<Tripletail::HtmlFilter>

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
