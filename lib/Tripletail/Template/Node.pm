# -----------------------------------------------------------------------------
# Tripletail::Template::Node - Templateノードオブジェクト
# -----------------------------------------------------------------------------
package Tripletail::Template::Node;
use strict;
use warnings;
use Tripletail;
#use Smart::Comments;

1;

# テンプレートをパーツ毎に分割
#
# <html>
#   aaa<&FOO>bbb
#   <!mark:bar>
#   <!copy:Bar>
# </html>
#
# $this->{tmplvec} = []; # Template Vector
# ==> [0] = "<html>\n  aaa"
#     [1] = ['tag', 'foo']
#     [2] = "bbb\n  "
#     [3] = ['mark', 'bar']
#     [4] = "\n  "
#     [5] = ['copy', 'baz']
#     [6] = "\n  </html>"
#
# $this->[tmpltags] = ['foo'];
#
# $this->{tmplback} = []; # tmplvec のコピー
#
# 挿入タグや<!mark>, <!copy> への挿入は、{タグ名 => 値} のハッシュへ値を設定する事で行う。
# リセット時にはそのハッシュの内容を空にすると同時に tmplvec をバックアップから書き戻す。
#
# $this->{valmap} = {}; # Value Map
# ==> [tag:foo]  = "FOOに入れたテキスト"
#     [node:bar] = "ノード bar を add した時の内容"
#
# flush 時にはテンプレートの先頭から少しずつ削って行く事になる為、
# tmplvec の内容は浅く変化する。(つまり配列は変化しても配列の要素までは
# 変化しない。)

sub _new {
	my $class = shift;
	my $parent = shift; # Tripletail::Template::Node または undef (rootの場合)
	my $name = shift; # <!mark>の名前。rootならundef
	my $html = shift; # template html

	my $this = bless {} => $class;

	$this->_reset;

	$this->{parent} = $parent;
	$this->{name} = lc $name;

	if(defined $html) {
		$this->_setTemplate($html);
	}

	$this;
}

sub _reset {
	my $this = shift;

	# 以下はルートにのみ存在する
	$this->{is_xhtml} = undef;

	# ソース冒頭参照
	$this->{tmplvec} = [];
	$this->{tmplback} = [];
	$this->{valmap} = {};

	# ノード -- {name => Tripletail::Template::Node}
	$this->{node} = {};

	# タグ属性
	$this->{attr} = {};

	$this;
}

sub isRoot {
	my $this = shift;
	!defined($this->{parent});
}

sub isXHTML {
    my $this = shift;
    
    $this->isRoot ? $this->{is_xhtml} : $this->{parent}->isXHTML;
}

sub _setTemplate {
	my $this = shift;
	my $str = shift;

	$this->_reset;

	if($str =~ m/^\s*<\?xml/) {
		$this->{is_xhtml} = 1;
	} else {
		$this->{is_xhtml} = undef;
	}

	# テンプレートに既に<!mark>が入っていたらエラー。
	if($str =~ m/<!mark:(.+)>/) {
		die __PACKAGE__."#setTemplate, we can't implant <!mark:$1> in a template by hand anymore. Use <!copy:$1> instead.\n";
	}

	# <!begin> - <!end>をパースして、ノードを生成。
	$str =~ s{<!begin:(.+?)>(.*?)<!end:\1>}{
		my ($name, $template) = (lc $1, $2);

		if($this->{node}{$name}) {
			# 既に同じノードが存在していたらエラー。
			die __PACKAGE__."#setTemplate, node [$name] is duplicated.\n";
		}

		$this->{node}{$name} = Tripletail::Template::Node->_new(
			$this, $name, $template
		);
		"<!mark:$name>";
	}egs;

	# 置換されなかった<!begin>や<!end>があったらエラー。
	if($str =~ m{(<!(?:begin|end>):.+?>)}) {
		die __PACKAGE__."#setTemplate, $1 was not matched to an another side.\n";
	}

	$this->_split($str,1);
	$this;
}

