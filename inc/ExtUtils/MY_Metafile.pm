## ----------------------------------------------------------------------------
#  ExtUtils::MY_Metafile
# -----------------------------------------------------------------------------
# Mastering programmed by YAMASHINA Hio
#
# Copyright 2006 YAMASHINA Hio
# -----------------------------------------------------------------------------
# $Id: MY_Metafile.pm,v 1.1 2006/10/20 07:06:48 hio Exp $
# -----------------------------------------------------------------------------
package ExtUtils::MY_Metafile;
use strict;
use warnings;

our $VERSION = '0.03';
our @EXPORT = qw(my_metafile);

our %META_PARAMS; # DISTNAME=>HASHREF.
our $DIAG_VERSION and &_diag_version;

1;

# -----------------------------------------------------------------------------
# for: use inc::ExtUtils::MY_Metafile;
#
sub inc::ExtUtils::MY_Metafile::import
{
	push(@inc::ExtUtils::MY_Metafile::ISA, __PACKAGE__);
	goto &import;
}

# -----------------------------------------------------------------------------
# import.
#
sub import
{
	my $pkg = shift;
	my @syms = (!@_ || grep{/^:all$/}@_) ? @EXPORT : @_;
	my $callerpkg = caller;
	
	foreach my $name (@syms)
	{
		my $sub = $pkg->can($name);
		$sub or next;
		no strict 'refs';
		*{$callerpkg.'::'.$name} = $sub;
	}
	if( !grep{ /^:no_setup$/ } @_ )
	{
		# override.
		*MM::metafile_target = \&_mm_metafile;
	}
}

# -----------------------------------------------------------------------------
# _diag_version();
#
sub _diag_version
{
	require ExtUtils::MakeMaker;
	my $mmver = $ExtUtils::MakeMaker::VERSION;
	if( $mmver >= 6.30 )
	{
		print STDERR "# ExtUtils::MY_Metafile for MM 6.30 or later ($mmver).\n";
	}else
	{
		print STDERR "# ExtUtils::MY_Metafile for MM 6.25 or earlier ($mmver).\n";
	}
}

# -----------------------------------------------------------------------------
# my_metafile($distname => $param);
# my_metafile($param);
#
sub my_metafile
{
	my $distname = @_>=2 && shift;
	my $param    = shift;
	UNIVERSAL::isa($distname,'HASH') and $distname = $distname->{DISTNAME};
	$distname ||= '';
	$distname =~ s/::/-/g;
	$META_PARAMS{$distname} and warn "# overwrite previous meta config $distname.\n";
	$META_PARAMS{$distname} = $param;
}

# -----------------------------------------------------------------------------
# _mm_metafile($MM)
#  altanative of MM::metafile_target.
#  takes $MM object and returns makefile text.
#
sub _mm_metafile
{
	my $this = shift;
	
	if( $this->{NO_META} )
	{
		return
			"metafile:\n" .
			"\t\$(NOECHO) \$(NOOP)\n";
	}
	
	# generate META.yml text.
	#
	my $meta = _gen_meta_yml($this);
	my @write_meta = (
		'$(NOECHO) $(ECHO) Generating META.yml',
		$this->echo($meta, 'META_new.yml'),
	);
	
	# format as makefile text.
	#
	my ($make_target, $metaout_file);
	if( $ExtUtils::MakeMaker::VERSION >= 6.30 )
	{
		$make_target  = "# for MM 6.30 or later.\n";
		$make_target .= "metafile : create_distdir\n";
		$metaout_file = '$(DISTVNAME)/META.yml';
	}else
	{
		$make_target  = "# for MM 6.25 or earlier.\n";
		$make_target .= "metafile :\n";
		$metaout_file  = 'META.yml',
	}
	
	my $rename_meta  = "-\$(NOECHO) \$(MV) META_new.yml $metaout_file";
	my $make_body = join('', map{"\t$_\n"} @write_meta, $rename_meta);
	"$make_target$make_body";
}

