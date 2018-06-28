#!/usr/bin/perl

# Relocate a MobileSheetsPro backup file.

# Author          : Johan Vromans
# Created On      : Mon Mar 14 08:32:12 2016
# Last Modified By: Johan Vromans
# Last Modified On: Tue Jun 26 12:44:09 2018
# Update Count    : 62
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

# Package name.
my $my_package = 'MSProTools';
# Program name and version.
my ($my_name, $my_version) = qw( msb_reloc 0.05 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $msbfile = "MobileSheetsProBackup.msb";
my $newmsbfile = "MobileSheetsProBackup_reloc.msb";
my $srcpath;
my $dstpath;
my $verbose = 1;		# verbose processing

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

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

use Fcntl qw( SEEK_CUR O_RDONLY O_WRONLY O_CREAT );
use DBI;
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

$msb->create($newmsbfile);

if ( $msb->version >= 4 ) {
    $msb->handle_preferences;
}

# First entry in the file is the database.
$msb->handle_database( "mobilesheets.db" );

my $len;
my $file = 0;
my %seen;

while ( my $n = $msb->read(8) ) {

    if ( $n != $HDR_MAGIC ) {
	# Add recovery later.
	die("OOPS -- Missing magic... punting\n");
    }
    $msb->write( $n, 8 );
    my $songid = $msb->read(8);
    $msb->write( $songid, 8 );
    $msb->get_dbfiles($songid);

    while ( my $info = shift( @{ $msb->dbfiles } )  ) {
	my ( $path, $mtime, $sz ) = @$info;
	unless ( $path ) {
	    warn("Song $songid, not included\n") if $verbose > 1;
	    last;
	}
	warn( "Song $songid, path = $path, size = $sz, mtime = $mtime (" .
	      localtime($mtime) . ")\n" )
	  if $verbose > 1;
	next if $sz == 0;

	$mtime = int( $mtime/1000 );
	my $len = $msb->read(8);
	$msb->write( $len, 8 );
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
	warn("Song $songid, size mismatch $sz <> $len\n") unless $sz == $len;
	# Mike: This is how I dealt with dups and missing files.

	# Copy data.
	$msb->readbuf( \my $buf, $len );
	$msb->writebuf( \$buf, $len );
    }
}

END {
    if ( $msb ) {
	$msb->writestring( $EOF_SENTINEL, 8 );
	$msb->{ofd}->close;
	undef $msb;
    }
    my $missing = 0;
    foreach ( sort keys %seen ) {
	next if $seen{$_} > 0;
	$missing++;
	# warn("Missing file: $_\n");
    }
    warn("Number of missing files = $missing\n") if $missing;
}

################ Subroutines ################

sub create_file {
    my ( $fh, $fn, $buf, $len, $mtime ) = @_;
    binmode($fh);
    # Copy contents.
    $len ||= length($buf);
    syswrite( $fh, $buf, $len ) == $len
      or die("$fn: write error:  $!\n");
    # Close.
    close($fh)
      or die("$fn: close:  $!\n");
    utime( $mtime, $mtime, $fn ) if $mtime;
}

################ Subroutines ################

package MSB;

use File::Temp qw( tempfile );
use Fcntl qw( SEEK_CUR O_RDONLY O_WRONLY O_CREAT );

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
    die("Not a valid MSPro backup file (wrong version?)\n")
      unless $self->{version};

    $self;
}