sub getHtml {
	my $this = shift;
	$this->_compose(save_marks => 1);
}

sub setHtml {
	my $this = shift;
	my $html = shift;

	if(!defined($html)) {
		die __PACKAGE__."#setHtml, ARG[1] was undef.\n";
	} elsif(ref($html)) {
		die __PACKAGE__."#setHtml, ARG[1] was Ref.\n";
	}

	$this->_split($html,1);
	$this;
}

sub node {
	my $this = shift;
	my $name = shift;

	if(!defined($name)) {
		die __PACKAGE__."#node, ARG[1] is undef.\n";
	} elsif(ref($name)) {
		die __PACKAGE__."#node, ARG[1] is Ref.\n";
	}

	$name = lc($name);

	my $node = $this->{node}{$name};
	if(!$node) {
		my $me = $this->isRoot ? "the root" : "node [$this->{name}]";
		die __PACKAGE__."#node, $me did not have a child node [$name].\n";
	}

	$node;
}

sub exists {
	my $this = shift;
	my $name = shift;

	if(!defined($name)) {
		die __PACKAGE__."#exists, ARG[1] was undef.\n";
	} elsif(ref($name)) {
		die __PACKAGE__."#exists, ARG[1] was Ref.\n";
	}
	
	$name = lc($name);

	exists $this->{node}{$name};
}


sub setAttr {
	my $this = shift;
	my $param = do {
		if(ref($_[0]) eq 'HASH') {
			shift;
		} elsif(!ref($_[0])) {
			scalar { @_ };
		} else {
			die __PACKAGE__."#setAttr, ARG[1] was neither SCALAR nor HASH Ref. [$_[0]]\n";
		}
	};

	foreach my $key (keys %$param) {
		if($param->{$key} eq 'plain'
		|| $param->{$key} eq 'raw'
		|| $param->{$key} eq 'js'
		|| $param->{$key} eq 'br') {
			$this->{attr}{lc($key)} = $param->{$key};
		} else {
			die __PACKAGE__."#setAttr, ARG[1] has wrong type. [$param->{$key}]\n";
		}
	}

	$TL->getDebug->_templateLog(
		node => $this,
		type => 'setattr',
		args => $param
	);

	$this;
}

sub expand {
	my $this = shift;
	my $param = do {
		if(ref($_[0]) eq 'HASH') {
			shift;
		} elsif(!ref($_[0])) {
			scalar { @_ };
		} else {
			die __PACKAGE__."#expand, ARG[1] was neither SCALAR nor HASH Ref. [$_[0]]\n";
		}
	};

	$this->_expand($param, 0);
}

sub expandAny {
	my $this = shift;
	my $param = do {
		if(ref($_[0]) eq 'HASH') {
			shift;
		} elsif(!ref($_[0])) {
			scalar { @_ };
		} else {
			die __PACKAGE__."#expandAny, ARG[1] was neither SCALAR nor HASH Ref. [$_[0]]\n";
		}
	};

	$this->_expand($param, 1);
}

sub add {
	my $this = shift;
	$this->expand(@_);

	$this->_dieIfDirty('add');

	if(!defined($this->{parent})) {
		die __PACKAGE__."#add, internal error [I have no parents].";
	} elsif(!defined($this->{name})) {
		die __PACKAGE__."#add, internal error [I have no name].";
	}

	$TL->getDebug->_templateLog(
		node => $this,
		type => 'add'
	);

	# 文字列化
	my $composed = $this->_compose;

	# 親の<!mark:MY-NAME>及び<!copy:MY-NAME>の前に自分自身を挿入する
	$this->{parent}{valmap}{"node:$this->{name}"} .= $composed;

	# 元のテンプレートに戻す
	if($this->{tmplvec} ne [ @{$this->{tmplback}} ]) {
		$this->{tmplvec} = [ @{$this->{tmplback}} ];
	}

	%{$this->{valmap}} = ();

	$this;
}

