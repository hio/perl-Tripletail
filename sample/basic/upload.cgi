#!/usr/bin/perl

use strict;
use warnings;

use Tripletail q(upload.ini);

$TL->startCgi(
	      -main => \&main,
	     );


sub main {
  my $t = $TL->newTemplate('upload.html');

  # データは通常のフォームと同様に入ってきますが，
  # 文字コードの自動変換は行われません．
  # ファイル名は，->getFilename メソッドで取得できます．
  
  if($CGI->exists('file')) {
    $t->node('file')
      ->add(FILENAME => $CGI->getFilename('file'),
	    FILEDATA => $CGI->get('file'),
	   );
  }
  
  $t->flush;

}



