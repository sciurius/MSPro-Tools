#!/usr/bin/perl

# Pack a MobileSheetsPro backup file.

# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

# Package name.
my $my_package = 'MSProTools';
# Program name and version.
my ($my_name, $my_version) = qw( msb_pack 0.13 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $newmsbfile = "MobileSheetsProBackup_repacked.msb";
my $dir;
my $dbonly = 0;
my $ann = 1;			# process annotations
my $check = 0;			# check integrity only
my $verbose = 1;		# verbose processing

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $trace = 0;			# trace (show process)
my $test = 0;			# test mode.

# Process command line options.
app_options();

# Post-processing.
$newmsbfile = shift if @ARGV == 1;
$trace ||= ($debug || $test);
$verbose ||= $trace;
$verbose = 9 if $debug;

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

use Fcntl qw( SEEK_CUR O_RDONLY O_WRONLY O_CREAT );
use File::Path qw(make_path);
use File::Basename qw(dirname);
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

my $FILE_MAGIC   = 1234567895;		# version 6
my $HDR_MAGIC    = 1287706427353294236;
my $EOF_SENTINEL = "\xff" x 8;

$dir ||= ".";
$dir .= "/" unless $dir =~ m;/$;;
$dir = "" if $dir eq "./";

die("Missing ${dir}mobilesheets.db ... is here a backup set?\n")
  unless -s "${dir}mobilesheets.db";

my $msb = MSB->new->create($newmsbfile);

chdir($dir) if $dir;

$msb->write_preferences;
$msb->write_data("user_filters.xml");
$msb->write_data("annotations_favorites.xml");
$msb->write_data("stamplists.json");
$msb->write_custom_stamps();
$msb->write_file("mobilesheets.db");

$msb->open_db("mobilesheets.db");

# Now write media files

my @db_files = $msb->get_dbfiles();

my $len;
my $file = 0;
my %seen;

my $lastSongId = -1;

my %written_paths;

foreach my $row (@db_files) {
    my ($Id, $SongId, $ordering, $Path, $LastModified, $FileSize) = @$row;
    if ($lastSongId != $SongId) {
        $msb->write($HDR_MAGIC, 8);
        $msb->write($SongId, 8);
    }
    $lastSongId = $SongId;
 
    unless ($written_paths{$Path}) {
        $msb->write_file("media/" . $Path)
    } else {
        $msb->write(0, 8);
    }
    $written_paths{$Path} = 1;
}

$msb->writestring( $EOF_SENTINEL, 8 );
$msb->{ofd}->close;

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

sub new {
    my ( $pkg ) = @_;
    bless {}, $pkg
}

sub create {
    my ( $self, $fn ) = @_;
    sysopen( my $fd, $fn, O_WRONLY|O_CREAT, 0666 )
      or die("$fn: $!\n");
    $self->{ofd} = $fd;

    $self->write( $FILE_MAGIC, 4 );
    $self;
}

sub write {
    my ( $self, $value, $len ) = @_;
    my $buf;
    if ( $len == 8 ) {
	$buf = eval { pack( "Q>", $value ) } // "\0\0\0\0".pack("N", $value);
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

sub writestring {
    my ( $self, $string, $len ) = @_;
    my $n = syswrite( $self->{ofd}, $string, $len );
    if ( $n != $len ) {
	warn("write error: $n bytes instead of $len\n");
    }
    return $n;
}

sub write_file {
    my ( $self, $dbfile) = @_;
    my $len = -s $dbfile;
    $self->write( $len // 0, 8 );
    return unless $len;
    sysopen( my $fi, $dbfile, O_RDONLY )
      or die("$dbfile: $!\n");
    my $buf = "";
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

sub writebuf {
    my ( $self, $bufref, $len ) = @_;
    my $n = syswrite( $self->{ofd}, $$bufref, $len );
    if ( $n != $len ) {
    warn("write error: $n bytes instead of $len\n");
    }
    return $n;
}

sub version { $_[0]->{version} }

sub write_preferences {
    my ( $self ) = @_;
    my $dir = 'preferences';
    opendir my $dh, $dir  or die "Can't open $dir: $!";
    my @xml_files = sort grep { /.xml$/ } readdir($dh);
    my $items = @xml_files;

    warn("Preferences: $items items\n") if $verbose > 1;

    $self->write($items, 4);
    foreach my $item (@xml_files) {
        warn("Processing pref $item\n");
        my $name = $item;
        $name =~s/^[0-9]*-(.*).xml/$1/;
        $self->write(length($name), 2);
        $self->writestring($name, length($name));
        $self->write_file("$dir/$item");
    }
}

sub write_data {
    my ( $self, $item ) = @_;
    warn("Processing file $item\n");
    my $name = $item;
#    $self->write(length($name), 2);
#    $self->writestring($name, length($name));
    $self->write_file($item);
}

sub write_custom_stamps {
    my ( $self ) = @_;
    my $dir = 'custom_stamps';
    opendir my $dh, $dir  or do {
	warn "No custom stamps (Can't open $dir: $!)\n";
	$self->write( 0, 4 );
	return;
    };
    my @files = sort grep { /^\d+-.*$/ } readdir($dh);
    my $items = @files;

    warn("Custom stamps: $items items\n") if $verbose > 1;

    $self->write($items, 4);
    foreach my $item (@files) {
        warn("Processing custom stamp $item\n");
        my $name = $item;
        $name =~s/^[0-9]*-//;
        $self->write(length($name), 2);
        $self->writestring($name, length($name));
        $self->write_file("$dir/$item");
    }
}

sub open_db {
    my ( $self, $dbfile) = @_;
    $self->{dbh} = DBI::->connect( "dbi:SQLite:dbname=$dbfile", "", "",
                   { sqlite_unicode => 1,
                     sqlite_open_flags => 1,
                   } );
    warn("Database $dbfile has been opened\n") if $verbose;
}

sub get_dbfiles {
    my ( $self) = @_;
    my @result;
    my $query = <<'end_query_delimiter';
SELECT 
  Files.Id as Id, 
  Files.SongId as SongId, 
  'a' as ordering, 
  Files.Path, 
  Files.LastModified, 
  Files.FileSize, 
  Songs.Title as Title 
FROM 
  Files join Songs on Files.SongId = Songs.Id
UNION 
SELECT 
  AudioFiles.Id as Id, 
  AudioFiles.SongId as SongId, 
  'b' as ordering, 
  AudioFiles.File, 
  AudioFiles.LastModified, 
  AudioFiles.FileSize, 
  Songs.Title as Title
FROM 
  AudioFiles join Songs on AudioFiles.SongId = Songs.Id 
ORDER BY 
  Title, SongId, ordering, Id asc;
end_query_delimiter
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute();
    while ( my $rr = $sth->fetch ) {
	   push(@result, [ @$rr ] );
    }
    return @result;
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
	GetOptions('verify|check'	=> \$check,
		   'dbonly'	=> \$dbonly,
		   'dir=s'	=> \$dir,
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

msb_pack - packs a MobileSheetsPro backup set that has been unpacked by msb_unpack

=head1 SYNOPSIS

msb_pack [options] file

 Options:
   --ident		show identification
   --help		brief help message
   --man                full documentation
   --verbose		more verbose information
   --quiet		run as quietly as possible

=head1 OPTIONS

=over 8

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

The destination file for the backup.

=back

=head1 DESCRIPTION

B<msb_pack> will read the given backup set and pack it.

The results will be a single msb file

=head1 DISCLAIMER

This is 'work in progress' and 'works for me'.

Much is based upon reverse engineering the MSPro database contents and
backup set format. Many bits and bytes are still not taken into
account.

THERE IS NO GUARANTEE THAT THIS PROGRAM WILL DO ANYTHING USEFUL FOR YOU.

=cut