sub toStr {
	my $this = shift;
	$this->_dieIfDirty('toStr');

	$TL->getDebug->_templateLog(
		node => $this,
		type => 'toStr'
	);

	# 値の定義されていない挿入タグが残っていたらエラー。(expandAll や
	# flushなどがある為、これが起こり得る。)
	foreach my $seg (@{$this->{tmplvec}}) {
		if(ref($seg) && $seg->[0] eq 'tag' && !defined($this->{valmap}{"tag:$seg->[1]"})) {
			die __PACKAGE__."#toStr, tag [$seg->[1]] was left unexpanded.\n";
		}
	}

	$this->_compose;
}

sub getForm {
	my $this = shift;
	my $name = shift;

	if(ref($name)) {
		die __PACKAGE__."#getForm, ARG[1] was Ref.\n";
	}

	if(!defined($name)) {
		$name = '';
	}

	my $filter = $TL->newHtmlFilter(
		interest => ['input'],
		track => [qw[form textarea select option]],
		filter_text => 1,
	);

	$filter->set($this->getHtml);
	my $form = $TL->newForm;

	### html: $this->getHtml

	my $found;
	while(my ($context, $elem) = $filter->next) {
		### elem: $elem
		if(my $f = $context->in('form')) {
			my $curname = $f->attr('name');
			$curname = defined($curname) ? $curname : '';

			if($curname ne $name) {
				# 関係無いフォーム
				next;
			} else {
				$found = 1;
			}
		} else {
			# form要素の中でない。
			next;
		}

		if($elem->isElement) {
			### name: $elem->name
			if(lc($elem->name) eq 'input') {
				my $name = $elem->attr('name');
				my $type = lc $elem->attr('type');
				my $value = do {
					my $str = $elem->attr('value');
					defined $str ? $str : '';
				};
				my $checked = do {
					my $str = lc($elem->attr('checked'));
					if($str && $str eq 'checked') {
						$str;
					} elsif($elem->end && $elem->end eq 'checked') {
						$elem->end;
					} else {
						undef;
					}
				};

				if(defined($name)) {
					if(!defined $type
					|| $type eq ''
					|| $type eq 'text'
					|| $type eq 'password'
					|| $type eq 'hidden'
					|| $type eq 'submit'
					) {
						$form->add(
							$TL->unescapeTag($name) => $TL->unescapeTag($value)
						);
					} elsif($type eq 'radio' || $type eq 'checkbox') {
						if($checked) {
							$form->add(
								$TL->unescapeTag($name) => $TL->unescapeTag($value)
							);
						} else {
							if(!$form->exists($name)) {
								$form->set($TL->unescapeTag($name) => []);
							}
						}
					}
				}
			}
		} elsif($elem->isText) {
			if(my $textarea = $context->in('textarea')) {
				if(defined(my $name = $textarea->attr('name'))) {
					$form->add(
						$TL->unescapeTag($name) => $TL->unescapeTag($elem->str)
					);
				}
			} elsif(my $option = $context->in('option')) {
				my $select = $context->in('select');
				if($select && defined(my $name = $select->attr('name'))) {
					my $value = do {
						if(my $str = $option->attr('value')) {
							$str;
						} else {
							my $str = $elem->str;
							$str =~ s/^\s*//;
							$str =~ s/\s*$//;
							$str;
						}
					};
					my $selected = do {
						my $str = lc $option->attr('selected');
						if($str && $str eq 'selected') {
							$str;
						} elsif($option->end && $option->end eq 'selected') {
							$option->end;
						}
					};

					if($selected) {
						$form->add(
							$TL->unescapeTag($name) => $TL->unescapeTag($value)
						);
					}
				}
			}
		}
	}

	if(!$found) {
		die __PACKAGE__."#getForm, form [$name] does not exist.\n";
	}

	$form;
}