# -----------------------------------------------------------------------------
# _gen_meta_yml($MM);
#  generate META.yml text.
#
sub _gen_meta_yml
{
    # from MakeMaker-6.30.
    my $this = shift;
    my $param = shift;
    if( !$param )
    {
      $param = $META_PARAMS{$this->{DISTNAME}} || $META_PARAMS{''} || {};
    }
		if( $META_PARAMS{':all'} )
		{
			# special key.
			$param = { %{$META_PARAMS{':all'}}, %$param };
		}
    
    # requires:
    my $requires = $param->{requires} || $this->{PREREQ_PM};
    my $prereq_pm = '';
    foreach my $mod ( sort { lc $a cmp lc $b } keys %$requires ) {
        my $ver = $this->{PREREQ_PM}{$mod};
        $prereq_pm .= sprintf "    %-30s %s\n", "$mod:", $ver;
    }
    chomp $prereq_pm;
    $prereq_pm and $prereq_pm = "requires:\n".$prereq_pm;

    # no_index:
    my $no_index = $param->{no_index};
    if( !$no_index )
    {
      my @dirs = grep{-d $_} (qw(example examples inc t));
      $no_index = @dirs && +{ directory => \@dirs };
    }
    $no_index = $no_index ? _yaml_out({no_index=>$no_index}) : '';
    chomp $no_index;
    if( $param->{no_index} && !$ENV{NO_NO_INDEX_CHECK} )
    {
      foreach my $key (keys %{$param->{no_index}})
      {
        # dir is in spec-v1.2, directory is from spec-v1.3? (blead).
        $key =~ /^(file|dir|directory|package|namespace)$/ and next;
        warn "$key is invalid field for no_index.\n";
      }
    }

    # abstract is from file.
    my $abstract = '';
    if( $this->{ABSTRACT} )
    {
      $abstract = _yaml_out({abstract => $this->{ABSTRACT}});
    }elsif( $this->{ABSTRACT_FROM} && open(my$fh, "< $this->{ABSTRACT_FROM}") )
    {
      while(<$fh>)
      {
        /^=head1 NAME$/ or next;
        (my $pkg = $this->{DISTNAME}) =~ s/-/::/g;
        while(<$fh>)
        {
          /^=/ and last;
          /^(\Q$pkg\E\s+-+\s+)(.*)/ or next;
          $abstract = $2;
          last;
        }
        last;
      }
      $abstract = $abstract ? _yaml_out({abstract=>$abstract}) : '';
    }
    chomp $abstract;
    
    # build yaml object as hash.
    my $yaml = {};
    $yaml->{name}         = $this->{DISTNAME};
    $yaml->{version}      = $this->{VERSION};
    $yaml->{version_from} = $this->{VERSION_FROM};
    $yaml->{installdirs}  = $this->{INSTALLDIRS};
    $yaml->{author}       = $this->{AUTHOR};
    foreach my $key (keys %$yaml)
    {
      if( $yaml->{$key} )
      {
        my $pad = ' 'x(12-length($key));
        $yaml->{$key} = sprintf('%s:%s %s', $key, $pad, $yaml->{$key});
      }else
      {
        $yaml->{$key} = "#$key:";
      }
    }
    $yaml->{abstract} = $abstract  || "#abstract:";
    $yaml->{requires} = $prereq_pm || "#requires:";
    $yaml->{no_index} = $no_index;
    
    $yaml->{distribution_type} = 'distribution_type: module';
    $yaml->{generated_by} = "generated_by: ExtUtils::MY_Metafile version $VERSION";
    $yaml->{'meta-spec'}  = "meta-spec:\n";
    $yaml->{'meta-spec'} .= "  version: 1.2\n";
    $yaml->{'meta-spec'} .= "  url: http://module-build.sourceforge.net/META-spec-v1.2.html\n";
    
    # customize yaml.
    my $extra = '';
    foreach my $key (sort keys %$param)
    {
      $key eq 'no_index' and next;
      my $line = _yaml_out->({$key=>$param->{$key}});
      if( $yaml->{$key} )
      {
        chomp $line;
        $yaml->{$key} = $line;
      }else
      {
        $extra .= $line;
      }
    }
    $yaml->{extra}    = $extra;
    
    # packing into singple text.
    my $meta = <<YAML;
# http://module-build.sourceforge.net/META-spec.html
#XXXXXXX This is a prototype!!!  It will change in the future!!! XXXXX#
$yaml->{name}
$yaml->{version}
$yaml->{version_from}
$yaml->{installdirs}
$yaml->{author}
$yaml->{abstract}
$yaml->{requires}
$yaml->{no_index}
$yaml->{extra}
$yaml->{distribution_type}
$yaml->{generated_by}
$yaml->{'meta-spec'}
YAML
	#print "$meta";
	$meta;
}

# -----------------------------------------------------------------------------
# generate simple yaml.
#
sub _yaml_out
{
	my $obj   = shift;
	
	my $depth = shift || 0;
	my $out   = '';
	
	if( !defined($obj) )
	{
		$out = "  "x$depth."~\n";
	}elsif( !ref($obj) )
	{
		$out = "  "x$depth.$obj."\n";
	}elsif( ref($obj)eq'ARRAY' )
	{
		my @e = map{_yaml_out->($_, $depth+1)} @$obj;
		@e = map{ "  "x$depth."- ".substr($_, ($depth+1)*2)} @e;
		$out = join('', @e);
		$out ||= "  "x$depth."[]";
	}elsif( ref($obj)eq'HASH' )
	{
		foreach my $k (sort keys %$obj)
		{
			$out .= "  "x$depth."$k:";
			$out .= ref($obj->{$k}) ? "\n"._yaml_out($obj->{$k}, $depth+1) : " $obj->{$k}\n";
		}
		$out ||= "  "x$depth."{}";
	}else
	{
		die "not supported: $obj";
	}
	$out;
}

# -----------------------------------------------------------------------------
# End of Code.
# -----------------------------------------------------------------------------
__END__

=head1 NAME

ExtUtils::MY_Metafile - META.yml customize with ExtUtil::MakeMaker

=head1 VERSION

Version 0.03

=head1 SYNOPSIS

  # in your Makefile.PL
  use ExtUtils::MakeMaker;
  use inc::ExtUtils::MY_Metafile;
  
  my_metafile {
    no_index => {
      directory => [ qw(inc example t), ],
    },
    license  => 'perl',
  };
  
  WriteMakefile(
    DISTNAME => 'Your::Module',
    ...
  );

=head1 EXPORT

This module exports one function.

=head1 FUNCTIONS

=head2 my_metafile \%meta_param;

Takes one or two arguments.
First one is package name to be generated, and you can omit this 
argument.  Second is hashref which contains META.yml contents.

  my_metafile {
    no_index => {
      directory => [ qw(inc example t), ],
    },
    license  => 'perl',
  };

=head1 AUTHOR

YAMASHINA Hio, C<< <hio at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-extutils-my_metafile at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=ExtUtils-MY_Metafile>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc ExtUtils::MY_Metafile

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/ExtUtils-MY_Metafile>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/ExtUtils-MY_Metafile>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=ExtUtils-MY_Metafile>

=item * Search CPAN

L<http://search.cpan.org/dist/ExtUtils-MY_Metafile>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2006 YAMASHINA Hio, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# -----------------------------------------------------------------------------
# End of File.
# -----------------------------------------------------------------------------
