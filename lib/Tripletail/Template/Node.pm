# -----------------------------------------------------------------------------
# Tripletail::Template::Node - Templateノードオブジェクト
# -----------------------------------------------------------------------------
package Tripletail::Template::Node;
use strict;
use warnings;
use Tripletail;
#use Smart::Comments;

my @_SPLIT_CACHE;

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
#     [1] = ['tag', 'foo', \"tag:foo"]
#     [2] = "bbb\n  "
#     [3] = ['mark', 'bar', \"node:bar"]
#     [4] = "\n  "
#     [5] = ['copy', 'baz', \"node:baz"]
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
		die __PACKAGE__."#setTemplate: we can't implant <!mark:$1> in a template by hand anymore. Use <!copy:$1> instead.".
			" (テンプレートに<!mark:$1>タグを入れることは出来ません。<!copy:$1>を使用してください)\n";
	}

	# <!begin> - <!end>をパースして、ノードを生成。
	$str =~ s{<!begin:(.+?)>(.*?)<!end:\1>}{
		my ($name, $template) = (lc $1, $2);

		if($this->{node}{$name}) {
			# 既に同じノードが存在していたらエラー。
			die __PACKAGE__."#setTemplate: node [$name] is duplicated. (ノード[$name]が複数あります)\n";
		}

		$this->{node}{$name} = Tripletail::Template::Node->_new(
			$this, $name, $template
		);
		"<!mark:$name>";
	}egs;

	# 置換されなかった<!begin>や<!end>があったらエラー。
	if($str =~ m{(<!(?:begin|end>):.+?>)}) {
		die __PACKAGE__."#setTemplate: $1 doesn't match to an another side. ($1のブロックの対応がとれていません)\n";
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
		die __PACKAGE__."#setHtml: arg[1] is not defined. (第1引数が指定されていません)\n";
	} elsif(ref($html)) {
		die __PACKAGE__."#setHtml: arg[1] is a reference. (第1引数がリファレンスです)\n";
	}

	$this->_split($html,1);
	$this;
}

sub node {
	my $this = shift;
	my $name = shift;

	if(!defined($name)) {
		die __PACKAGE__."#node: arg[1] is not defined. (第1引数が指定されていません)\n";
	} elsif(ref($name)) {
		die __PACKAGE__."#node: arg[1] is a reference. (第1引数がリファレンスです)\n";
	}

	$name = lc($name);

	my $node = $this->{node}{$name};
	if(!$node) {
		my $me = $this->isRoot ? "the root" : "node [$this->{name}]";
		die __PACKAGE__."#node: $me does not have a child node [$name]. (${me}は子ノードを持っていません)\n";
	}

	$node;
}

sub exists {
	my $this = shift;
	my $name = shift;

	if(!defined($name)) {
		die __PACKAGE__."#exists: arg[1] is not defined. (第1引数が指定されていません)\n";
	} elsif(ref($name)) {
		die __PACKAGE__."#exists: arg[1] is a reference. (第1引数がリファレンスです)\n";
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
			die __PACKAGE__."#setAttr: arg[1] is neither a HASH Ref nor a scalar. [$_[0]] (第1引数がハッシュでもハッシュのリファレンスでもありません)\n";
		}
	};

	foreach my $key (keys %$param) {
		if($param->{$key} eq 'plain'
		|| $param->{$key} eq 'raw'
		|| $param->{$key} eq 'js'
		|| $param->{$key} eq 'br') {
			$this->{attr}{lc($key)} = $param->{$key};
		} else {
			die __PACKAGE__."#setAttr: arg[1] is an invalid type. [$param->{$key}] (第1引数の指定に不正な展開方法が含まれます)\n";
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
			die __PACKAGE__."#expand: arg[1] is neither a HASH Ref nor a scalar. [$_[0]] (第1引数がハッシュでもハッシュのリファレンスでもありません)\n";
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
			die __PACKAGE__."#expandAny: arg[1] is neither a HASH Ref nor a scalar. [$_[0]] (第1引数がハッシュでもハッシュのリファレンスでもありません)\n";
		}
	};

	$this->_expand($param, 1);
}