sub setForm {
	my $this = shift;
	my $form = shift;
	my $name = shift;

	if(!defined($form)) {
		die __PACKAGE__."#setForm, ARG[1] was undef.\n";
	} elsif(ref($form) eq 'HASH') {
		$form = $TL->newForm($form);
	} elsif(ref($form) ne 'Tripletail::Form') {
		die __PACKAGE__."#setForm, ARG[1] was not instance of Tripletail::Form. [$form].\n";
	}

	if(ref($name)) {
		die __PACKAGE__."#setForm, ARG[2] was Ref.\n";
	}

	# $formは後で変更してしまうのでcloneして置く
	$form = $form->clone;

	local *popform = sub {
		# 指定されたkeyの先頭の値を取り出し、それを消す。
		my $key = shift;

		my @array = $form->getValues($key);
		my $val = shift @array;

		$form->remove($key => $val);
		$val;
	};

	if(!defined $name) {
		$name = '';
	}

	$TL->getDebug->_templateLog(
		node => $this,
		type => 'setForm',
		form => $form,
		name => $name,
	);

	my $filter = $TL->newHtmlFilter(
		interest => ['input'],
		track => [qw(form textarea select option)],
		filter_text => 1,
	);
	$filter->set($this->getHtml);

	my $found;
	while(my ($context, $elem) = $filter->next) {
		if(my $f = $context->in('form')) {
			my $curname = $f->attr('name');
			$curname = defined $curname ? $curname : '';

			if($curname ne $name) {
				# 関係無いフォーム
				next;
			} else {
				$found = 1;
			}
		} else {
			# form要素の中でない。
			next;
		}

		if($elem->isElement) {
			if(lc $elem->name eq 'input') {
				if(defined(my $name = $elem->attr('name'))) {
					$name = $TL->unescapeTag($name);
					my $type = lc $elem->attr('type');

					if(!defined($type)
					|| $type eq '' 
					|| $type eq 'text'
					|| $type eq 'password'
					|| $type eq 'hidden'
					|| $type eq 'submit') {
						if($form->exists($name)) {
							# valueを書換える
							$elem->attr(
								value => $TL->escapeTag(popform($name))
							);
						}
					} elsif($type eq 'radio' || $type eq 'checkbox') {
						if($form->exists($name)
						&& defined($elem->attr('value'))
						&& $form->lookup($name,$TL->unescapeTag($elem->attr('value')))) {
							if($this->isXHTML) {
								$elem->attr('checked' => 'checked');
							}else {
								$elem->attr('checked' => undef);
								$elem->end('checked');
							}
						} else {
							if($this->isXHTML) {
								$elem->attr('checked' => undef);
							} else {
								$elem->attr('checked' => undef);
								$elem->end(undef);
							}
						}
					}
				}
			}
		} elsif($elem->isText) {
			if(my $textarea = $context->in('textarea')) {
				if(defined(my $name = $textarea->attr('name'))) {
					$name = $TL->unescapeTag($name);

					if($form->exists($name)) {
						# textareaの中身を置き換える
						$elem->str(
							$TL->escapeTag(popform($name)));
					}
				}
			} elsif(my $option = $context->in('option')) {
				my $select = $context->in('select');
				if($select && defined(my $name = $select->attr('name'))) {
					$name = $TL->unescapeTag($name);

					my $value = do {
						if(my $str = $option->attr('value')) {
							$str;
						} else {
							my $str = $elem->str;
							$str =~ s/^\s*//;
							$str =~ s/\s*$//;
							$str;
						}
					};

					if($form->exists($name)
					&& $form->lookup($name,$TL->unescapeTag($value))) {
						if($this->isXHTML) {
							$option->attr('selected' => 'selected');
						} else {
							$option->attr(selected => undef);
							$option->end('selected');
						}
					} else {
						if($this->isXHTML) {
							$option->attr(selected => undef);
						} else {
							$option->attr(selected => undef);
							$option->end(undef);
						}
					}
				}
			}
		}
	}

	if(!$found) {
		die __PACKAGE__."#setForm, form [$name] does not exist.\n";
	}

	$this->setHtml($filter->toStr);

	$this;
}

