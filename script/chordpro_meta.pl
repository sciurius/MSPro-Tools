#!/usr/bin/perl -w

# Author          : Johan Vromans
# Created On      : Sun Jun  7 21:58:04 2015
# Last Modified By: Johan Vromans
# Last Modified On: Thu Jun 28 11:32:51 2018
# Update Count    : 176
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use Carp;
use FindBin;

use lib "$FindBin::Bin/../lib";

# Package name.
my $my_package = 'MSProTools';
# Program name and version.
my ($my_name, $my_version) = qw( chordpro_meta 0.02 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $dbname = "mobilesheets.db";
my $songid;
my $fileid;
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

binmode( STDOUT, ':utf8' );

# We don't use anything from MobileSheetsPro::DB.
db_open( $dbname, { RaiseError => 1, Trace => $trace } );

my @allmeta = ();
#  qw( title subtitle artist composer lyricist arranger
#      album copyright year key time tempo capo duration
#      sorttitle collection setlist source genre difficulty
#      rating custom custom2 customgroup keywords
#   );

my $q_files = <<EOD;
SELECT Id, Path, SongId
 FROM Files
EOD

my $q_songs = <<EOD;
SELECT Id, Title, SortTitle, Duration,
       Custom, Custom2, Difficulty, Keywords
 FROM Songs
EOD

if ( $songid ) {
    my $ret = db_sel( "$q_songs WHERE Id = ?".
		      " ORDER BY Id", {}, $songid );

    if ( @$ret ) {
	my $r = db_sel( "$q_files WHERE SongId = ?" .
			" ORDER BY Id", {}, $songid );

	foreach my $fret ( @$r ) {
	    foreach my $sret ( @$ret ) {
		handle_song( $fret, $sret );
	    }
	}
    }
}
elsif ( $fileid || !@ARGV ) {
    my $ret;
    if ( $fileid ) {
	$ret = db_sel( "$q_files WHERE Id = ?" .
		       " ORDER BY Id", {}, $fileid );
    }
    else {
	$ret = db_sel( "$q_files ORDER BY Id" );
    }

    foreach my $fret ( @$ret ) {
	my $songid = $fret->[2];
	my $ret = db_sel( "$q_songs WHERE Id = ?".
			  " ORDER BY Id", {}, $songid );

	foreach my $sret ( @$ret ) {
	    handle_song( $fret, $sret );
	}
    }
}
else {
    foreach my $title ( @ARGV ) {
	my $ret = db_sel( "$q_songs WHERE Title like ?".
			  " ORDER BY Id", {}, $title );

	foreach my $sret ( @$ret ) {
	    my $songid = $sret->[0];
	    my $r = db_sel( "$q_files WHERE SongId = ?" .
			    " ORDER BY Id", {}, $songid );

	    foreach my $fret ( @$r ) {
		handle_song( $fret, $sret );
	    }
	}
    }
}

sub handle_song {
    my ( $fileid, $path ) = @{shift(@_)};
    my ( $songid, $title, $stitle, $duration, $c1, $c2, $dc, $kw ) = @{shift(@_)};
    $path =~ s;^/storage/.*?/Android/data/com.zubersoft.mobilesheetspro/files/;;;

    my $meta;

    # For convenience, we treat all metadata as lists.
    $meta = { map { $_ => [] } @allmeta } if @allmeta;

    # Internal meta data.
    $meta->{_songid}    = $songid;
    $meta->{_fileid}    = $fileid;
    $meta->{_path}      = $path;

    # Song meta data.
    $meta->{title}      = [ $title ];
    $meta->{sorttitle}  = [ $stitle ] if $stitle//'' ne '';
    $meta->{duration}   = [ $duration ] if $duration;
    $meta->{custom}     = [ $c1 ] if $c1//'' ne '';
    $meta->{custom2}    = [ $c2 ] if $c2//'' ne '';
    $meta->{difficulty} = [ $dc ] if $dc;
    $meta->{keywords}   = [ $kw ] if $kw//'' ne '';

    # Collect the rest of the meta data.

    my $ret;

    # Artist
    # You are in a twisty maze of little passages, all different.
    $ret = db_sel( "SELECT Name FROM Artists,ArtistsSongs".
		   " WHERE ArtistId = Artists.Id".
		   " AND SongID = $songid" );
    $meta->{artist} = [ map { $_->[0] } @$ret ]
      if $ret && @$ret;

    # Composer
    # You are in a little twisty maze of passages, all different.
    $ret = db_sel( "SELECT Name FROM Composer,ComposerSongs".
		   " WHERE ComposerId = Composer.Id".
		   " AND SongID = $songid" );
    $meta->{composer} = [ map { $_->[0] } @$ret ]
      if $ret && @$ret;

    # Collection
    # You are in a twisty little maze of passages, all different.
    $ret = db_sel( "SELECT Name FROM Collections,CollectionSong".
		   " WHERE CollectionId = Collections.Id".
		   " AND SongID = $songid" );
    $meta->{collection} = [ map { $_->[0] } @$ret ]
      if $ret && @$ret;

    # Album (Book)
    # You are in a maze of little twisty passages, all different.
    $ret = db_sel( "SELECT Title FROM Books,BookSongs".
		   " WHERE BookId = Books.Id".
		   " AND SongID = $songid" );
    $meta->{album} = [ map { $_->[0] } @$ret ]
      if $ret && @$ret;

    # Setlist
    # You are in a little maze of twisty passages, all different.
    $ret = db_sel( "SELECT Name FROM Setlists,SetlistSong".
		   " WHERE SetlistId = Setlists.Id".
		   " AND SongID = $songid" );
    $meta->{setlist} = [ map { $_->[0] } @$ret ]
      if $ret && @$ret;

    # Time (Signature).
    # You are in a maze of twisting little passages, all different.
    $ret = db_sel( "SELECT Name FROM Signature,SignatureSongs".
		   " WHERE SignatureId = Signature.Id".
		   " AND SongID = $songid" );
    $meta->{time} = [ map { $_->[0] } @$ret ]
      if $ret && @$ret;

    # Tempo
    # You are in a twisting maze of little passages, all different.
    $ret = db_sel( "SELECT Tempo FROM Tempos".
		   " WHERE SongID = $songid" );
    $meta->{tempo} = [ grep { $_ } map { $_->[0] } @$ret ]
      if $ret && @$ret;

    # Capo
    # You are in a maze of little twisting passages, all different.
    $ret = db_sel( "SELECT Capo FROM TextDisplaySettings".
		   " WHERE SongID = $songid".
		   "  AND FileID = $fileid" );
    $meta->{capo} = [ grep { $_ } map { $_->[0] } @$ret ]
      if $ret && @$ret;

    # Year
    # You are in a little maze of twisting passages, all different.
    $ret = db_sel( "SELECT Name FROM Years,YearsSongs".
		   " WHERE SongID = $songid".
		   "  AND Years.Id = YearId" );
    $meta->{year} = [ grep {  $_ } map { $_->[0] } @$ret ]
      if $ret && @$ret;

    # Genre
    # You are in a twisting little maze of passages, all different.
    $ret = db_sel( "SELECT Type FROM Genres,GenresSongs".
		   " WHERE SongID = $songid".
		   "  AND Genres.Id = GenreId" );
    $meta->{genre} = [ grep { $_ } map { $_->[0] } @$ret ]
      if $ret && @$ret;

    # Source
    # You are in a maze of twisty little passages, all different.
    $ret = db_sel( "SELECT Type FROM SourceType,SourceTypeSongs".
		   " WHERE SongID = $songid".
		   "  AND SourceType.Id = SourceTypeId" );
    $meta->{source} = [ grep { $_ } map { $_->[0] } @$ret ]
      if $ret && @$ret;

    # CustomGroup
    # You are in a little twisting maze of passages, all different.
    $ret = db_sel( "SELECT Name FROM Customgroup,CustomgroupSongs".
		   " WHERE SongID = $songid".
		   "  AND Customgroup.Id = GroupId" );
    $meta->{customgroup} = [ grep { $_ } map { $_->[0] } @$ret ]
      if $ret && @$ret;

    for ( $meta ) {
	print( "=== ", $_->{_path}, " === ",
	       "[", $_->{_songid}, "/", $_->{_fileid}, "]\n" );
	print( "{title: ", $_->{title}->[0], "}\n");
	for my $k ( qw(subtitle
		       artist composer lyricist arranger
		       album copyright year
		       key capo time tempo duration) ) {
	    print( "{$k: $_}\n") foreach @{$_->{$k}};
	};
	for my $k ( qw(sorttitle collection setlist
		       source genre difficulty
		       custom custom2 customgroup keywords) ) {
	    print( "{meta: $k $_}\n") foreach @{$_->{$k}};
	};
    }
}

################ Database Subroutines ################

use DBI;

my $dbh;

sub db_open {
    my ( $dbname, $opts ) = @_;
    $opts ||= {};
    $trace = delete( $opts->{Trace} );
    Carp::croak("No database $dbname\n") unless -s $dbname;
    $opts->{sqlite_unicode} = 1;
    $dbh = DBI::->connect( "dbi:SQLite:dbname=$dbname", "", "", $opts );
}

sub db_sel {
    $dbh->selectall_arrayref(@_);
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
		   'songid=i'	=> \$songid,
		   'fileid=i'	=> \$fileid,
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
    if ( $songid && $fileid ) {
	die("Do not specify --songid and --fileid simultaneously.\n")
    }
    if ( ( $songid || $fileid ) && @ARGV ) {
	die("Do not specify songs titles with --songid or --fileid.\n")
    }
    if ( $man or $help ) {
	$pod2usage->(1) if $help;
	$pod2usage->(VERBOSE => 2) if $man;
    }
}

__END__

################ Documentation ################

=head1 NAME

chordpro_meta - get ChordPro metadata from MobileSheetsPro database

=head1 SYNOPSIS

chordpro_meta [options] [title ...]

 Options:
   --fileid=NNN		internal file id
   --songid=NNN		internal song id
   --db=XXX		the MSPro database
   --ident		show identification
   --help		brief help message
   --man                full documentation
   --verbose		verbose information

=head1 OPTIONS

=over 8

=item B<--db=>I<XXX>

The location of the MobileSheetsPro database. Default is
C<mobilesheets.db> in the current directory.

=item B<--songid=>I<NNN>

If used, only the information for the specified song is returned.

This can not be combined with <--fileid> and song titles.

=item B<--fileid=>I<NNN>

If used, only the information for the songs that use the specified
file is returned.

This can not be combined with <--songid> and song titles.

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

More verbose information.

=item I<title>

Optional titles of songs to return information for.

The titles are matched case-insensitive and may contain SQL wilcard
characters like C<_> and C<%>.

=back

=head1 DESCRIPTION

This program extracts ChordPro metadata from the MobileSheetsPro
database.

The metadata is written to standard output in the form of a series of
ChordPro directives, preceeded by the file name, e.g.

    === HowsaGoin/051_As_I_Roved_Out.cho === [2497/14472]
    {title: As I Roved Out}
    {artist: The High Kings}
    {capo: 3}
    {tempo: 105}
    {meta: collection HowsaGoin!}
    {meta: source Lead Sheet}
    {meta: custom2 51}

The numbers between C<[ ]> are the internal song and file id. These
can be used for subsequent searches with B<--songid> and B<--fileid>
command line options.

If no songs are selected, the information for all songs in the
database is returned.

=head1 AUTHOR

Johan Vromans C<< <jv at CPAN dot org > >>

=head1 SUPPORT

This program is part of the MobileSheetPro tools suite, but can be
used independently. Development is hosted on GitHub, repository
L<https://github.com/sciurius/MSPro-Tools>.

Please report any bugs or feature requests to the GitHub issue tracker.

=head1 LICENSE

Copyright (C) 2018 Johan Vromans,

This program is free software. You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