sub create {
    my ( $self, $fn ) = @_;
    sysopen( my $fd, $fn, O_WRONLY|O_CREAT, 0666 )
      or die("$fn: $!\n");
    $self->{ofd} = $fd;

    if ( $self->{version} == 4 ) {
	$self->write( $FILE_MAGIC+1, 4 );
    }
    elsif ( $self->{version} == 3 ) {
	$self->write( $FILE_MAGIC, 4 );
    }
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

sub write {
    my ( $self, $value, $len ) = @_;
    my $buf;
    if ( $len == 8 ) {
	$buf = eval { pack( "Q>", $value ) } || "\0\0\0\0".pack("N", $value);
    }
    elsif ( $len == 4 ) {
	$buf = pack( "N", $value );
    }
    elsif ( $len == 2 ) {
	$buf = pack( "n", $value );
    }
    my $n = syswrite( $self->{ofd}, $buf, $len );
    if ( $n != $len ) {
	warn("write error: $n bytes instead of $len\n");
    }
    return $n;
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

sub writestring {
    my ( $self, $string, $len ) = @_;
    my $n = syswrite( $self->{ofd}, $string, $len );
    if ( $n != $len ) {
	warn("write error: $n bytes instead of $len\n");
    }
    return $n;
}

sub readbuf {
    my ( $self, $bufref, $want ) = @_;
    my $n = sysread( $self->{fd}, $$bufref, $want );
    if ( $n < $want ) {
	warn("short read: $n bytes instead of $want\n");
    }
    return $n;
}

sub writebuf {
    my ( $self, $bufref, $len ) = @_;
    my $n = syswrite( $self->{ofd}, $$bufref, $len );
    if ( $n != $len ) {
	warn("write error: $n bytes instead of $len\n");
    }
    return $n;
}

sub version { $_[0]->{version} }

sub handle_preferences {
    my ( $self ) = @_;
    my $items = $self->read(4);
    warn("Preferences: $items items\n") if $verbose;
    $self->write( $items, 4 );
    for my $i ( 0..$items-1 ) {
	my $len = $self->read(2);
	my $path = $self->readstring($len) . ".xml";
	warn("Pref item: $path ($len)\n") if $verbose > 1;
	$self->write( $len, 2 );
	$self->writestring( $path, $len ); # yes, this will cut off ".xml"
	$len = $self->read(8);
	$self->readbuf( \my $data, $len );
	warn("item: ", substr($data, 0, 20), "...\n") if $debug;
	if ( 0 && $path eq "default.xml" ) {
	    #     <string name="storage_dir">/storage/C443-17EE/Android/data/com.zubersoft.mobilesheetspro/files</string>
	    $data =~ s;>\Q$srcpath\E;>$dstpath;g;
	    $len = length($data);
	}
	$self->write( $len, 8 );
	$self->writebuf( \$data, $len );

	# Verify <?xml ...> header.
	unless ( $data =~ /^\<\?xml\b.*\>/ ) {
	    warn("Pref item: $path -- Missing <?xml> header\n");
	}

	# Verify <map>...</map> or <map/> content.
	unless ( $data =~ /^.*\n\<map\s*\/\>\s*$/
		 or $data =~ /^.*\n\<map\>(?:.|\n)*\<\/map\>\s*$/ ) {
	    warn("Pref item: $path -- Missing <map> content\n");
	}
    }
}

sub handle_database {
    my ( $self, $dbfile ) = @_;

    my $len = $self->read(8);
    warn( "Database length = $len\n" ) if $verbose > 2;

    # Read content.
    $msb->readbuf( \my $buf, $len );

    # We need a disk file for SQLite, so store the database
    # in a temp file.
    my $db;
    ( $db, $dbfile ) = tempfile();
    ::create_file( $db, $dbfile, $buf );
    warn("Using temporary database $dbfile\n") if $verbose;
    $db->close;
    # Connect to SQLite database.
    $self->{dbh} = DBI::->connect( "dbi:SQLite:dbname=$dbfile", "", "",
				   { sqlite_unicode => 1 } );
    warn("Database $dbfile has been opened\n") if $verbose;

    my $tally = 0;
    my $rr = 0;
    foreach $file ( @{ $self->{dbh}->selectall_arrayref("SELECT Id,Path,Type FROM Files") } ) {
	$tally++;
	next if $file->[2] == 5; # placeholder
	warn("File ", $file->[0], " has no path?\n"), next unless $file->[1];
	my $fn = $file->[1];
	if ( $srcpath && $srcpath eq substr($fn, 0, length($srcpath)) ) {
	    $fn = $dstpath . substr($fn, length($srcpath));
	    $rr++;
	}
	$seen{$fn} = 0;
	if ( $fn ne $file->[1] ) {
	    $self->{dbh}->do("UPDATE Files SET Path = ? WHERE Id = ?", {},
			     $fn, $file->[0]);
	}
    }
    foreach $file ( @{ $self->{dbh}->selectall_arrayref("SELECT Id,File FROM AudioFiles") } ) {
	$tally++;
	warn("File ", $file->[0], " has no path?\n"), next unless $file->[1];
	my $fn = $file->[1];
	if ( $srcpath && $srcpath eq substr($fn, 0, length($srcpath)) ) {
	    $fn = $dstpath . substr($fn, length($srcpath));
	    $rr++;
	}
	$seen{$fn} = 0;
	if ( $fn ne $file->[1] ) {
	    $self->{dbh}->do("UPDATE AudioFiles SET File = ? WHERE Id = ?", {},
			     $fn, $file->[0]);
	}
    }
    warn("Datatase: $tally file entries, $rr have been relocated\n")
      if $verbose;

    # Flush changes and reopen readonly.
    $self->{dbh}->disconnect;
    $self->{dbh} = DBI::->connect( "dbi:SQLite:dbname=$dbfile", "", "",
				   { sqlite_unicode => 1,
				     sqlite_open_flags => 1,
				   } );
    warn("Database $dbfile has been reopened\n") if $verbose;

    $len = -s $dbfile;
    $self->write( $len, 8 );
    sysopen( my $fi, $dbfile, O_RDONLY )
      or die("$dbfile: $!\n");
    $buf = "";
    my $offset = 0;
    while ( my $n = sysread( $fi, $buf, 10240, $offset ) ) {
	$offset += $n;
    }
    unless ( length($buf) == $len ) {
	die("OOPS1 ", length($buf), " <> $len\n");
    }
    unless ( length($buf) == $offset ) {
	die("OOPS2 ", length($buf), " <> $offset\n");
    }
    $self->writebuf( \$buf, $len );
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
    warn( "DB files for song $songid: $i + ",
	  @{ $self->{dbfiles} }-$i, " audio\n" )
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
	GetOptions('src=s'	=> \$srcpath,
		   'dst=s'	=> \$dstpath,
		   'ident'	=> \$ident,
		   'verbose+'	=> \$verbose,
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
}

__END__

################ Documentation ################

=head1 NAME

msb_reloc - relocates a MobileSheetsPro backup set

=head1 SYNOPSIS

msb_reloc [options] file

 Options:
   --src=XXX		old path prefix
   --dst=XXX		new path prefix
   --ident		show identification
   --help		brief help message
   --man                full documentation
   --verbose		more verbose information
   --quiet		run as quietly as possible

=head1 OPTIONS

=over 8

=item B<--src=>I<XXX>

The old path prefix. Every file path in the database that starts with
this prefix will have this prefix stripped, and the new prefix (if any)
prepended.

=item B<--dst=>I<XXX>

The new path prefix. Every file path in the database that starts with
the old prefix will have this prefix stripped, and the new prefix
prepended.

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

The MobileSheetsProBackup set to relocate.

Default is C<MobileSheetsProBackup.msb>.

The relocated backup set will be written to C<MobileSheetsProBackup_reloc.msb>.

=back

=head1 DESCRIPTION

B<msb_reloc> will copy the contents of the given backup into a new
backup set. The new set will be identical to the old one, except that
in the database all path names have been changed according to the
B<--src> and B<--dst> arguments.

For example, if your files are currently residing on
C</storage/sdcard1> and you want to restore the backup set on a tablet
where the external SDcard is called C</storage/0123-4567>, you can use
the following command:

  perl msb_reloc --src=/storage/sdcard1/ --dst=/storage/0123-4567/

(Note the trailing slashes.)

You can use B<msb_unpack> to verify the contents of the relocated
backup set.

=head1 DISCLAIMER

This is 'work in progress' and 'works for me'.

Much is based upon reverse engineering the MSPro database contents and
backup set format. Many bits and bytes are still not taken into
account.

THERE IS NO GUARANTEE THAT THIS PROGRAM WILL DO ANYTHING USEFUL FOR YOU.

=cut