sub extForm {
	my $this = shift;
	my $name = shift;

	if(ref($name)) {
		die __PACKAGE__."#extForm, ARG[1] was Ref.\n";
	}

	if(!defined $name) {
		$name = '';
	}

	$TL->getDebug->_templateLog(
		node => $this,
		type => 'extForm',
		name => $name,
	);

	my $filter = $TL->newHtmlFilter(
		interest => ['form'],
		filter_text => 0,
	);
	$filter->set($this->getHtml);

	my $found;
	while(my ($context, $elem) = $filter->next) {
		if($elem->isElement) {
			if(lc $elem->name eq 'form') {
				my $curname = $elem->attr('name');
				$curname = defined $curname ? $curname : '';
				
				if($curname ne $name) {
					# 関係無いフォーム
					next;
				} else {
					$elem->attr(EXT => 1);
					$found = 1;
				}
			}
		}
	}

	if(!$found) {
		die __PACKAGE__."#extForm, form [$name] does not exist.\n";
	}

	$this->setHtml($filter->toStr);

	$this;
}

sub addHiddenForm {
	my $this = shift;
	my $form = shift;
	my $name = shift;

	if(!defined($form)) {
		die __PACKAGE__."#addHiddenForm, ARG[1] was undef.\n";
	} elsif(ref($form) eq 'HASH') {
		$form = $TL->newForm($form);
	} elsif(ref($form) ne 'Tripletail::Form') {
		die __PACKAGE__."#addHiddenForm, ARG[1] was not instance of Tripletail::Form or HASH.\n";
	}
	if(ref($name)) {
		die __PACKAGE__."#addHiddenForm, ARG[2] was Ref.\n";
	}

	if(!defined($name)) {
		$name = '';
	}

	$TL->getDebug->_templateLog(
		node => $this,
		type => 'addHiddenForm',
		form => $form,
		name => $name,
	);

	my $filter = $TL->newHtmlFilter(
		interest => ['form'],
	);
	$filter->set($this->getHtml);

	my $found;
	while(my ($context, $elem) = $filter->next) {
		if($elem->isElement && lc $elem->name eq 'form') {
			my $curname = do {
				my $str = $elem->attr('name');
				if(defined($str)) {
					$TL->unescapeTag($str);
				} else {
					'';
				}
			};

			if($curname eq $name) {
				$found = 1;

				foreach my $key ($form->getKeys) {
					foreach my $value ($form->getValues($key)) {
						my $e = $context->newElement('input');
						$e->attr(type => 'hidden');
						$e->attr(name => $TL->escapeTag($key));
						$e->attr(value => $TL->escapeTag($value));

						if($this->isXHTML) {
							$e->end('/');
						}

						$context->add($e);
					}
				}
			}
		}
	}

	if(!$found) {
		die __PACKAGE__."#addHiddenForm, form [$name] does not exist.\n";
	}

	### before: $this->getHtml
	### filtered: $filter->toStr
	$this->_setHtml($filter->toStr);
	$this;
}

