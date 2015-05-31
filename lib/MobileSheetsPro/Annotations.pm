#! perl -w

# Author          : Johan Vromans
# Created On      : Sat May 30 13:10:48 2015
# Last Modified By: Johan Vromans
# Last Modified On: Sun May 31 10:51:02 2015
# Update Count    : 235
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

package MobileSheetsPro::Annotations;

use MobileSheetsPro::DB;
use Data::Dumper;
use PDF::API2;

my $verbose = 0;
my $debug = 0;

sub flatten_song {
    my ( $dbh, $songid, $pdfsrc, $pdfdst ) = @_;

    my $sth;
    my $r;

    $r = $dbh->selectrow_arrayref( "SELECT Title FROM Songs WHERE Id = $songid" );
    die("Unknown song $songid\n")
      unless $r && $r->[0];

    warn("Processing song \"$r->[0]\"\n") if $verbose;

    my $pdf;
    if ( $pdfsrc ) {
	warn("Song file \"$r->[0]\"\n") if $verbose;
	$pdf = PDF::API2->open($pdfsrc);
    }
    else {
	$pdf = PDF::API2->new;
    }
    my $font ||= $pdf->ttfont( $ENV{HOME}."/.fonts/DejaVuSans.ttf" );

    $sth = $dbh->prepare( "SELECT Id, Page, Type, GroupNum, Alpha, Zoom, ZoomY, Version FROM AnnotationsBase" .
			 " WHERE SongId = ? ORDER BY Page, Id" );

    $sth->bind_columns( \my ( $annid, $pageno, $type, $groupnum, $alpha, $zoomx, $zoomy, $version ) );

    $sth->execute($songid);

    my $curpage = -1;

    my $page;
    my $gfx;
    my $text;
    my @mb;

    while ( $sth->fetch ) {

	if ( $curpage != $pageno ) {
	    if ( $pdfsrc ) {
		$page = $pdf->openpage( $pageno + 1 );
	    }
	    else {
		$page = $pdf->page;
		$page->mediabox('A4');
	    }
	    @mb = $page->get_mediabox; # A4 = 595 x 842
	    $curpage = $pageno;
	    $text = $page->text;
	    $gfx = $page->gfx;
	    $gfx->translate( 0, $mb[3]-$mb[1] );
	}

	$gfx->save;
	$text = $gfx;
	#$page->grid;
	my $MAGIC = 0.44974402082622;
	$gfx->scale( $MAGIC/$zoomx, $MAGIC/$zoomy ); #### MAGIC

	if ( $type == 0 ) {	# text
	    my $sth2 = $dbh->prepare( "SELECT TextColor,Text,FontFamily,FontSize,FontStyle," .
				     "FillColor,BorderColor,TextAlign," .
				     "HasBorder,BorderWidth,AutoSize,Density" .
				     " FROM TextboxAnnotations" .
				     " WHERE BaseId = $annid ORDER BY Id" );
	    $sth2->bind_columns( \my ( $textcolor, $thetext, $fontfamily, $fontsize, $fontstyle,
				       $fillcolor, $bordercolor, $textalign,
				       $hasborder, $borderwidth, $autosize, $density ) );
	    my $r = get_path( $dbh, $annid );
	    $sth2->execute;
	    while ( $sth2->fetch ) {
		my $text = $page->text;
		$text->font($font, $fontsize);
		$text->fillcolor( make_colour($textcolor) );
		$text->strokecolor( make_colour($textcolor) );
		# I don't understand, but it works.
		$text->transform( -translate => [ $r->[4] * ($MAGIC/$zoomx), (0-$r->[5]) * ($MAGIC/$zoomy) ],
				  -scale => [ $MAGIC/$zoomx, $MAGIC/$zoomy ],
				); #### MAGIC
		if ( $textalign == 1 ) {
		    $text->text_center($thetext);
		}
		else {
		    $text->text($thetext);
		}

		if ( $hasborder || $fillcolor ) {
		    $gfx->save;
		    $gfx->strokecolor( make_colour($bordercolor) );
		    $gfx->fillcolor(   make_colour($fillcolor) ) if $fillcolor;
		    $gfx->linewidth($borderwidth);
		    $gfx->rectxy( $r->[0], -$r->[1], $r->[2], -$r->[3] );
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
	    }
	    next;
	}

	unless ( $type == 1 ) {	# drawing
	    warn("Skipping annotation (type = $type)\n");
	    next;
	}

	my $sth2 = $dbh->prepare( "SELECT LineColor,FillColor,LineWidth,DrawMode" .
				 " FROM DrawAnnotations" .
				 " WHERE BaseId = ?" );

	$sth2->execute($annid);
	$r = $sth2->fetch;
	unless ( $r && $r->[0] ) {
	    die("No annotation info for song $songid\n");
	}
	my ( $linecolor, $fillcolor, $linewidth, $drawmode ) = @$r;

	$gfx->strokecolor( make_colour($linecolor) );
	$gfx->fillcolor(   make_colour($fillcolor) );
	$gfx->linewidth($linewidth);
	$gfx->linejoin(1);	# round
	$gfx->linecap(1);	# round

	$sth2 = $dbh->prepare( "SELECT PointX,PointY FROM AnnotationPath" .
			      " WHERE AnnotationId = ? ORDER BY Id" );
	$sth2->execute($annid);

	if ( $drawmode == 1 ) {
	    my $r = $sth2->fetchall_arrayref;
	    $gfx->rectxy( $r->[0]->[0], -$r->[0]->[1], $r->[1]->[0], -$r->[1]->[1] );
	    $gfx->stroke;
	    next;
	}

	if ( $drawmode == 2 ) {	# circle
	    my $r = $sth2->fetchall_arrayref;
	    $gfx->circle( $r->[0]->[0], -$r->[0]->[1], $r->[1]->[0] - $r->[0]->[0] );
	    $gfx->stroke;
	    next;
	}

	if ( $drawmode == 0 ) {
	    my $r = $sth2->fetchall_arrayref;
	    $gfx->poly( $r->[0]->[0], -$r->[0]->[1], $r->[1]->[0], -$r->[1]->[1] );
	    $gfx->stroke;
	    next;
	}

	unless ( $drawmode == 3 ) {
	    warn("Skipping annotation (drawmode = $drawmode)\n");
	    next;
	}


	$sth2->bind_columns( \my ( $x, $y ) );
	my $point = 0;
	my ( $px, $py ) = ( -1, -1 );

	while ( $sth2->fetch ) {
	    if ( $x > 10000 && $y > 10000 ) {
		$gfx->stroke if $point;
		$gfx->endpath;
		$point = 0;
		( $px, $py ) = ( -1, -1 );
		# Next point is the same, so ignore it.
		$sth2->fetch;
		next;
	    }

	    next if $px == $x && $py == $y;
	    ( $px, $py ) = ( $x, $y );
	    if ( $point++ ) {
		warn( sprintf("page $curpage, line %.3f %.3f\n", $x, $y ) ) if $debug;
		$gfx->line( $x, -$y );
	    }
	    else {
		warn( sprintf("page $curpage, move %.3f %.3f\n", $x, $y ) ) if $debug;
		$gfx->move( $x, -$y );
	    }
	}

	$gfx->stroke if $point;
    }
    continue {
	$gfx->restore;
    }

    $pdf->saveas($pdfdst);

}

sub get_path {
    my ( $dbh, $id ) = @_;
    my $r = $dbh->selectall_arrayref( "SELECT PointX,PointY FROM AnnotationPath" .
				     " WHERE AnnotationId = $id ORDER BY Id" );
    my @r;
    push( @r, @$_ ) foreach @$r;
    \@r;
}

sub make_colour {
    my ( $col ) = @_;
    sprintf("#%06x", $col & 0xffffff)
}

1;
