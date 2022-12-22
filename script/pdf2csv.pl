#!/usr/bin/perl -w

# Author          : Johan Vromans
# Created On      : Mon Nov  5 18:39:01 2018
# Last Modified By: 
# Last Modified On: Thu Dec 22 08:46:43 2022
# Update Count    : 208
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use utf8;

# Package name.
my $my_package = 'MSPTools';
# Program name and version.
my ($my_name, $my_version) = qw( pdf2csv 0.04 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $csvfile;
my @tags;
my %tags;
my $overlap;
my $verbose = 1;		# verbose processing

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $trace = 0;			# trace (show process)
my $test = 0;			# test mode.

# Process command line options.
app_options();

# Post-processing.
$trace |= ($debug || $test);

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

use PDF::API2 2.042;

my @t = ( time );		# for speed stats

# Open.
my $pdffile = $ARGV[0];
my $pdf = PDF::API2->open($pdffile) || die("$pdffile: $!\n");

push( @t, time );

if ( $csvfile && $csvfile ne "-" ) {
    open( STDOUT, '>', $csvfile );
}
binmode( STDOUT, ':utf8' );
binmode( STDERR, ':utf8' );

my $ol = outlines($pdf);
die("No outline?\n") unless $ol;

print( "title;pages;");
foreach ( @tags ) {
    print( "$_;" );
}
print( "\n");

my @items;
if ( $overlap ) {
    @items = sort { $a->[1] cmp $b->[1] } @$ol; # ????
}
else {
    @items = sort { $a->[1] <=> $b->[1] } @$ol;
}
push( @items, $items[-1] );

for ( my $i = 0; $i < @items-1; $i++ ) {

    my %v = ( title     => $items[$i][0],
	      startpage => $items[$i][1],
	      endpage   => $items[$i+1][1]-1,
	      pagecount => $pdf->page_count );

    my $ep =  $overlap ? $v{pagecount} : $v{endpage};
    $v{pages} = $ep > $v{startpage}
      ? join( "-", $v{startpage}, $ep )
      : $v{startpage};

    my %n;
    for my $t ( @tags ) {
	$n{$t} = $tags{$t};
	$n{$t} =~ s;\%\{(.+?)\};$v{$1};ge;
    }
    $v{$_} = $n{$_} for keys %n;

    print( join( ";",
		 map { $v{$_} } qw( title pages ), @tags ),
	   ";\n" );
}

warn( "Open: ",     $t[1]-$t[0], "s, ",
      "Pages: ",    $t[2]-$t[1], "s, ",
      "Outlines: ", $t[3]-$t[2], "s\n" );

################ Subroutines ################

use Encode qw(decode :fallbacks);

my $_pages;
sub outlines {
    my ( $pdf ) = @_;

    unless ( $_pages ) {
	for ( 1 .. $pdf->pages ) {
	    $_pages->{ "".$pdf->openpage($_) } = $_;
	}
	push( @t, time );
    }
    my $outline = $pdf->outlines;
    my $count = $outline->count;
    warn("Children: ", $outline->has_children ? $count : "No", "\n") if $trace;
    my $child = $outline->first;
    my $res = [];

    my $p; $p = sub {		# you know why
	my ( $this, $lvl ) = @_;
	$lvl ||= 1;

	while ( $this ) {

	    if ( $this->has_children ) {
		# This prevents a crash Can't locate object method "has_children"
		$this->_load_children;
		warn( "Children[$lvl](",
		      pdfstring( $this->title ),
		      "): ", $this->count,
		      "\n") if $trace;
		$p->( $this->first, $lvl+1 );
		$this = $this->next;
		next;
	    }

	    my $title = pdfstring( $this->title );
	    warn( $lvl, " ", $title, "\n" ) if $trace;

	    my $ol = $this->val;
	    my $dst;
	    if ( exists( $ol->{Dest} ) ) {
		warn("using Dest\n") if $debug;
		$dst = $ol->{Dest}->val;
		$dst = $_pages->{"".$dst} // $_pages->{"".($dst->[0])};
	    }
	    else {
		warn("using A\n") if $debug;
		$ol = $ol->{A}->val;
		if ( exists($ol->{S})
		     && ( $ol->{S} eq "/GoTo" || $ol->{S}->val eq "GoTo" ) ) {
		    warn("using GoTo\n") if $debug;
		    my $v = $ol->{D}->val;
		    if ( ref($v) eq 'ARRAY' && ref($v->[0]) eq 'PDF::API2::Page' ) {
			$dst = $_pages->{"".($v->[0])};
		    }
		    else {
			# Named destination.
			$dst = destpage($v);
			warn("Page ", $v, " => $dst\n") if $trace;
		    }
		}
		else {
		    warn("using D\n") if $debug;
		    $dst = $ol->{D}->val;
		}
	    }
	    warn("dest = $dst\n") if $debug;

	    push( @$res, [ $title, $dst ] );
	    $this = $this->next;
	}
    };

    $p->($child);
    push( @t, time );
    return $res;
}

my $pdfdocencoding_support;

sub pdfstring {
    my ( $str ) = @_;

    # Default encoding is PDFDocEncoding. Need Encode::PDFCodc module.
    my $enc = 'PDFDoc';
    my $check = FB_DEFAULT;

    # Handle BOM, if present.
    if ( $str =~ /^\xef\xbb\xbf(.*)/s ) { # ï»¿
	$enc = 'UTF-8'; $str = $1;
    }
    elsif ( $str =~ /^\xfe\xff(.*)/s ) { # þÿ
	$enc = 'UTF-16BE'; $str = $1;
    }
    elsif ( $str =~ /^\xff\xfe(.*)/s ) { # ÿþ
	$enc = 'UTF-16LE'; $str = $1;
    }
    elsif ( $str =~ /^\xff\xfe\x00\x00(.*)/s ) { # ÿþ\0\0
	$enc = 'UTF-32LE'; $str = $1;
    }
    elsif ( $str =~ /^\x00\x00\xfe\xff(.*)/s ) { # \0\0þÿ
	$enc = 'UTF-32BE'; $str = $1;
    }
    elsif ( $str =~ /^[[:ascii:]]*\Z/ ) {
	$enc = 'ASCII';
    }

    if ( $enc eq 'PDFDoc' ) {
	unless ( defined $pdfdocencoding_support ) {
	    $pdfdocencoding_support = 0;
	    eval { require Encode::PDFDoc;
		   $pdfdocencoding_support = 1;
	       }
	      or
	      warn("Warning: No support for PDFDocEncoding.\n",
		   "Some characters may yield surprising results.\n");
	}
	$enc = 'ASCII' unless $pdfdocencoding_support;
    }

    return decode( $enc, $str, $check );
}

sub destpage {
    my ( $target ) = @_;

    my $tree = eval { $pdf->{catalog}->{Names}->val->{Dests}->val };
    warn( "No page tree found", "\n" ), return unless $tree;

    my $page = _search( $tree, $target );
    warn( $page ? "Page $page" : "Not found", "\n" ) if $trace;
    return $page;
}

sub _search {
    my ( $tree, $target ) = @_;

    my $limits = $tree->{Limits}->val;
    my ( $min, $max ) = ( pdfstring($limits->[0]->val),
			  pdfstring($limits->[1]->val) );
    warn( "Limits: $min -> $max\n" ) if $debug;

    return if $target lt $min;

    if ( $target le $max ) {
	warn("Target $target <= $max\n") if $debug;
	if ( exists $tree->{Kids} ) {
	    my $kids = $tree->{Kids}->val;
	    foreach ( @$kids ) {
		my $found = _search( $_->val, $target );
		return $found if $found;
	    }
	}
	else {
	    my $names = $tree->{Names}->val;
	    for ( my $i = 0; $i < @$names-1; $i++ ) {
		my $key = $names->[$i];
		if ( pdfstring($key->val) eq $target ) {
		    my $d = $names->[$i+1]->val->{D}->val->[0];
		    return $d->{' pnum'};
		}
	    }
	}
    }
}

sub showkeys {
    warn( "'", join("', '", sort(keys(%{shift()}))), "'\n");
}

################ Subroutines ################

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally
    my $man = 0;		# handled locally
    my @t;

    my $pod2usage = sub {
        # Load Pod::Usage only if needed.
        require Pod::Usage;
        Pod::Usage->import;
        &pod2usage;
    };

    # Process options.
    if ( @ARGV > 0 ) {
	GetOptions( 'csvfile=s' => \$csvfile,
		    'extra|x=s'	=> \@t,
		    'overlap'	=> \$overlap,
		    'ident'	=> \$ident,
		    'verbose+'	=> \$verbose,
		    'quiet'	=> sub { $verbose = 0 },
		    'trace'	=> \$trace,
		    'help|?'	=> \$help,
		    'man'	=> \$man,
		    'debug'	=> \$debug )
	  or $pod2usage->( -exitval => 2, -verbose => 0 );
    }
    for ( @t ) {
	$pod2usage->( -exitval => 2, -verbose => 0 )
	  unless /^(\w+)=(.*)/;
	$tags{$1} = $2;
	push( @tags, $1 );
    }
    if ( $ident or $help or $man ) {
	print STDERR ("This is $my_package [$my_name $my_version]\n");
    }
    if ( $man or $help ) {
	$pod2usage->( -exitval => 0, -verbose => $man ? 2 : 0 );
    }
    if ( @ARGV != 1 ) {
	$pod2usage->( -exitval => 3, -verbose => 0 );
    }
}

