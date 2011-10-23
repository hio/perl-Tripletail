package CustomFilter;
use strict;
use warnings;
use Tripletail;

1;


# フィルタモジュールを作成します．
# _new，print，flush の３つのメソッドを実装します．
#
# 各メソッドの動作については，Tripletail::Filter の
# ドキュメントと，下記のコメントを参照してください．

# このフィルタでは以下の処理をします．
# ・タグの途中で出力がとぎれている場合は，その部分を
# 　バッファに保存しておき，次回処理します．
# ・目的のタグ <#TIME> があった場合は，現在時刻に展開します．

sub _new {
    # フィルタの初期化
    # デフォルトの実装をそのまま流用し，
    # タグ断片の保持変数の初期化のみ行う．
    # 
    # setContentFilter の際にオプション指定をすれば，
    # オプションも渡されるが，ここでは使用していない．
    
    my $class = shift;
    my $this = bless {} => $class;

    my %opts = @_; # オプションがある場合はここで受け取る

    $this->{buffer} = ''; # タグの断片を保持

    $this;
}

sub print {
    # フィルタへ入力があると呼び出され，次のフィルタへ
    # 渡すデータを返す．
    # ヘッダ・ボディ両方がこの関数を経由して出力されるが，
    # 不足しているヘッダは，このフィルタの後に呼び出される
    # HTML フィルタによって補完されるため，ここでは考慮しない．
    
    my $this = shift;
    my $data = shift;

    $data = $this->{buffer} . $data;
    $this->{buffer} = '';
    if($data =~ s/(<[^>]+)$//) {
      $this->{buffer} .= $1;
    }

    $data =~ s/<#TIME>/localtime.''/ie;

    $data;
}

sub flush {
    # フィルタへの入力データが無くなると，
    # 最後にこのメソッドが呼び出される．
    # バッファしているデータがあれば返さなければならない．
    #
    # フィルタオブジェクトは，FastCGI時は複数のリクエストで
    # 使い回されるため，内部データはこの関数内で
    # 初期化しておく必要がある．
    
    my $this = shift;

    my $output = $this->{buffer};
    $this->{buffer} = '';

    $output;
}