sub addSessionCheck {
	my $this = shift;
	my $sessiongroup = shift;
	my $name = shift;
	my $issecure = shift;

	if(!defined($sessiongroup)) {
		die __PACKAGE__."#addSessionCheck, ARG[1] was undef.\n";
	}
	my $session = $TL->getSession($sessiongroup);
	if(ref($name)) {
		die __PACKAGE__."#addSessionCheck, ARG[2] was Ref.\n";
	}
	if(ref($issecure)) {
		die __PACKAGE__."#addSessionCheck, ARG[3] was Ref.\n";
	}

	my $csrfkey = $TL->INI->get($sessiongroup => 'csrfkey', undef);
	if(!defined($csrfkey)) {
		die __PACKAGE__."#addSessionCheck, csrfkey was not set. set INI [$sessiongroup].\n";
	}

	do {
		local $SIG{__DIE__} = 'DEFAULT';
		eval 'use Digest::HMAC_SHA1 qw(hmac_sha1_hex)';
	};
	if($@) {
		die __PACKAGE__."#addSessionCheck, failed to load HMAC_SHA1.pm [$@]\n";
	}

	my ($key, $sid, $checkval) = $session->getSessionInfo($issecure);
	
	if(!defined($sid)) {
		die __PACKAGE__."#addSessionCheck, Session was not set. need setValue.\n";
	}
	
	$key = 'C' . $key;
	my $value = hmac_sha1_hex(join('.', $sid, $checkval), $csrfkey);

	if(!defined($name)) {
		$name = '';
	}

	$TL->getDebug->_templateLog(
		node => $this,
		type => 'addSessionCheck',
		name => $name,
	);

	my $filter = $TL->newHtmlFilter(
		interest => ['form'],
	);
	$filter->set($this->getHtml);

	my $found;
	while(my ($context, $elem) = $filter->next) {
		if($elem->isElement && lc $elem->name eq 'form') {
			my $curname = do {
				my $str = $elem->attr('name');
				if(defined($str)) {
					$TL->unescapeTag($str);
				} else {
					'';
				}
			};

			if($curname eq $name) {
				$found = 1;

				if(lc($elem->attr('method')) ne 'post') {
					die __PACKAGE__."#addSessionCheck, form isn't post method.\n"
				}

				my $e = $context->newElement('input');
				$e->attr(type => 'hidden');
				$e->attr(name => $TL->escapeTag($key));
				$e->attr(value => $TL->escapeTag($value));

				if($this->isXHTML) {
					$e->end('/');
				}

				$context->add($e);
			}
		}
	}

	if(!$found) {
		die __PACKAGE__."#addSessionCheck, form [$name] does not exist.\n";
	}

	$this->_setHtml($filter->toStr);
	$this;
}

sub flush {
	my $this = shift;
	$this->_dieIfDirty('flush');

	$TL->getDebug->_templateLog(
		node => $this, type => 'flush');

	$this->_flush;
}

sub _setHtml {
	my $this = shift;
	my $html = shift;

	if(!defined($html)) {
		die __PACKAGE__."#setHtml, ARG[1] was undef.\n";
	} elsif(ref($html)) {
		die __PACKAGE__."#setHtml, ARG[1] was Ref.\n";
	}

	$this->_split($html);
	$this;
}

sub _finalize {
	my $this = shift;

	foreach my $node (values %{$this->{node}}) {
		$node->_finalize;
	}
	$this->{node} = undef;
}

sub _isDirty {
	# このノードが dirty であるなら、実際に dirty であるノードを返す。
	# そうでなければ undef。
	#
	# 或るノードがdirtyであるとは、自分の valmap が空でないか、または
	# dirty な子ノードを持っている場合を云う。
	my $this = shift;
	my $ignore_dirtiness_of_myself = shift;

	if(not $ignore_dirtiness_of_myself and %{$this->{valmap}}) {
		return $this;
	}

	foreach my $child (values %{$this->{node}}) {
		if(my $dirty = $child->_isDirty) {
			return $dirty;
		}
	}

	undef;
}

sub _nodePath {
	# /    => ルートノード
	# /foo => ルート直下のノード"foo"
	my $this = shift;

	if($this->{parent}) {
		my $parent_path = $this->{parent}->_nodePath;

		$parent_path eq '/' ? "/$this->{name}" : "$parent_path/$this->{name}";
	} else {
		'/';
	}
}

sub _dieIfDirty {
	# dirtyな子ノードがあったらdie。
	my $this = shift;
	my $method = shift;

	if(my $dirty = $this->_isDirty(1)) {
		die __PACKAGE__."#$method, node [".$dirty->_nodePath."] was modified but not added to the parent.\n";
	}

	$this;
}