__END__

################ Documentation ################

=head1 NAME

pdf2csv - extract pages info from PDF outline

=head1 SYNOPSIS

pdf2csv [options] file

 Options:
   --csvfile=XXX	CSV file to output, default is standard output
   --overlap		overlapping pages
   --extra|x KEY=VALUE  additional fields in the CSV
   --ident		shows identification
   --help		shows a brief help message and exits
   --man                shows full documentation and exits
   --verbose		provides more verbose information
   --quiet		runs as silently as possible

=head1 OPTIONS

=over 8

=item B<--csvfile=>I<XXX>

Write the resultant CSV data to the specified file.

Default is to write to standard output.

=item B<--overlap>

The items have overlapping pages. Instead of an end page derived from
the start of the next item, all items get the last page of the file as
end page.

=item B<--extra> B<-x> KEY=VAL

Add additional fields with value I<VAL> to the CSV.

I<VAL> may contain substitution strings in the form C<%{XXX}>, where
I<XXX> can be one of C<startpage>, C<endpage>, C<pages> (the page range) and
C<pagecount> (the number of pages in the PDF.

This may be repeated.

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

Provides more verbose information.
This option may be repeated to increase verbosity.

=item B<--quiet>

Suppresses all non-essential information.

=item I<file>

The input PDF document.

=back

=head1 DESCRIPTION

B<This program> will read the outline of the given PDF document
and tries to create a CSV file with pages info, suitable for
importing in tools like MobileSheetsPro.

=head1 REQUIREMENTS

You need a fairly recent version of L<PDF::API2>.

Some PDF documents use a PDF-specific encoding for outlines. You need
to install L<Encode::PDFDoc> to support this.

=cut
