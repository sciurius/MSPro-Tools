#!/usr/bin/perl -w

# Author          : Johan Vromans
# Created On      : Sun Jun  7 21:58:04 2015
# Last Modified By: Johan Vromans
# Last Modified On: Mon Jun 15 13:52:03 2015
# Update Count    : 133
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;

use FindBin;

use lib "$FindBin::Bin/../lib";

# Package name.
my $my_package = 'MSProTools';
# Program name and version.
my ($my_name, $my_version) = qw( get_meta 0.02 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $dbname = "mobilesheets.db";
my $output;
my $annotations = 0;		# include annotations
my $verbose = 0;		# verbose processing

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

use MobileSheetsPro::DB;
use DBI;
use Data::Dumper;
use JSON;

my @filetypes  = ( 'Image', 'PDF', undef, 'ChordPro' );
my @anntypes   = qw( text draw highlight stamp );
my @aligntypes = qw( left right center );
my @drawtypes  = qw( line rectangle circle freehand );

db_open( $dbname, { RaiseError => 1, Trace => $trace } );

my $meta = [];

my $ret = dbh->selectall_arrayref( "SELECT Id, Title, SortTitle" .
				   " FROM Songs ORDER BY Id" );

foreach ( @$ret ) {
    my ( $songid, $title, $stitle ) = @$_;
    warn( "Song[$songid]: $title\n" ) if $trace;

    push( @$meta,
	  { title     => $title,
	    sorttitle => $stitle,
	    $trace ? ( songid => $songid ) : (),
	    paths     => [],
	  } );

    my $ret = dbh->selectall_arrayref( "SELECT Id, Path, Source, Type" .
				       " FROM Files" .
				       " WHERE SongID = $songid".
				       " ORDER BY Id" );

    foreach ( @$ret ) {
	my ( $fileid, $path, $source, $type ) = @$_;
	warn( "Path[$fileid]: $path\n" ) if $trace;

	my $mp =
	  { path   => $path,
	    $trace ? ( fileid => $fileid ) : (),
	    source => lookup( qw(SourceType Type), $source),
	    type   => $filetypes[$type] // $type,
	  };
	push( @{ $meta->[-1]->{paths} }, $mp );


	# Capo / Transpose.
	my $ret = dbh->selectall_arrayref
	  ( "SELECT Capo,EnableCapo,Transpose,EnableTranpose".
	    " FROM TextDisplaySettings".
	    " WHERE SongId = $songid AND FileId = $fileid" );

	if ( $ret && $ret->[0] ) {
	    $ret = $ret->[0];
	    $mp->{capo}		   = $ret->[0] if     $ret->[0];
	    $mp->{enablecapo}	   = $ret->[1] unless !$ret->[0] || $ret->[1];
	    $mp->{transpose}	   = $ret->[2] if     $ret->[2];
	    $mp->{enabletranspose} = $ret->[3] unless !$ret->[2] || $ret->[3];
	}

    }

    my $std = sub {
	my ( $Table, $STable ) = @_;
	$STable //= $Table . 'Songs';
	my $TableId = $Table . "Id";
	$TableId =~ s/sId$/Id/;
	my $ret = dbh->selectall_arrayref
	  ( "SELECT Name FROM $Table,$STable".
	    " WHERE $TableId = $Table.Id".
	    " AND SongID = $songid" );
	my $tag = lc($Table);
	$tag .= 's' unless $tag =~ /s$/;
	$meta->[-1]->{$tag} = [ map { $_->[0] } @$ret ]
	  if $ret && @$ret;
    };

    $std->( qw( Artists ) );
    $std->( qw( Composer ) );
    $std->( qw( Collections CollectionSong ) );
    $std->( qw( Key ) );
    $std->( qw( Signature ) );

    # Tempi.
    $ret = dbh->selectall_arrayref
      ( "SELECT Tempo".
	" FROM Tempos".
	" WHERE SongId = $songid ".
	"ORDER BY TempoIndex" );

    my @t;
    foreach ( @$ret ) {
	push( @t, $_->[0] );
    }
    $meta->[-1]->{tempos} = \@t if @t;

    $ret = [];
    $ret = dbh->selectall_arrayref( "SELECT Id, Page, Type, GroupNum,".
				    " Alpha, Zoom, ZoomY, Version" .
				    " FROM AnnotationsBase" .
				    " WHERE SongID = $songid" .
				    " ORDER BY Page,GroupNum,Id" )
      if $annotations;

    my $ann = [];

    foreach ( @$ret ) {
	my ( $annid, $page, $type, $group, $alpha,
	     $zoomx, $zoomy, $version) = @$_;
	my $a = { $trace ? ( annid => $annid ) : (),
		  type	   => $anntypes[$type] // $type,
		  alpha	   => $alpha,
		  zoom	   => [ $zoomx, $zoomy ],
		  version  => $version,
		};
	if ( $type == 0 ) {	# text
	    $ret = dbh->selectall_arrayref
	      ( "SELECT TextColor, Text, FontFamily, FontSize, FontStyle,".
		" FillColor, BorderColor, TextAlign, HasBorder,".
		" BorderWidth, AutoSize, Density".
		" FROM TextboxAnnotations" .
		" WHERE BaseId = $annid " .
		" ORDER BY Id" );
	    warn("Multiple results for annid = $annid\n") unless @$ret == 1;
	    ( $a->{textcolor},
	      $a->{text},
	      $a->{font}->{family},
	      $a->{font}->{size},
	      $a->{font}->{style},
	      $a->{fillcolor},
	      $a->{bordercolor},
	      $a->{textalign},
	      $a->{hasborder},
	      $a->{borderwidth},
	      $a->{autosize},
	      $a->{density},
	    ) = @{ $ret->[0] };
	    for ( qw( textcolor fillcolor bordercolor ) ) {
		$a->{$_} = make_colour( $a->{$_} );
	    }
	    $a->{textalign} = $aligntypes[$a->{textalign}] // $a->{textalign};
	}
	elsif ( $type == 1 || $type == 2 ) {	# draw / highlight
	    $ret = dbh->selectall_arrayref
	      ( "SELECT LineColor, FillColor, LineWidth, DrawMode,".
		" PenMode, SmoothMode".
		" FROM DrawAnnotations" .
		" WHERE BaseId = $annid " .
		" ORDER BY Id" );
	    warn("Multiple results for annid = $annid\n") unless @$ret == 1;
	    ( $a->{linecolor},
	      $a->{fillcolor},
	      $a->{linewidth},
	      $a->{drawmode},
	      $a->{penmode},
	      $a->{smoothmode},
	    ) = @{ $ret->[0] };
	    for ( qw( linecolor fillcolor ) ) {
		$a->{$_} = make_colour( $a->{$_} );
	    }
	    $a->{drawmode} = $drawtypes[$a->{drawmode}] // $a->{drawmode};
	}
	elsif ( $type == 3 ) {	# stamp
	    $ret = dbh->selectall_arrayref
	      ( "SELECT StampIndex, CustomSymbol, StampSize".
		" FROM StampAnnotations" .
		" WHERE BaseId = $annid " .
		" ORDER BY Id" );
	    warn("Multiple results for annid = $annid\n") unless @$ret == 1;
	    ( $a->{stampindex},
	      $a->{customsymbol},
	      $a->{stampsize},
	    ) = @{ $ret->[0] };
	}


	my $sth = dbh->prepare( "SELECT PointX, PointY".
				" FROM AnnotationPath" .
				" WHERE AnnotationId = $annid " .
				" ORDER BY Id" );
	$sth->bind_columns( \my ( $x, $y ) );
	$sth->execute;
	my @p;
	while ( $sth->fetch ) {
	    push( @p, [ $x, $y ] );
	}
	$a->{path} = \@p;
	push( @{ $ann->[$page]->{$group} }, $a );
    }

    push( @{ $meta->[-1]->{annotations} }, $ann ) if @$ann;
}

my $json = JSON->new;
$json->ascii->pretty->allow_nonref;

if ( $output && $output ne "-" ) {
    open( STDOUT, ">:utf8", $output );
}

print STDOUT $json->encode($meta);

################ Subroutines ################

sub make_colour {
    my ( $col ) = @_;
    sprintf("#%06x", $col & 0xffffff)
}

################ Subroutines ################

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally
    my $man = 0;		# handled locally

    my $pod2usage = sub {
        # Load Pod::Usage only if needed.
        require Pod::Usage;
        Pod::Usage->import;
        &pod2usage;
    };

    # Process options.
    if ( @ARGV > 0 ) {
	GetOptions('ident'	=> \$ident,
		   'db=s',	=> \$dbname,
		   'output=s'	=> \$output,
		   annotations  => \$annotations,
		   'verbose'	=> \$verbose,
		   'trace'	=> \$trace,
		   'help|?'	=> \$help,
		   'man'	=> \$man,
		   'debug'	=> \$debug)
	  or $pod2usage->(2);
    }
    if ( $ident or $help or $man ) {
	print STDERR ("This is $my_package [$my_name $my_version]\n");
    }
    if ( $man or $help ) {
	$pod2usage->(1) if $help;
	$pod2usage->(VERBOSE => 2) if $man;
    }
}

__END__

################ Documentation ################

=head1 NAME

get_meta.pl - dump songs metadata from MSPro database in JSON format

=head1 SYNOPSIS

sample [options] [file ...]

 Options:
   --db=XXX		name of the MSPro database
   --output=XXX		name of the output file, default is standard output
   --annotations	include annotations
   --ident		show identification
   --help		brief help message
   --man                full documentation
   --verbose		verbose information

=head1 OPTIONS

=over 8

=item B<--db=>I<dbname>

Specifies the name of the MobileSheetsPro database.

Default is C<"mobilesheets.db">.

=item B<--output=>I<filename>

Specifies the name of the output file to write the JSON data to.

Default is standard output.

Print a brief help message and exits.

=item B<--annotations>

Includes the annotations in the meta data.

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

More verbose information.

=item I<file>

Input file(s).

=back

=head1 DESCRIPTION

This program will retrieve the metadata for all songs from the
MobileSheetsPro database and write it out in JSON format.

=cut