sub add {
	my $this = shift;
	$this->expand(@_);

	$this->_dieIfDirty('add');

	if(!defined($this->{parent})) {
		die __PACKAGE__."#add: internal error [I have no parents]. (内部エラー:親がいません)";
	} elsif(!defined($this->{name})) {
		die __PACKAGE__."#add: internal error [I have no name]. (内部エラー:名前がありません)";
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
    $this->{tmplvec} = [ @{$this->{tmplback}} ];

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
	
	$this->_dieIfAnyUnexpandedTag('toStr');
	$this->_compose;
}

sub getForm {
	my $this = shift;
	my $name = shift;

	if(ref($name)) {
		die __PACKAGE__."#getForm: arg[1] is a reference. (第1引数がリファレンスです)\n";
	}

	if(!defined($name)) {
		$name = '';
	}

	my $filter = $TL->newHtmlFilter(
		interest => ['input'],
		track => [qw[form textarea select option]],
		filter_text => 1,
	);

    $this->_dieIfAnyUnexpandedTag('getForm');

	$filter->set($this->_compose);
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
						my $str = $option->attr('value');
						if(defined($str)) {
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
		die __PACKAGE__."#getForm: form [$name] does not exist. (form [$name] が存在しません)\n";
	}

	$form;
}

sub __popform
{
	# 指定されたkeyの先頭の値を取り出し、それを消す。
	my $form = shift;
	my $key  = shift;
	
	my @array = $form->getValues($key);
	if( !@array )
	{
		return '';
	}
	
	my $val = shift @array;
	$form->remove($key => $val);
	$val;
}

sub setForm {
	my $this = shift;
	my $form = shift;
	my $name = shift;

	if(!defined($form)) {
		die __PACKAGE__."#setForm: arg[1] is not defined. (第1引数が指定されていません)\n";
	} elsif(ref($form) eq 'HASH') {
		$form = $TL->newForm($form);
	} elsif(ref($form) ne 'Tripletail::Form') {
		die __PACKAGE__."#setForm: arg[1] is not an instance of Tripletail::Form. [$form]. (第1引数がFormオブジェクトではありません)\n";
	}

	if(ref($name)) {
		die __PACKAGE__."#setForm: arg[2] is a reference. (第2引数がリファレンスです)\n";
	}

	# $formは後で変更してしまうのでcloneして置く
	$form = $form->clone;

	if(!defined $name) {
		$name = '';
	}

	$TL->getDebug->_templateLog(
		node => $this,
		type => 'setForm',
		form => $form,
		name => $name,
	);

    $this->_dieIfAnyUnexpandedTag('setForm');

	my $html = $this->_compose;
	my $has_textarea = $html=~/<textarea\b/i;
	my $has_option   = $html=~/<option\b/i;
	my $no_filter_text = !$has_textarea && !$has_option;
	
	my $filter = $TL->newHtmlFilter(
		interest => ['input'],
		track => [qw(form textarea select option)],
		filter_text => !$no_filter_text,
	);
	$filter->set($html);

	my $found;
	my $last_form = 0;
	my $on_form;
	while(my ($context, $elem) = $filter->next)
	{
		if( my $f = $context->in('form') )
		{
			if( $f!=$last_form )
			{
				my $curname = $f->attr('name');
				$curname = defined $curname ? $curname : '';

				if($curname ne $name) {
					# 関係無いフォーム
					$on_form &&= undef;
					next;
				} else {
					$on_form ||= $found ||= 1;
				}
				$last_form = $f;
			}
			$on_form or next;
		} else {
			# form要素の中でない。
			next;
		}

		if( $no_filter_text || $elem->isElement )
		{
			# elem is always 'input'.
				my $name = $elem->attr('name');
				if( defined($name) )
				{
					$name = $TL->unescapeTag($name);
					my $type = $elem->attr('type');
					$type &&= lc $type;

					if(!defined($type)
					|| $type eq '' 
					|| $type eq 'text'
					|| $type eq 'password'
					|| $type eq 'hidden'
					|| $type eq 'submit') {
						if($form->exists($name)) {
							# valueを書換える
							$elem->attr(
								value => $TL->escapeTag(__popform($form, $name))
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
		} elsif($elem->isText) {
			if(my $textarea = $context->in('textarea')) {
				if(defined(my $name = $textarea->attr('name'))) {
					$name = $TL->unescapeTag($name);

					if($form->exists($name)) {
						# textareaの中身を置き換える
						$elem->str(
							$TL->escapeTag(__popform($form, $name)));
					}
				}
			} elsif(my $option = $context->in('option')) {
				my $select = $context->in('select');
				if($select && defined(my $name = $select->attr('name'))) {
					$name = $TL->unescapeTag($name);

					my $value = do {
						my $str = $option->attr('value');
						if(defined($str)) {
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
		die __PACKAGE__."#setForm: form [$name] does not exist. (form [$name] が存在しません)\n";
	}

	$this->setHtml($filter->toStr);

	$this;
}

sub extForm {
	my $this = shift;
	my $name = shift;

	if(ref($name)) {
		die __PACKAGE__."#extForm: arg[1] is a reference. (第1引数がリファレンスです)\n";
	}

	if(!defined $name) {
		$name = '';
	}

	$TL->getDebug->_templateLog(
		node => $this,
		type => 'extForm',
		name => $name,
	);

    $this->_dieIfAnyUnexpandedTag('extForm');

	my $filter = $TL->newHtmlFilter(
		interest => ['form'],
		filter_text => 0,
	);
	$filter->set($this->_compose);

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
		die __PACKAGE__."#extForm: form [$name] does not exist. (form [$name] が存在しません)\n";
	}

	$this->setHtml($filter->toStr);

	$this;
}

sub addHiddenForm {
	my $this = shift;
	my $form = shift;
	my $name = shift;

	if(!defined($form)) {
		die __PACKAGE__."#addHiddenForm: arg[1] is not defined. (第1引数が指定されていません)\n";
	} elsif(ref($form) eq 'HASH') {
		$form = $TL->newForm($form);
	} elsif(ref($form) ne 'Tripletail::Form') {
		die __PACKAGE__."#addHiddenForm: arg[1] is not an instance of Tripletail::Form or HASH. (第1引数がFormオブジェクトではありません)\n";
	}
	if(ref($name)) {
		die __PACKAGE__."#addHiddenForm: arg[2] is a reference. (第2引数がリファレンスです)\n";
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

    $this->_dieIfAnyUnexpandedTag('addHiddenForm');

	my $filter = $TL->newHtmlFilter(
		interest => ['form'],
	);
	$filter->set($this->_compose);

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
		die __PACKAGE__."#addHiddenForm: form [$name] does not exist. (form [$name] が存在しません)\n";
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
		die __PACKAGE__."#addSessionCheck: arg[1] is not defined. (第1引数が指定されていません)\n";
	}
	my $session = $TL->getSession($sessiongroup);
	if(ref($name)) {
		die __PACKAGE__."#addSessionCheck: arg[2] is a reference. (第2引数がリファレンスです)\n";
	}
	if(ref($issecure)) {
		die __PACKAGE__."#addSessionCheck: arg[3] is a reference. (第3引数がリファレンスです)\n";
	}

	my $csrfkey = $TL->INI->get($sessiongroup => 'csrfkey', undef);
	if(!defined($csrfkey)) {
		die __PACKAGE__."#addSessionCheck: csrfkey is not defined for the INI group [$sessiongroup]. (INI [$sessiongroup] で csrfkey を設定してください)\n";
	}

	do {
		local $SIG{__DIE__} = 'DEFAULT';
		eval 'use Digest::HMAC_SHA1 qw(hmac_sha1_hex)';
	};
	if($@) {
		die __PACKAGE__."#addSessionCheck: failed to load Digest::HMAC_SHA1 [$@] (Digest::HMAC_SHA1が使用できません)\n";
	}

	my ($key, $sid, $checkval) = $session->getSessionInfo($issecure);
	
	if(!defined($sid)) {
        die __PACKAGE__."#addSessionCheck: no session ID has been created. You must prepare one before. (セッションがありません。事前にセッションを生成してください)\n";
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

    $this->_dieIfAnyUnexpandedTag('addSessionCheck');

	my $filter = $TL->newHtmlFilter(
		interest => ['form'],
	);
	$filter->set($this->_compose);

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
					die __PACKAGE__."#addSessionCheck: the method type of the form isn't `post'. (formがpostメソッドではありません)\n"
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
		die __PACKAGE__."#addSessionCheck: form [$name] does not exist. (form [$name] が存在しません)\n";
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
		die __PACKAGE__."#setHtml: arg[1] is not defined. (第1引数が指定されていません)\n";
	} elsif(ref($html)) {
		die __PACKAGE__."#setHtml: arg[1] is a reference. (第1引数がリファレンスです)\n";
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
		die __PACKAGE__."#$method: node [".$dirty->_nodePath."] has been modified but not added to the parent.".
			" (node [".$dirty->_nodePath."] は変更されていますがaddされていません)\n";
	}

	$this;
}

sub _dieIfAnyUnexpandedTag {
	my $this = shift;
	my $method = shift;

	# 値の定義されていない挿入タグが残っていたらエラー。(expandAll や
	# flushなどがある為、これが起こり得る。)
	my $valmap = $this->{valmap};
	foreach my $seg (@{$this->{tmpltags}}) {
			if( $seg->[0] eq 'tag' )
			{
				if( !defined($valmap->{${$seg->[2]}}) )
				{
					die __PACKAGE__."#$method: tag [$seg->[1]] has been left unexpanded. (tag [$seg->[1]] が展開されていません)\n";
				}
			}
	}

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
				
				die __PACKAGE__."#flush: node [$mark] has been already flushed. (node [$mark] は既にflush済みです)\n";
			}

			while(my $seg = shift @{$this->{tmplvec}}) {
				if(ref($seg)) {
					if($seg->[0] eq 'tag') {
						my $ref = \$this->{valmap}{${$seg->[2]}};

						if(defined($$ref)) {
							$ret .= $$ref;
						} else {
							die __PACKAGE__."#flush: tag [$seg->[1]] has been left unexpanded. (tag [$seg->[1]] が展開されていません)\n";
						}
					} elsif($seg->[0] eq 'mark' || $seg->[0] eq 'copy') {
						my $ref = \$this->{valmap}{${$seg->[2]}};

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
						die "internal error: unknown segment type: $seg->[0] (内部エラー:未知の segment type)";
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
				$this->_dieIfAnyUnexpandedTag('flush');
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
			die __PACKAGE__."#expand: the value for key [$key] is not defined. (key [$key] の値が指定されていません)\n";
		} elsif(ref($val)) {
			die __PACKAGE__."#expand: the value for key [$key] is a reference. [$val] (key [$key] の値がリファレンスです)\n";
		}
		
		$key = lc($key);
		$val = $this->_filter($key, $val);

		$this->{valmap}{"tag:$key"} = $val;
	}

    if (not $allow_unexpanded) {
        $this->_dieIfAnyUnexpandedTag('expand');
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
		die __PACKAGE__."#_filter: internal state error. (内部状態エラー)\n";
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

	foreach my $cache (@_SPLIT_CACHE)
	{
		if( $cache->{src} eq $src )
		{
			$this->{tmplvec}  = [ @{$cache->{vec}}  ];
			$this->{tmpltags} = [ @{$cache->{tags}} ];
			$this->{tmplback} = [ @{$cache->{vec}}  ] if($tmpwrite);
			$this->{valmap} = {};
			return;
		}
	}
	
	my $vec = [];
	my %tags;

	foreach my $part (split $re_split, $src) {
		defined $part or next;
		length $part or next;

		if(substr($part, 0, 1) ne '<') {
			push @$vec, $part;
		}
        else {
            # \((keys%{{"tag:$key"=>1}})[0]) は意味的には \"tag:$key" と等価であ
            # るはずだが、何と前者の方が速度が出るらしい。ちなみにわざわざ
            # SCALAR Ref にしている理由は、そうしないと SV 内に保存されたハッシュ
            # 値のキャッシュが使われない為。
            
			if($part =~ m/<&(.+?)>/) {
				my $key = lc $1;
				my $elm = [tag => $key, \((keys%{{"tag:$key"=>1}})[0]) ];
				push @$vec, $elm;
				$tags{${$elm->[2]}} ||= $elm;
			}
            elsif($part =~ m/<!(mark|copy):(.+?)>/) {
				my $key = lc $2;
				push @$vec, [$1 => $key, \((keys%{{"node:$key"=>1}})[0]) ];
			}
            else {
				push @$vec, $part;
			}
		}
	}

	my $tags = [ values %tags ];
	push(@_SPLIT_CACHE, +{
		src  => $src,
		vec  => $vec,
		tags => $tags,
	});
	
	$this->{tmplvec}  = [ @$vec  ];
	$this->{tmpltags} = [ @$tags ];
	$this->{tmplback} = [ @$vec  ] if($tmpwrite);
	$this->{valmap}   = {};
}

# テンプレート処理を施した結果を作る.
sub _compose {
	# このメソッドの動作速度は重要。
	my $this = shift;
	my $opts = { @_ };
	my $ret = '';
	
	my $save_marks = $opts->{save_marks};

	if (!$save_marks) {
		foreach my $seg (@{$this->{tmplvec}}) {
			if(ref $seg ) {
				my $val = $this->{valmap}{${$seg->[2]}};
				
				if(defined $val) {
					$ret .= $val;
				}
				
				# save_marks 処理は省略.
			}
            else {
				$ret .= $seg;
			}
		}
	}
    else {
		foreach my $seg (@{$this->{tmplvec}}) {
			if (ref($seg)) {
				my $val = $this->{valmap}{${$seg->[2]}};
                
				if (defined $val) {
                    $ret .= $val;
                }
	
				# save_marks 処理.
                if ($seg->[0] eq 'tag') {
					if (!defined $val) {
						$ret .= sprintf '<&%s>', $seg->[1];
					}
				}
                else {
                    $ret .= sprintf '<!%s:%s>', $seg->[0], $seg->[1];
                }
            }
            else {
				$ret .= $seg;
			}
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
