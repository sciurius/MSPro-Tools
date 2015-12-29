#!/usr/bin/perl -w

# Author          : Johan Vromans
# Created On      : Thu May 28 08:13:56 2015
# Last Modified By: Johan Vromans
# Last Modified On: Tue Dec 29 13:56:43 2015
# Update Count    : 87
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;

use FindBin;

use lib "$FindBin::Bin/../lib";

# Package name.
my $my_package = 'Sciurix';
# Program name and version.
my ($my_name, $my_version) = qw( upd_meta 0.01 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $dbname = "mobilesheets.db";
my $pathfull = 0;		# match on full path name
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
use Time::HiRes;
use DBI;
use Data::Dumper;
use JSON;

my $data = do { local $/; <> };
my $meta = JSON->new->decode($data);

db_open( $dbname, { RaiseError => 1, Trace => $trace } );

my $sth = dbh->prepare( "SELECT Path, Id, SongId" .
			" FROM Files WHERE Path " .
			( $pathfull ? " =" : "LIKE" ) . " ?" );

foreach my $m ( @$meta ) {
    next unless $m->{paths};

    foreach my $p ( @{ $m->{paths} } ) {

	my $path = $p->{path};
	$path =~ s;^.*/([^/]+)$;$1; unless $pathfull;

	$sth->execute($path);
	my $ret = $sth->fetchall_arrayref;
	if ( !$ret || @$ret == 0 || @$ret > 1 ) {
	    $sth->execute( "\%$path\%" );
	    $ret = $sth->fetchall_arrayref;
	}
	if ( !$ret || @$ret == 0 || @$ret > 1 ) {
	    warn("Expecting one match for \"$path\", skipped\n");
	    next;
	}
	$sth->finish;

	my ( $ppp, $fileid, $songid ) = @{ $ret->[0] };
	my $attr = {};
	warn( "Path: $ppp\n" ) if $trace;

	for ( qw( title sorttitle collections tempo keys signatures ) ) {
	    next unless $m->{$_};
	    $attr->{$_} = $m->{$_};
	}
	for ( qw( capo transpose source ) ) {
	    next unless $p->{$_};
	    $attr->{$_} = $p->{$_};
	}

	unless ( $attr->{source} ) {
	    if ( $path =~ /-ptb\.pdf$/ ) {
		$attr->{source} = get_sourcetype("Chords");
	    }
	    elsif ( $path =~ /-ptg\.pdf$/ ) {
		$attr->{source} = get_sourcetype("Charts");
	    }
	    elsif ( $path =~ /\.pdf$/ ) {
		$attr->{source} = get_sourcetype("Sheet Music");
	    }
	    elsif ( $path =~ /\.cho$/ ) {
		$attr->{source} = get_sourcetype("Lead Sheet");
	    }
	}
	upd_song( $songid, $fileid, $attr );
    }
}

################ Subroutines ################

sub upd_song {
    my ( $songid, $fileid, $attr ) = @_;

    warn( "File: $fileid, Song: $songid\n",
	  Dumper($attr), "\n") if $debug;

    if ( $attr->{title} ) {
	db_upd( "Songs",
		[ qw( Id Title ) ],
		[ $songid, $attr->{title} ],
	      );
    }

    if ( $attr->{sorttitle} ) {
	db_upd( "Songs",
		[ qw( Id SortTitle ) ],
		[ $songid, $attr->{sorttitle} ],
	      );
    }

    if ( $attr->{collections} ) {
	foreach ( @{ $attr->{collections} } ) {
	    db_insupd( "CollectionSong",
		       [ qw( SongId CollectionId ) ],
		       [ $songid, get_collections($_) ],
		     );
	}
    }

    if ( $attr->{source} ) {
	db_insupd( "SourceTypeSongs",
		   [ qw( SongId SourceTypeId ) ],
		   [  $songid, $attr->{source} ],
		 );
    }

    if ( $attr->{key} ) {
	foreach ( @{ $attr->{key} } ) {
	    db_insupd( "KeySongs",
		       [ qw( SongId KeyId ) ],
		       [ $songid, get_key($_) ],
		     );
	}
    }

    # Sig1  0 = 2, 1 = 3, ...
    # Sig2  0 = 4, 1 = 8
    # Subdivision
    if ( $attr->{signatures} ) {
	foreach ( @{ $attr->{signatures} } ) {
	    my @s;
	    if ( m;^(\d+)/(\d+)$; && ( $2 == 4 || $2 == 8 ) ) {
		@s = ( $1 - 2, $2 == 4 ? 0 : 1, 0 );
	    }
	    else {
		@s = ( 2, 0, 0 );	# treat like 4/4
	    }
	    db_insupd( "MetronomeSettings",
		       [ qw( SongId Sig1 Sig2 Subdivision SoundFX AccentFirst
			     AutoStart CountIn NumberCount AutoTurn ) ],
		       [ $songid, @s, 0, 0,
			 1, 1, 2, 0 ],
		     ) if @s;
	    db_insupd( "SignatureSongs",
		       [ qw( SongId SignatureId  ) ],
		       [ $songid, get_signature($_) ],
		     );
	}
    }

    if ( $attr->{tempos} ) {
	foreach ( @{ $attr->{tempos} } ) {
	    db_insupd( "Tempos",
		       [ qw( SongId TempoIndex Tempo ) ],
		       [ $songid, 0, $_ ],
		       2
		     );
	}
    }

    if ( $attr->{artists} ) {
	foreach ( @{ $attr->{artists} } ) {
	    db_insupd( "ArtistsSongs",
		       [ qw( SongId ArtistId ) ],
		       [ $songid, get_artist($_) ],
		     );
	}
    }

    if ( $attr->{composers} ) {
	foreach ( @{ $attr->{composers} } ) {
	    db_insupd( "ComposerSongs",
		       [ qw( SongId ComposerId ) ],
		       [ $songid, get_composer($_) ],
		     );
	}
    }

    # TextDisplaySettings
    #  Key: 1=C, ...
    #  EnableCapo: 1=on
    #  EnableTranspose: 1=on
    #  Transpose: 1, 2, ... if EnableTranspose
    #  Capo: 1, 2, ... if EnableCapo
    #  ChordStyle: 0=Plain, 1=Bold,
    #  Encoding: 0=Default(UTF-8), 2=ISO-8859.1

    if ( $attr->{capo} || $attr->{transpose} || $attr->{encoding} ) {
	db_insupd( "TextDisplaySettings",
		   [ qw( FileId SongId FontFamily
			 TitleSize MetaSize LyricsSize ChordsSize LineSpacing
			 ChordHighlight ChordColor ChordStyle NumberChords
			 EnableTranpose EnableCapo Transpose Capo
			 ShowTitle ShowMeta ShowLyrics ShowChords ShowTabs
			 Structure Key Encoding ) ],
		   [ $fileid, $songid, 0,
		     37, 30, 28, 30, 1.2,
		     0x00ff00 - 0x1000000, 0x000000 - 0x1000000, 1, 6,
		     $attr->{capo} ? ( 1, 1, $attr->{capo}, $attr->{capo} ) : ( 0, 0, 0, 0 ),
		     1, 1, 1, 1, 1,
		     undef, 0, get_encoding($attr->{encoding}),
		   ],
		   2
		 );
    }

    if ( $attr->{capo} ) {
	# Use Custom2 to show in title display.
	db_upd( "Songs",
		[ qw( Id Custom2 ) ],
		[ $songid, "Capo " . $attr->{capo} . " " ],
	      );
    }

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
		   'path-full'  => \$pathfull,
		   'verbose'	=> \$verbose,
		   'trace'	=> \$trace,
		   'help|?'	=> \$help,
		   'man'	=> \$man,
		   'debug'	=> \$debug)
	  or $pod2usage->(2);
    }
    $pod2usage->(2) unless @ARGV == 1;
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

upd_meta -- update MSPro metadata

=head1 SYNOPSIS

upd_meta [options] json-file

 Options:
   --db=XXX		name of the MSPro database
   --path-full		match on full path names
   --ident		show identification
   --help		brief help message
   --man                full documentation
   --verbose		verbose information

=head1 OPTIONS

=over 8

=item B<--db=>I<dbname>

Specifies the name of the MobileSheetsPro database.

Default is C<"mobilesheets.db">.

=item B<--path-full>

Normally upd_meta looks for files in the database based on the
filename without path. This can lead to problems when there are files
with identical names in different paths.

Using the B<--path-full> command line option makes the program search
for files based on filename including the path.

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

More verbose information.

=item I<json-file>

Input file containing metadata in JSON format, as generated by the
companion program B<get_meta>.

=back

=head1 DESCRIPTION

This program will read the metadata from the given input file and
update the MobileSheetsPro database accordingly.

=cut