sub _flush {
	my $this = shift;
	my $mark = shift; # <!mark>名。undefの場合がある。(後述)

	# ルートノードのflushは、(もしあれば)指定された<!mark>まで取り出し、
	# それを出力してから消す事で行う。
	# ルート以外では、先に自分の親ノードの_flushを自分の名前付きで呼んだ後に、
	# (もしあれば)指定された<!mark>までを取り出して、それを出力して消す。

	if(defined($this->{parent})) {
		# ルートでない。
		$this->{parent}->_flush($this->{name});
	}

	my $to_flush = do {
		if(defined($mark)) {
			my $ret = '';

			unless(grep {
				ref($_) &&
				  $_->[0] eq 'mark' &&
					$_->[1] eq $mark; } @{$this->{tmplvec}}) {
				
				die __PACKAGE__."#flush, node [$mark] seems to be already flushed.\n";
			}

			while(my $seg = shift @{$this->{tmplvec}}) {
				if(ref($seg)) {
					if($seg->[0] eq 'tag') {
						my $ref = \$this->{valmap}{"tag:$seg->[1]"};

						if(defined($$ref)) {
							$ret .= $$ref;
						} else {
							die __PACKAGE__."#flush, tag [$seg->[1]] was left unexpanded.\n";
						}
					} elsif($seg->[0] eq 'mark' || $seg->[0] eq 'copy') {
						my $ref = \$this->{valmap}{"node:$seg->[1]"};

						if(defined($$ref)) {
							$ret .= $$ref;
						}

						if($seg->[0] eq 'mark' && $seg->[1] eq $mark) {
							# ここで終わり
							$$ref = undef;
							unshift @{$this->{tmplvec}}, $seg;
							last;
						}
					} else {
						die "internal error: unknown segment type: $seg->[0]";
					}
				} else {
					$ret .= $seg; # ただの文字列
				}
			}

			$ret;
		} else {
			# $markがundefであるのは次の場合。
			# 1. ルートノードに対してflush()が呼ばれた場合
			#    -- この場合は現在の$this->{html}の内容をそのまま出力して消す。
			# 2. ルート以外のノードに対してflush()が呼ばれ、且つ_flush()の呼出しが
			#    全ての祖先に対しての再帰を終えた後。
			#    -- この場合は何も消さず何も出力せずに終了。
			unless(defined($this->{parent})) {
				my $composed = $this->_compose;
				$this->{tmplvec} = [];
				
				$composed;
			} else {
				'';
			}
		}
	};

	$TL->print($to_flush);

	$this;
}

sub _expand {
	my $this = shift;
	my $param = shift; # always HASH ref
	my $allow_unexpanded = shift;

	$TL->getDebug->_templateLog(
		node => $this,
		type => 'expand',
		args => $param,
		any  => $allow_unexpanded
	);

	while(my ($key, $val) = each %$param) {
		if(!defined($val)) {
			die __PACKAGE__."#expand, value for key [$key] was undef.\n";
		} elsif(ref($val)) {
			die __PACKAGE__."#expand, value for key [$key] was a ref. [$val]\n";
		}
		
		$key = lc($key);
		$val = $this->_filter($key, $val);

		$this->{valmap}{"tag:$key"} = $val;
	}

	unless($allow_unexpanded) {
		if(keys %{$this->{valmap}} != @{$this->{tmpltags}}) {
			foreach my $seg (@{$this->{tmplvec}}) {
				ref $seg or next;
				$seg->[0] eq 'tag' or next;
				
				unless(defined($this->{valmap}{"tag:$seg->[1]"})) {
					die __PACKAGE__."#expand, key [$seg->[1]] was left unexpanded.\n";
				}
			}
		}
	}

	$this;
}

