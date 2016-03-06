#! perl -w

# Author          : Johan Vromans
# Created On      : Sat May 30 13:10:48 2015
# Last Modified By: Johan Vromans
# Last Modified On: Sat Jun 20 19:46:34 2015
# Update Count    : 482
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

package MobileSheetsPro::Annotations::PDF;

use MobileSheetsPro::DB;
use Data::Dumper;
use PDF::API2;

use base qw(Exporter);
our @EXPORT = qw( flatten_song );
our @EXPORT_OK = @EXPORT;

my $verbose = 1;
my $debug = 1;

# Draw types.
use constant {
    DRAWTYPE_TEXT	=> 0,
    DRAWTYPE_PEN	=> 1,
    DRAWTYPE_HIGHLIGHT  => 2,
    DRAWTYPE_STAMP      => 3,
};

# Draw modes.
use constant {
    DRAWMODE_LINE	=> 0,
    DRAWMODE_RECTANGLE  => 1,
    DRAWMODE_CIRCLE     => 2,
    DRAWMODE_FREEHAND   => 3,
};

use constant {
    DPI_SCALE => 72/160,	# map Android screen resolution to PDF points
};

sub flatten_song {
    my ( $dbh, $songid, $songsrc, $pdfdst ) = @_;

    my $sth;
    my $r;
    my $xparent = 0;		# document with alpha

    my $title = lookup( qw( Songs Title ), $songid );
    die("Unknown song $songid\n") unless $title;
    warn("Processing song \"$title\"\n") if $verbose;

    my $pdf;
    if ( $songsrc && $songsrc =~ /\.pdf$/ ) {
	warn("Song file \"$songsrc\"\n") if $verbose;
	$pdf = PDF::API2->open($songsrc);
	# Consider PDFs to be transparent.
	$xparent++;
    }
    elsif ( $songsrc && $songsrc =~ /\.jpe?g$/ ) {
	warn("Song file \"$songsrc\"\n") if $verbose;
	$pdf = PDF::API2->new;
	my $jpg = $pdf->image_jpeg($songsrc);
	my $page = $pdf->page;
	$page->mediabox( 0, 0, DPI_SCALE * $jpg->width, DPI_SCALE * $jpg->height );
	$page->gfx->image( $jpg, 0, 0, DPI_SCALE  );
    }
    else {
	$pdf = PDF::API2->new;
    }
    # $pdf->{forcecompress} = 0; # testing

    my $font ||= $pdf->ttfont( $ENV{HOME}."/.fonts/DejaVuSans.ttf" );

    $sth = $dbh->prepare( "SELECT Id, Page, Type, GroupNum, Alpha,".
			  " Zoom, ZoomY, Version".
			  " FROM AnnotationsBase".
			  " WHERE SongId = ?".
			  "ORDER BY Page, Id" );

    $sth->bind_columns( \my ( $annid, $pageno, $type, $groupnum,
			      $alpha, $zoomx, $zoomy, $version ) );

    $sth->execute($songid);

    # Page being processed.
    my $page;
    my $curpage = -1;

    # Media box of current page.
    my @mb;

    while ( $sth->fetch ) {

	if ( $curpage != $pageno ) {
	    if ( $songsrc ) {
		$page = $pdf->openpage( $pageno + 1 );
	    }
	    else {
		$page = $pdf->page;
		$page->mediabox('A4');
	    }
	    @mb = $page->get_mediabox; # A4 = 595 x 842
	    $curpage = $pageno;
	    warn( sprintf( "page $curpage, mediabox %.3f %.3f %.3f %.3f\n", @mb ) )
	      if $debug;
	}

	# Coordinate transformations.
	# Since the transformations work different for text and graphics, we keep
	# all annotations in separate containers.
	my $mx = DPI_SCALE / $zoomx;
	my $my = DPI_SCALE / $zoomy;
	my $tr = sub {
	    my ( $g, $t1, $t2, $s1, $s2 ) = @_;
	    $t1 += $mb[0];
	    $t2 += $mb[3];
	    $s1 *= $mx;
	    $s2 *= $my;
	    warn( sprintf("xlat %.2f %.2f scale %.2f %.2f\n", $t1, $t2, $s1, $s2) )
	      if $debug;
	    $g->transform( -translate => [ $t1, $t2 ], -scale => [ $s1, $s2 ] );
	};

	#### Text annotations ####

	if ( $type == DRAWTYPE_TEXT ) {

	    my $sth = $dbh->prepare( "SELECT TextColor,Text,FontFamily,FontSize,FontStyle," .
				     "FillColor,BorderColor,TextAlign," .
				     "HasBorder,BorderWidth,AutoSize,Density" .
				     " FROM TextboxAnnotations" .
				     " WHERE BaseId = $annid" );
	    $sth->execute;
	    my $r = $sth->fetchall_arrayref;
	    warn( "Expecting a single result for annotation $annid, not ",
		  scalar(@$r), "\n" ) unless @$r == 1;

	    my ( $textcolor, $thetext, $fontfamily, $fontsize, $fontstyle,
		 $fillcolor, $bordercolor, $textalign,
		 $hasborder, $borderwidth, $autosize, $density ) = @{ $r->[0] };

	    $r = get_path( $dbh, $annid );

	    if ( $hasborder || $fillcolor ) {
		my $gfx = $page->gfx;
		$gfx->save;
		$tr->( $gfx, 0, 0, 1, -1 );
		$gfx->strokecolor( make_colour($bordercolor) );
		$gfx->fillcolor(   make_colour($fillcolor) ) if $fillcolor;
		$gfx->linewidth($borderwidth);

		warn( sprintf( "page $curpage, rect %.2f %.2f %.2f %.2f\n", @$r ) )
		  if $debug;
		$gfx->rectxy( $r->[0], $r->[1], $r->[2], $r->[3] );
		if ( $fillcolor && $hasborder ) {
		    $gfx->fillstroke;
		}
		elsif ( $fillcolor ) {
		    $gfx->fill;
		}
		else {
		    $gfx->stroke;
		}
		$gfx->restore;
	    }

	    my $text = $page->text;
	    $text->font($font, $fontsize);
	    $text->fillcolor( make_colour($textcolor) );
	    $text->strokecolor( make_colour($textcolor) );

	    $text->save;
	    $tr->( $text, $mx * $r->[4], - $my * $r->[5], 1, 1 );
	    if ( $textalign == 1 ) {
		$text->text_center($thetext);
	    }
	    elsif ( $textalign == 2 ) {
		$text->text_right($thetext);
	    }
	    else {
		$text->text($thetext);
	    }
	    $text->restore;
	}

	#### Drawing annotations ####

	elsif ( $type == DRAWTYPE_PEN || $type == DRAWTYPE_HIGHLIGHT ) {

	    my $sth = $dbh->prepare( "SELECT LineColor,FillColor,LineWidth,DrawMode" .
				     " FROM DrawAnnotations" .
				     " WHERE BaseId = ?" );

	    $sth->execute($annid);
	    $r = $sth->fetch;
	    unless ( $r && $r->[0] ) {
		die("No annotation info for song $songid\n");
	    }
	    my ( $linecolor, $fillcolor, $linewidth, $drawmode ) = @$r;

	    unless ( $drawmode == DRAWMODE_LINE      ||
		     $drawmode == DRAWMODE_RECTANGLE ||
		     $drawmode == DRAWMODE_CIRCLE    ||
		     $drawmode == DRAWMODE_FREEHAND ) {
		warn("Skipping annotation (drawmode = $drawmode)\n");
		next;
	    }

	    # Get a graphics content. For highlights, the annotations
	    # should go underneath. Note that this only works if the
	    # background is a transparent image or PDF.
	    my $gfx = $page->gfx( $type == DRAWTYPE_HIGHLIGHT && $xparent );

	    # Set transformations.
	    $gfx->save;
	    $tr->($gfx, 0, 0, 1, -1 );

	    # Make this object transparent if necessary.
	    if ( $type == DRAWTYPE_HIGHLIGHT && $alpha < 254 ) {
		my $extgs = $pdf->egstate;
		$extgs->transparency( $alpha / 255 );
		$gfx->egstate($extgs);
	    }

	    # Set graphics properties.
	    $gfx->strokecolor( make_colour($linecolor) );
	    $gfx->fillcolor(   make_colour($fillcolor) );
	    $gfx->linewidth($linewidth);
	    $gfx->linejoin(1);	# round
	    $gfx->linecap(1);	# round

	    if ( $drawmode == DRAWMODE_LINE ) {
		my $r = get_path( $dbh, $annid ); # 2 points
		warn( sprintf( "page $curpage, poly %.3f %.3f %.3f %.3f\n", @$r ) )
		  if $debug;
		$gfx->poly(@$r);
		$gfx->stroke;
	    }

	    elsif ( $drawmode == DRAWMODE_RECTANGLE ) {
		my $r = get_path( $dbh, $annid ); # 2 points
		warn( sprintf( "page $curpage, rect %.3f %.3f %.3f %.3f\n", @$r ) )
		  if $debug;
		$gfx->rectxy(@$r);
		$gfx->stroke;
	    }

	    elsif ( $drawmode == DRAWMODE_CIRCLE ) {
		my $r = get_path( $dbh, $annid ); # 1 point + radius
		warn( sprintf( "page $curpage, circel %.3f %.3f %.3f\n", @$r ) )
		  if $debug;
		$gfx->circle( $r->[0], $r->[1], $r->[2] - $r->[0] );
		$gfx->stroke;
	    }

	    else {	# $drawmode == DRAWMODE_FREEHAND

		my $r = get_path( $dbh, $annid ); # a lot of points
		my ( $px, $py ) = ( -1, -1 );     # previous point to suppress dups

		my @points;		# points currently on path

		while ( @$r ) {
		    my ( $x, $y ) = splice( @$r, 0, 2 );
		    if ( $x > 100000 && $y > 100000 ) { # MAX_FLOATs
			if ( @points ) {
			    # Finish stroke at next point.
			    push( @points, splice( @$r, 0, 2 ) );
			    warn( sprintf( "page $curpage, poly %.3f %.3f %.3f %.3f ...\n",
					   @points[0..3] ) ) if $debug;
			    $gfx->poly(@points);
			    $gfx->stroke;
			    $gfx->endpath;
			    @points = ();
			}
			else {
			    warn( "page $curpage, poly EMPTY\n" );
			}
			( $px, $py ) = ( -1, -1 );
			next;
		    }

		    next if $px == $x && $py == $y;
		    ( $px, $py ) = ( $x, $y );
		    push( @points, $x, $y );
		}
		if ( @points ) {
		    warn( sprintf( "page $curpage, poly %.3f %.3f %.3f %.3f ... UNFINISHED\n",
				   @points[0..3] ) );
		    $gfx->poly(@points);
		    $gfx->stroke;
		}
	    }

	    $gfx->restore;
	}

	elsif ( $type == DRAWTYPE_STAMP ) {

	    my $sth = $dbh->prepare( "SELECT StampIndex,StampSize" .
				     " FROM StampAnnotations" .
				     " WHERE BaseId = ?" );

	    $sth->execute($annid);
	    $r = $sth->fetch;
	    unless ( $r && $r->[0] ) {
		die("No annotation info for song $songid\n");
	    }
	    my ( $stampindex, $stampsize ) = @$r;

	    my $r = get_path( $dbh, $annid );

	    warn( sprintf( "stamp $stampindex @ %.2f %2f\n", @$r ) );

	    my $gfx = $page->gfx;
	    $gfx->fillcolor( "#FF00FF" );
	    $gfx->strokecolor( "#FF00FF" );

	    $gfx->save;
	    $tr->( $gfx, 0, 0, 1, -1 );
	    my $sz = $stampsize / 4;
	    $gfx->rect( $r->[0], $r->[1], $sz, $sz );
	    $gfx->poly( $r->[0], $r->[1], $r->[0] + $sz, $r->[1] + $sz );
	    $gfx->poly( $r->[0] + $sz, $r->[1], $r->[0], $r->[1] + $sz );
	    $gfx->stroke;
	    $gfx->restore;

	    my $text = $page->text;
	    $text->font( $font, $sz/1.5 );
	    $text->fillcolor( "#FF00FF" );
	    $text->strokecolor( "#FF00FF" );

	    $text->save;
	    $tr->( $text, 0, 0, 1, 1 );
	    $sz = $stampsize / 4;
	    $tr->( $text, $mx * ( $sz/2 + $r->[0]), - ( $sz/2.8 + $my * $r->[1]), 1, 1 );
	    $text->text_center( $stampindex );
	    $text->restore;

	}

	else {
	    warn("Skipping annotation (type = $type)\n");
	}

    }

    $pdf->saveas($pdfdst);

}

my $gp_sth;
sub get_path {
    my ( $dbh, $id ) = @_;
    $gp_sth ||= $dbh->prepare( "SELECT PointX, PointY FROM AnnotationPath" .
			       " WHERE AnnotationId = ? ORDER BY Id" );
    $gp_sth->execute($id);

    my $r = $gp_sth->fetchall_arrayref;
    $gp_sth->finish;

    return [ map { @$_ } @$r ];

}

sub make_colour {
    my ( $col ) = @_;
    sprintf("#%06x", $col & 0xffffff)
}

1;
