#!/usr/bin/perl

# Unpack a MobileSheetsPro backup file.

# Author          : Johan Vromans
# Created On      : Fri May  1 18:39:01 2015
# Last Modified By: Johan Vromans
# Last Modified On: Sat Sep 11 21:03:15 2021
# Update Count    : 315
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

# Package name.
my $my_package = 'MSProTools';
# Program name and version.
my ($my_name, $my_version) = qw( msb_unpack 0.13 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $msbfile = "MobileSheetsProBackup.msb";
my $dbonly = 0;
my $zipfile;
my $ann = 1;			# process annotations
my $check = 0;			# check integrity only
my $verbose = 1;		# verbose processing
my $repackable = 1;		# unpack in a format that msb_pack.pl understands

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $trace = 0;			# trace (show process)
my $test = 0;			# test mode.

# Process command line options.
app_options();

# Post-processing.
$msbfile = shift if @ARGV == 1;
$trace ||= ($debug || $test);
$verbose ||= $trace;
$verbose = 9 if $debug;

$repackable = 0 if $check;

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

use Fcntl qw( SEEK_CUR O_RDONLY O_WRONLY O_CREAT );
use File::Path qw(make_path);
use File::Basename qw(dirname);
use DBI;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Encode;

# MSB File Format, as told by Mike.
#
# 499602d4         file magic word (version 3) 1234567892
# xxxxxxxxxxxxxxxx 8-byte data length
# xxxxxxxxxxxxxxxx database file data
#
# OR:
#
# 499602d5         file magic word (version 4) 1234567893
# xxxx             4-byte number of settings items
# xx		   2-byte item name length
# aaaaaaa	   item name
# xxxxxxxxxxxxxxxx 8-byte data length
# xxxxxxxxxxxxxxxx item data
# ... rinse, repeat ...
# xxxxxxxxxxxxxxxx 8-byte data length
# xxxxxxxxxxxxxxxx database file data
#
#
# Followed by zero or more:
#
# 11deda2c5161659c 8-byte header magic word 1287706427353294236
#                  (can be used for searching in a corrupt file)
# xxxxxxxxxxxxxxxx 8-byte song database Id
# xxxxxxxxxxxxxxxx 8-byte data length ( 0 = missing or dup )
# xxxxxxxxxxxxxxxx file data
#                  order: image/PDF/text/audio
#
# Finally:
#
# ffffffffffffffff 8-byte end-of-file sentinel
#
# Note: Everything is byte aligned.

my $FILE_MAGIC   = 1234567892;
my $HDR_MAGIC    = 1287706427353294236;
my $EOF_SENTINEL = "\xff" x 8;

my $msb = MSB->new->open($msbfile);
warn("Reading MobileSheetsPro backup set version ",
     $msb->version, "\n") if $verbose;

# For zip output.
$msb->zip( Archive::Zip->new ) if $zipfile;

if ( $msb->version >= 4 ) {
    $msb->handle_preferences;
}

if ( $msb->version >= 5 ) {
    $msb->handle_user_filters;
}

if ( $msb->version >= 6 ) {
    $msb->handle_annotations_favorites();
    $msb->handle_stamplists();
    $msb->handle_custom_stamps();
}

# First entry in the file is the database.
$msb->handle_database( "mobilesheets.db" );

my $len;
my $file = 0;
my %seen;

while ( !$dbonly && ( my $n = $msb->read(8) ) ) {

    mkdir("media") if $repackable;

    if ( $n != $HDR_MAGIC ) {
	# Add recovery later.
	die("OOPS -- Missing magic... punting\n");
    }

    my $songid = $msb->read(8);
    $msb->get_dbfiles($songid);

    while ( my $info = shift( @{ $msb->dbfiles } )  ) {
	my ( $path, $mtime, $sz ) = @$info;
	unless ( $path ) {
	    warn("Song $songid, not included\n") if $verbose > 1;
	    last;
	}
	$mtime = int( $mtime/1000 );
	warn( "Song $songid, path = $path, size = $sz, mtime = $mtime (" .
	      localtime($mtime) . ")\n" )
	  if $verbose > 1;
	#next if $sz == 0;

	my $len = $msb->read(8);
	if ( !$len ) {
	    # Placeholder for files not physically present in the backup set.
	    warn("Placeholder: $path\n") if $verbose > 1;
	    next;
	}
	$seen{$path}++;

	# This is puzzling. Sometimes I see two songs that refer to
	# the same physical file. Apparently two versions. Both
	# versions are in the backup, the first with the length of the
	# second and the second with a length of zero.
	unless ( $sz == $len ) {
	    warn( "Song $songid, path = $path, size = $sz, mtime = $mtime (" .
		  localtime($mtime) . ")\n" )
	      if $verbose <= 1;
	    warn("Song $songid, size mismatch $sz (db) <> $len (msb)\n");
	}
	# Mike: This is how I dealt with dups and missing files.

	# Read data.
	$msb->readbuf( \my $buf, $len );

	if ( $msb->zip ) {
	    # Store into zip.
	    warn("AddString: $path\n") if $verbose;
	    local $Archive::Zip::UNICODE;
	    $Archive::Zip::UNICODE = 1;
	    my $m = $msb->zip->addString( $buf, $path, COMPRESSION_STORED );
	    $m->setLastModFileDateTimeFromUnix($mtime);
	}
	elsif ( !$check) {
	    # Make file name and create it.
	    my $fn = $path;
	    $path =~ s;^.*/;; unless $repackable;
	    $path =~ s;^/;; if $repackable;
	    $path = "media/" . $path if $repackable;
	    make_path(dirname($path));
	    $fn = $path if $path;
	    create_file( $fn, $buf, undef, $mtime );
	}
    }
}

END {
    unless ( $dbonly ) {
	foreach ( sort keys %seen ) {
	    warn("Missing file: $_\n") unless $seen{$_} > 0;
	}
    }
    if ( $msb && $msb->zip ) {
	warn("$zipfile: Write error\n")
	  unless $msb->zip->writeToFileNamed($zipfile) == AZ_OK;
	$msb->zip(0);
    }
}

################ Subroutines ################

sub create_file {
    my ( $fn, $buf, $len, $mtime ) = @_;
    sysopen( my $of, $fn, O_WRONLY|O_CREAT, 0666 )
      or die("$fn: $!\n");
    # Copy contents.
    $len ||= length($buf);
    syswrite( $of, $buf, $len ) == $len
      or die("$fn: short write:  $!\n");
    # Close.
    close($of)
      or die("$fn: close:  $!\n");
    utime( $mtime, $mtime, $fn ) if $mtime;
}

################ Subroutines ################

package MSB;

use Fcntl qw( SEEK_CUR O_RDONLY O_WRONLY O_CREAT );
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

sub new {
    my ( $pkg ) = @_;
    bless {}, $pkg
}

sub open {
    my ( $self, $fn ) = @_;
    sysopen( my $fd, $fn, O_RDONLY )
      or die("$fn: $!\n");
    $self->{fd} = $fd;

    my $magic = $self->read(4);
    if ( $magic == $FILE_MAGIC ) {
	$self->{version} = 3;
    }
    elsif ( $magic == $FILE_MAGIC+1 ) {
	$self->{version} = 4;
    }
    elsif ( $magic == $FILE_MAGIC+2 ) {
	$self->{version} = 5;
    }
    elsif ( $magic == $FILE_MAGIC+3 ) {
	$self->{version} = 6;
    }
    die("Not a valid MSPro backup file (wrong version?)\n")
      unless $self->{version};

    $self;
}

sub read {
    my ( $self, $want ) = @_;
    my $buf = "";
    my $n = sysread( $self->{fd}, $buf, $want );
    if ( $n eq length($EOF_SENTINEL) && $buf eq $EOF_SENTINEL ) {
	warn("EOF\n") if $debug;
	exit;
    }

    if ( $n < $want ) {
	warn("short read: $n bytes instead of $want\n");
    }
    return unpack( "N", $buf ) if $want == 4;
    return unpack( "n", $buf ) if $want == 2;
    my @a = unpack( "NN", $buf );
    $a[0] << 32 | $a[1];
}

sub readstring {
    my ( $self, $want ) = @_;
    my $buf;
    my $n = sysread( $self->{fd}, $buf, $want );
    if ( $n < $want ) {
	warn("short read: $n bytes instead of $want\n");
    }
    return $buf;
}

sub readbuf {
    my ( $self, $bufref, $want ) = @_;
    my $n = sysread( $self->{fd}, $$bufref, $want );
    if ( $n < $want ) {
	warn("short read: $n bytes instead of $want\n");
    }
    return $n;
}

sub version { $_[0]->{version} }

sub zip {
    my ( $self, $zip ) = @_;
    $self->{zip} = $zip if defined $zip;
    return $self->{zip};
}

sub handle_user_filters {
    my ( $self ) = @_;
    my $path = "user_filters.xml";
    my $len = $self->read(8);
    warn("Item: $path ($len bytes)\n") if $verbose > 1;
    $self->readbuf( \my $data, $len );
    warn("item: ", substr($data, 0, 20), "...\n") if $debug;

    # Verify <?xml ...> header.
    unless ( $data =~ /^\<\?xml\b.*\>/ ) {
	warn("Pref item: $path -- Missing <?xml> header\n");
    }

    return if $dbonly;

    if ( $self->zip ) {
	# Store into zip.
	warn("AddString: $path\n") if $verbose > 1;
	my $m = $self->zip->addString( $data, $path, COMPRESSION_STORED );
    }
    elsif ( !$check ) {
	::create_file( $path, $data, $len );
    }
}

sub handle_preferences {
    my ( $self ) = @_;
    my $items = $self->read(4);
    warn("Preferences: $items items\n") if $verbose && !$dbonly;

    mkdir("preferences") if $repackable;
    for my $i ( 0..$items-1 ) {
	my $len  = $self->read(2);
	my $path = $self->readstring($len) . ".xml";
	$path = "preferences/" . sprintf("%02d", $i) . "-" . $path if $repackable;
	$len = $self->read(8);
	warn("Pref item: $path ($len bytes)\n") if $verbose > 1;
	$self->readbuf( \my $data, $len );
	warn("item: ", substr($data, 0, 20), "...\n") if $debug;

	# Verify <?xml ...> header.
	unless ( $data =~ /^\<\?xml\b.*\>/ ) {
	    warn("Pref item: $path -- Missing <?xml> header\n");
	}

	# Verify <map>...</map> or <map/> content.
	unless ( $data =~ /^.*\n\<map\s*\/\>\s*$/
		 or $data =~ /^.*\n\<map\>(?:.|\n)*\<\/map\>\s*$/ ) {
	    warn("Pref item: $path -- Missing <map> content\n");
	}

	if ( $path =~ /(^|\/)\d+-default\.xml$/ ) {
	    if ( $data =~ /<string name="version">(.+?)<\/string>/ ) {
		warn("MobileSheetsPro version $1\n");
	    }
	}

	next if $dbonly;

	if ( $self->zip ) {
	    # Store into zip.
	    warn("AddString: $path\n") if $verbose > 1;
	    my $m = $self->zip->addString( $data, $path, COMPRESSION_STORED );
	}
	elsif ( !$check ) {
	    ::create_file( $path, $data, $len );
	}
    }
}

sub handle_annotations_favorites {
    my ( $self ) = @_;
    my $path = "annotations_favorites.xml";
    my $len = $self->read(8);
    warn("Item: $path ($len bytes)\n") if $verbose > 1;
    return unless $len;
    $self->readbuf( \my $data, $len );
    warn("item: ", substr($data, 0, 20), "...\n") if $debug;

    # Verify <?xml ...> header.
    unless ( $data =~ /^\<\?xml\b.*\>/ ) {
	warn("Pref item: $path -- Missing <?xml> header\n");
    }

    next if $dbonly;

    if ( $self->zip ) {
	# Store into zip.
	warn("AddString: $path\n") if $verbose > 1;
	my $m = $self->zip->addString( $data, $path, COMPRESSION_STORED );
    }
    elsif ( !$check ) {
	::create_file( $path, $data, $len );
    }
}

sub handle_stamplists {
    my ( $self ) = @_;
    my $path = "stamplists.json";
    my $len = $self->read(8);
    warn("Item: $path ($len bytes)\n") if $verbose > 1;
    return unless $len;

    $self->readbuf( \my $data, $len );
    warn("item: ", substr($data, 0, 20), "...\n") if $debug;


    # Verify JSON (like).
    unless ( $data =~ /^\{.*\}[\n\r]+$/s ) {
	warn("Stamplists: $path -- Not JSON?\n");
    }
    next if $dbonly;

    if ( $self->zip ) {
	# Store into zip.
	warn("AddString: $path\n") if $verbose > 1;
	my $m = $self->zip->addString( $data, $path, COMPRESSION_STORED );
    }
    elsif ( !$check ) {
	::create_file( $path, $data, $len );
    }
}

sub handle_custom_stamps {
    my ( $self ) = @_;
    my $items = $self->read(4);
    warn("Custom stamps: $items items\n") if $verbose && !$dbonly;

    mkdir("custom_stamps") if $repackable;
    for my $i ( 0..$items-1 ) {
	my $len  = $self->read(2);
	my $path = $self->readstring($len);
	$path = "custom_stamps/" . sprintf("%02d", $i) . "-" . $path if $repackable;
	$len = $self->read(8);
	warn("Custom item: $path ($len bytes)\n") if $verbose > 1;
	$self->readbuf( \my $data, $len );
	warn("item: ", substr($data, 0, 20), "...\n") if $debug;

	next if $dbonly;

	if ( $self->zip ) {
	    # Store into zip.
	    warn("AddString: $path\n") if $verbose > 1;
	    my $m = $self->zip->addString( $data, $path, COMPRESSION_STORED );
	}
	elsif ( !$check ) {
	    ::create_file( $path, $data, $len );
	}
    }
}

sub handle_database {
    my ( $self, $dbfile ) = @_;

    my $len = $self->read(8);
    warn( "Database length = $len\n" ) if $verbose > 2;

    my $path = $dbfile;
    $path =~ s;^.*/;;;
    $dbfile = $path if $path;

    # Read content.
    $msb->readbuf( \my $buf, $len );

    # We need a disk file for SQLite, so store the database
    # in a temp file.
    if ( $check || $self->zip ) {
	# Add to the zip.
	$dbfile = Archive::Zip::tempFile;
	::create_file( $dbfile, $buf );
	$self->zip->addFile( $dbfile, $path, COMPRESSION_DEFLATED )
	  unless $check;
    }
    else {
	::create_file( $dbfile, $buf );
    }
    # Connect to SQLite database.
    eval {
	$self->{dbh} = DBI::->connect( "dbi:SQLite:dbname=$dbfile", "", "",
				       { sqlite_unicode => 1 } );
	1;
    } or warn("DATABASE IS POSSIBLY CORRUPT\n");

    my $v = $self->{dbh}->selectrow_array("pragma user_version");
    warn("Database API version: $v\n");
    foreach $file ( @{ $self->{dbh}->selectall_arrayref("SELECT Id,Path,Type FROM Files") } ) {
	next if $file->[2] == 5; # placeholder
	warn("File ", $file->[0], " has no path?\n"), next unless $file->[1];
	$seen{$file->[1]} = 0;
    }
    foreach $file ( @{ $self->{dbh}->selectall_arrayref("SELECT Id,File FROM AudioFiles") } ) {
	warn("File ", $file->[0], " has no path?\n"), next unless $file->[1];
	$seen{$file->[1]} = 0;
    }
    warn("Datatase: ", scalar(keys(%seen)), " file entries\n")
      if $verbose;
}

sub get_dbfiles {
    my ( $self, $songid ) = @_;
    # Get the list of files associated with this song.
    # Oops. The previous song needed some more files...
    warn("Missing: $_->[0]\n") foreach @{ $self->dbfiles };
    $self->{dbfiles} = [];
    my $sth = $self->{dbh}->prepare
      ( "SELECT Path,LastModified,FileSize FROM Files WHERE SongId = ?" );
    $sth->execute($songid);
    while ( my $rr = $sth->fetch ) {
	push( @{ $self->{dbfiles} }, [ @$rr ] );
    }
    my $i = @{ $self->{dbfiles} };
    $sth = $self->{dbh}->prepare
      ( "SELECT File,LastModified,FileSize FROM AudioFiles WHERE SongId = ?" );
    $sth->execute($songid);
    while ( my $rr = $sth->fetch ) {
	push( @{ $self->{dbfiles} }, [ @$rr ] );
    }
    warn( "DB files: $i + ", @{ $self->{dbfiles} }-$i, " audio\n" )
      if $verbose > 2;
}

sub dbfiles {
    my ( $self) = @_;
    $self->{dbfiles} ||= [];
    wantarray ? @{ $self->{dbfiles} } : $self->{dbfiles};
}

package main;

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
	GetOptions('zip=s'	=> \$zipfile,
		   'verify|check'	=> \$check,
		   'dbonly'	=> \$dbonly,
		   'ident'	=> \$ident,
		   'verbose+'	=> \$verbose,
		   'repackable!'   => \$repackable,
		   'quiet'	=> sub { $verbose = 0 },
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
    $pod2usage->(2) if $zipfile && $check;
}

__END__

################ Documentation ################

=head1 NAME

msb_unpack - unpacks a MobileSheetsPro backup set

=head1 SYNOPSIS

msb_unpack [options] file

 Options:
   --zip=XXX		produce a zip
   --check		integrity check only
   --dbonly             extract the database only
   --ident		show identification
   --help		brief help message
   --man                full documentation
   --verbose		more verbose information
   --quiet		run as quietly as possible
   --[no]repackable	output compatible with msb_pack

=head1 OPTIONS

=over 8

=item B<--zip=>I<XXX>

Instead of unpacking everything into the current directory, produces a
zip file containing everything. Experimental.

=item B<--check>

Checks integrity only. Does not extract files.

This option cannot be used together with the B<--zip> option.

=item B<--dbonly>

Only extracts the database, not the files.

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

More verbose information. In particular, the song number for each
entry is reported.

=item B<--quiet>

Runs as quietly as possible.

=item I<file>

The MobileSheetsProBackup set to unpack.

=item B<--repackable>

Unpack media files into media/ and preferences into preferences/ so that they can be re-packed by msb_pack.pl

=back

=head1 DESCRIPTION

B<msb_unpack> will read the given backup set and unpack it.

The results will be a collection of files in the current directory, or
a zip file when selected with the --zip command line option.

=head1 DISCLAIMER

This is 'work in progress' and 'works for me'.

Much is based upon reverse engineering the MSPro database contents and
backup set format. Many bits and bytes are still not taken into
account.

THERE IS NO GUARANTEE THAT THIS PROGRAM WILL DO ANYTHING USEFUL FOR YOU.

=cut