sub _filter {
	my $this = shift;
	my $key = shift;
	my $value = shift; # value will be modified, if $key isn't raw.
	# Return: $value that has been modified.

	if(!exists($this->{attr}{$key}) ||
		  $this->{attr}{$key} eq 'plain') {
		$value = $TL->escapeTag($value);
	} elsif($this->{attr}{$key} eq 'raw') {
		# do nothing
	} elsif($this->{attr}{$key} eq 'js') {
		# JavaScript filter
		$value = $TL->escapeJs($value);
	} elsif($this->{attr}{$key} eq 'br') {
		# insert <br> or <br /> before newlines
		$value = $TL->escapeTag($value);

		if($this->{is_xhtml}) {
			$value =~ s!(\r?\n)!<br />$1!g;
		} else {
			$value =~ s!(\r?\n)!<br>$1!g;
		}
	} else {
		die __PACKAGE__."#_filter, internal state error.\n";
	}

	$value;
}

my $re_split = qr{(
    <
	 (?:
		&              |  # 挿入タグの場合
		!(?:mark|copy):   # mark または copy の場合
	 )
	 [^>]+
	>
)}x;
sub _split {
	my $this = shift;
	my $src = shift;
	my $tmpwrite = shift;

	my $vec = [];
	my $tags = [];

	foreach my $part (split $re_split, $src) {
		defined $part or next;
		length $part or next;

		if(substr($part, 0, 1) ne '<') {
			push @$vec, $part;
		} else {
			if($part =~ m/<&(.+?)>/) {
				push @$vec, [tag => lc $1];
				push @$tags, lc $1;
			} elsif($part =~ m/<!(mark|copy):(.+?)>/) {
				push @$vec, [$1 => lc $2];
			} else {
				push @$vec, $part;
			}
		}
	}

	$this->{tmplvec} = $vec;
	$this->{tmpltags} = $tags;
	$this->{tmplback} = [ @$vec ] if($tmpwrite);
	$this->{valmap} = {};
}

sub _compose {
	# このメソッドの動作速度は重要。
	my $this = shift;
	my $opts = { @_ };
	my $ret = '';
	
	my $save_marks = $opts->{save_marks};

	foreach my $seg (@{$this->{tmplvec}}) {
		if(ref($seg)) {
			my $dest = ($seg->[0] eq 'tag' ? 'tag' : 'node');
			my $ref = \$this->{valmap}{"$dest:$seg->[1]"};

			if(defined($$ref)) {
				$ret .= $$ref;
			}

			if($save_marks) {
				if($seg->[0] eq 'tag') {
					if(!defined($$ref)) {
						$ret .= sprintf '<&%s>', $seg->[1];
					}
				} else {
					$ret .= sprintf '<!%s:%s>', $seg->[0], $seg->[1];
				}
			}
		} else {
			$ret .= $seg;
		}
	}

	$ret;
}

__END__

=encoding utf-8

=head1 NAME

Tripletail::Template::Node - Templateノードオブジェクト

=head1 DESCRIPTION

L<Tripletail::Template> 参照

=head2 METHODS

=over 4

=item add

L<Tripletail::Template> 参照

=item addHiddenForm

L<Tripletail::Template> 参照

=item addSessionCheck

L<Tripletail::Template> 参照

=item exists

L<Tripletail::Template> 参照

=item expand

L<Tripletail::Template> 参照

=item expandAny

L<Tripletail::Template> 参照

=item extForm

L<Tripletail::Template> 参照

=item flush

L<Tripletail::Template> 参照

=item getForm

L<Tripletail::Template> 参照

=item getHtml

L<Tripletail::Template> 参照

=item isRoot

L<Tripletail::Template> 参照

=item isXHTML

L<Tripletail::Template> 参照

=item node

L<Tripletail::Template> 参照

=item setAttr

L<Tripletail::Template> 参照

=item setForm

L<Tripletail::Template> 参照

=item setHtml

L<Tripletail::Template> 参照

=item toStr

L<Tripletail::Template> 参照

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
