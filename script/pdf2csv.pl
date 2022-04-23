#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use PDF::API2;

# Open.
my @t = ( time );
my $pdf = PDF::API2->open( shift || "__temp__.pdf" );
push( @t, time );

binmode( STDOUT, ':utf8' );
for ( @{ outlines($pdf) } ) {
    print( $_->[0], ';', $_->[1], ";\n" );
}

warn( $t[1]-$t[0], " ", $t[2]-$t[1], " ", $t[3]-$t[2], "\n" );

my $_pages;
sub outlines {
    my ( $pdf ) = @_;

    unless ( $_pages ) {
	for ( 1 .. $pdf->pages ) {
	    $_pages->{ "".$pdf->openpage($_) } = $_;
	}
	push( @t, time );
    }
    my $outlines = $pdf->outlines();
    my $ol = $outlines->val->{First};
    my $res = [];
    for ( 1 .. $outlines->val->{Count}->val ) {
	$ol = $ol->val;
	my $dst =
	  exists($ol->{Dest})
	    ? $ol->{Dest}->val->[0]
	      : $ol->{A}->val->{D}->val->[0];
	my $p1 = $_pages->{ "".$dst };
	push( @$res, [ $ol->{Title}->val, $p1 ] );
	$ol = $ol->{Next};
    }
    push( @t, time );
    return $res;
}




