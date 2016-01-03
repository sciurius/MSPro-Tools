#!/usr/bin/perl -w

# Author          : Johan Vromans
# Created On      : Thu May 28 08:13:56 2015
# Last Modified By: Johan Vromans
# Last Modified On: Mon Jan  4 00:00:32 2016
# Update Count    : 135
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;

use FindBin;

use lib "$FindBin::Bin/../lib";

# Package name.
my $my_package = 'Sciurix';
# Program name and version.
my ($my_name, $my_version) = qw( upd_meta 0.02 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $dbname = "mobilesheets.db";
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
use Encode;

my $data = do { local $/; <> };

$data = eval { Encode::decode("utf-8", $data, 1) }
  || Encode::decode("latin1", $data);

my $meta = JSON->new->relaxed->decode($data);

db_open( $dbname, { RaiseError => 1, Trace => $trace } );

foreach my $m ( @$meta ) {

    my $m_attr = {};

    if ( $m->{songid} ) {
	# Ok
    }
    elsif ( $m->{title} ) {
	my $sth = dbh->prepare("SELECT Id FROM Songs WHERE Title = ?");
	$sth->execute($m->{title});
	my $ret = $sth->fetchall_arrayref;
	if ( !$ret || @$ret == 0 || @$ret > 1 ) {
	    warn( "Expecting one match for song \"",
		  $m->{title}. ", skipped\n");
	    next;
	}
	$m->{songid} = $ret->[0][0];
    }
    else {
	warn("No 'songid' nor 'title', cannot update\n");
	next;
    }

    if ( $m->{songid} ) {
	warn( "Song: ", $m->{songid},
	      " (", $m->{title} // "", ")\n") if $trace;
	for ( qw( songid title sorttitle
		  sourcetypes collections tempo keys signatures ) ) {
	    next unless $m->{$_};
	    $m_attr->{$_} = $m->{$_};
	}
    }


    # File properties. Only relevant for ChordPro files, of which
    # there is always only one.

    $m->{paths} //= [];
    foreach my $p ( @{ $m->{paths} } ) {

	if ( $p->{fileid} ) {
	    my $sth = dbh->prepare( "SELECT Path FROM Files WHERE Id = ?" );
	    $sth->execute($p->{fileid});
	    my $ret = $sth->fetchall_arrayref;
	    $p->{path} = $ret->[0][0];
	}
	elsif ( $p->{path} ) {
	    my $path = $p->{path};
	    $path =~ s;^.*/([^/]+)$;$1;;
	    my $sth = dbh->prepare( "SELECT Id, Path FROM Files WHERE Path = ?" );
	    $sth->execute($path);
	    my $ret = $sth->fetchall_arrayref;
	    if ( !$ret || @$ret == 0 ) {
		$sth->execute( "\%$path\%" );
		$ret = $sth->fetchall_arrayref;
	    }
	    if ( !$ret || @$ret == 0 || @$ret > 1 ) {
		warn("Expecting one match for \"$path\", skipped\n");
		next;
	    }
	    $p->{fileid} = $ret->[0][0];
	    $p->{path} = $ret->[0][1];
	}
	else {
	    warn("No 'fileid' nor 'path', cannot update\n");
	}

	if ( $p->{fileid} ) {
	    my $path = $p->{path};
	    warn( "File: ", $p->{fileid},
		  " (", $path // "", ")\n") if $trace;
	    my $attr = {};
	    # DO NOT UPDATE source and type.
	    for ( qw( enablecapo capo enabletranspose transpose ) ) {
		next unless $p->{$_};
		$attr->{$_} = $p->{$_};
	    }
	    upd_file( $p->{fileid}, $m->{songid}, $attr ) if %$attr;

	    unless ( 1 || $m_attr->{sourcetypes} ) {
		if ( $path =~ /-ptb\.pdf$/ ) {
		    $m_attr->{sourcetypes} = [ "Chords" ];
		}
		elsif ( $path =~ /-ptg\.pdf$/ ) {
		    $m_attr->{sourcetypes} = [ "Charts" ];
		}
		elsif ( $path =~ /\.pdf$/ ) {
		    $m_attr->{sourcetypes} = [ "Sheet Music" ];
		}
		elsif ( $path =~ /\.cho$/ ) {
		    $m_attr->{sourcetypes} = [ "Lead Sheet" ];
		}
	    }

	}

    }

    upd_song( $m->{songid}, $m_attr );
}

################ Subroutines ################

sub upd_song {
    my ( $songid, $attr ) = @_;

    warn( "Song: $songid\n", Dumper($attr), "\n") if $debug;

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
	db_delall( "CollectionSong", [ qw( SongId ) ], [ $songid ] );
	foreach ( @{ $attr->{collections} } ) {
	    db_insnodup( "CollectionSong",
			 [ qw( SongId CollectionId ) ],
			 [ $songid, get_collections($_) ],
		       );
	}
    }

    if ( $attr->{sourcetypes} ) {
	db_delall( "SourceTypeSongs", [ qw( SongId ) ], [ $songid ] );
	foreach ( @{ $attr->{sourcetypes} } ) {
	    db_insnodup( "SourceTypeSongs",
			 [ qw( SongId SourceTypeId ) ],
			 [  $songid, get_sourcetype($_) ],
		       );
	}
    }

    if ( $attr->{keys} ) {
	db_delall( "KeySongs", [ qw( SongId ) ], [ $songid ] );
	foreach ( @{ $attr->{keys} } ) {
	    db_insnodup( "KeySongs",
			 [ qw( SongId KeyId ) ],
			 [ $songid, get_key($_) ],
		       );
	}
    }

    # Sig1  0 = 2, 1 = 3, ...
    # Sig2  0 = 4, 1 = 8
    # Subdivision
    if ( $attr->{signatures} ) {
	db_delall( "SignatureSongs", [ qw( SongId ) ], [ $songid ] );
	foreach ( @{ $attr->{signatures} } ) {
	    my @s;
	    if ( m;^(\d+)/(\d+)$; && ( $2 == 4 || $2 == 8 ) ) {
		@s = ( $1 - 2, $2 == 4 ? 0 : 1, 0 );
	    }
	    else {
		@s = ( 2, 0, 0 );	# treat like 4/4
	    }
	    db_insnodup( "MetronomeSettings",
			 [ qw( SongId Sig1 Sig2 Subdivision SoundFX AccentFirst
			       AutoStart CountIn NumberCount AutoTurn ) ],
			 [ $songid, @s, 0, 0,
			   1, 1, 2, 0 ],
		       ) if @s;
	    db_insnodup( "SignatureSongs",
			 [ qw( SongId SignatureId  ) ],
			 [ $songid, get_signature($_) ],
		       );
	}
    }

    if ( $attr->{tempos} ) {
	db_delall( "Tempos", [ qw( SongId ) ], [ $songid ] );
	foreach ( @{ $attr->{tempos} } ) {
	    db_insnodup( "Tempos",
			 [ qw( SongId TempoIndex Tempo ) ],
			 [ $songid, 0, $_ ],
		       );
	}
    }

    if ( $attr->{artists} ) {
	db_delall( "ArtistsSongs", [ qw( SongId ) ], [ $songid ] );
	foreach ( @{ $attr->{artists} } ) {
	    db_insnodup( "ArtistsSongs",
			 [ qw( SongId ArtistId ) ],
			 [ $songid, get_artist($_) ],
		       );
	}
    }

    if ( $attr->{composers} ) {
	db_delall( "ComposerSongs", [ qw( SongId ) ], [ $songid ] );
	foreach ( @{ $attr->{composers} } ) {
	    db_insnodup( "ComposerSongs",
			 [ qw( SongId ComposerId ) ],
			 [ $songid, get_composer($_) ],
		       );
	}
    }

}

sub upd_file {
    my ( $fileid, $songid, $attr ) = @_;

    warn( "File: $fileid\n", Dumper($attr), "\n") if $debug;

    # TextDisplaySettings
    #  Key: 1=C, ...
    #  EnableCapo: 1=on
    #  EnableTranspose: 1=on
    #  Transpose: 1, 2, ... if EnableTranspose
    #  Capo: 1, 2, ... if EnableCapo
    #  ChordStyle: 0=Plain, 1=Bold,
    #  Encoding: 0=Default(UTF-8), 2=ISO-8859.1

    if ( defined $attr->{capo} || defined $attr->{transpose} || defined $attr->{encoding}
	 || defined $attr->{enablecapo} || defined $attr->{enabletranspose} ) {
	db_insupd( "TextDisplaySettings",
		   [ qw( FileId SongId FontFamily
			 TitleSize MetaSize LyricsSize ChordsSize LineSpacing
			 ChordHighlight ChordColor ChordStyle NumberChords
			 EnableTranpose Transpose EnableCapo Capo
			 ShowTitle ShowMeta ShowLyrics ShowChords ShowTabs
			 Structure Key Encoding ) ],
		   [ $fileid, $songid, 0,
		     37, 30, 28, 30, 1.2,
		     0x00ff00 - 0x1000000, 0x000000 - 0x1000000, 1, 6,
		     $attr->{enabletranspose} // 0,
		     $attr->{transpose} // 0,
		     $attr->{enablecapo} // 0,
		     $attr->{capo} // 0,
		     1, 1, 1, 1, 1,
		     undef, 0, get_encoding($attr->{encoding}),
		   ],
		   2
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
   --ident		show identification
   --help		brief help message
   --man                full documentation
   --verbose		verbose information

=head1 OPTIONS

=over 8

=item B<--db=>I<dbname>

Specifies the name of the MobileSheetsPro database.

Default is C<"mobilesheets.db">.

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
