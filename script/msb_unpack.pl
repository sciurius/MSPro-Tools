#!/usr/bin/perl

# Unpack a MobileSheetsPro backup file.

# Author          : Johan Vromans
# Created On      : Fri May  1 18:39:01 2015
# Last Modified By: Johan Vromans
# Last Modified On: Sun May 31 20:54:05 2015
# Update Count    : 118
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

# Package name.
my $my_package = 'MSProTools';
# Program name and version.
my ($my_name, $my_version) = qw( msb_unpack 0.10 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $msbfile = "MobileSheetsProBackup.msb";
my $zipfile;
my $ann = 1;			# process annotations
my $verbose = 0;		# verbose processing

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $trace = 0;			# trace (show process)
my $test = 0;			# test mode.

# Process command line options.
app_options();

# Post-processing.
$msbfile = shift if @ARGV == 1;
$trace |= ($debug || $test);

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

use Fcntl qw( SEEK_CUR O_RDONLY O_WRONLY O_CREAT );
use DBI;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

# MSB File Format, as told by Mike.
#
# 499602d4         file magic word (version 3) 1234567892
# xxxxxxxxxxxxxxxx 8-byte data length
# xxxxxxxxxxxxxxxx database file data
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

sysopen( my $fd, $msbfile, O_RDONLY, 0 )
  or die("$msbfile: $!\n");

my $buf;
my $len = sysread( $fd, $buf, 4 );
die("Not a valid MSPro backup file\n")
  unless $len == 4 && unpack( "N", $buf) == $FILE_MAGIC;

# First entry in the file is the database.

$len = read8();
my $file = 0;
warn( "file $file, length = $len\n" ) if $debug;
my $path = "mobilesheets.db";

# For database date.
my $dbh;
my $sth;

# For zip output.
my $zip;
if ( $zipfile ) {
    $zip = Archive::Zip->new;
}

for ( ;; ) {

    my $fn = sprintf( "file%03d.dat", $file );
    my $mtime = 0;
    my $sz = 0;
    if ( $dbh ) {
	$path = "";
	# Be careful -- the database may be damaged.
	eval {
	    $sth->execute( $file );
	    ( $path, $mtime, $sz ) = @{ $sth->fetch };
	    $mtime = int( $mtime/1000 );
	    warn( "File $file, path = $path, size = $sz ($len), mtime = $mtime (" .
		  localtime($mtime) . ")\n" )
	      if $verbose;
	    $sth->finish;
	};

	# This is puzzling. Sometimes I see two songs that refer to
	# the same physical file. Apparently two versions. Both
	# versions are in the backup, the first with the length of the
	# second and the second with a length of zero.
	warn("File $file, size mismatch $sz <> $len\n") unless $sz == $len;
	# Mike: This is how I dealt with dups and missing files.
    }

    if ( $zip && $file ) {
	# Store into zip.
	sysread( $fd, $buf, $len );
	warn("AddString: $path\n");
	my $m = $zip->addString( $buf, $path, COMPRESSION_STORED );
	$m->setLastModFileDateTimeFromUnix($mtime);
    }
    else {
	# Make file name and create it.
	$path =~ s;^.*/;;;
	$fn = $path if $path;

	# We need a disk file for SQLite, so store the database
	# in a temp file.
	$fn = Archive::Zip::tempFile if $zip;

	sysopen( my $of, $fn, O_WRONLY|O_CREAT, 0666 );
	# Copy contents.
	sysread( $fd, $buf, $len );
	syswrite( $of, $buf );
	# Close.
	close($of);
	utime( $mtime, $mtime, $fn ) if $mtime;
    }

    # Special treatment for the first file (the database).
    if ( $file == 0 ) {
	if ( $zipfile ) {
	    # Add to the zip.
	    $zip->addFile( $fn, $path, COMPRESSION_DEFLATED );
	}
	eval {
	    $dbh = DBI::->connect( "dbi:SQLite:dbname=$fn", "", "" );
	    $sth = $dbh->prepare( "SELECT Path,LastModified,FileSize FROM Files WHERE SongId = ?" );
	};
    }

    die("Corrupted data -- header magic not found\n")
      unless read8() == $HDR_MAGIC;

    $file = read8();		# database song id
    $len = read8();
    warn("file = $file, length = $len\n") if $debug;

    # Next iteration will copy the contents.
}

END {
    if ( $zip ) {
	warn("$zipfile: Write error\n")
	  unless $zip->writeToFileNamed($zipfile) == AZ_OK;
	$zip = "";
    }
}

################ Subroutines ################

sub read8 {
    my $buf;
    my $n = sysread( $fd, $buf, 8 );

    if ( $n eq length($EOF_SENTINEL) && $buf eq $EOF_SENTINEL ) {
	warn("EOF\n") if $debug;
	exit;
    }
    if ( $n < 8 ) {
	warn("short read: $n bytes instead of 8\n");
    }
    my @a = unpack( "NN", $buf );
    $a[0] << 32 | $a[1];
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
	GetOptions('zip=s'	=> \$zipfile,
		   'ident'	=> \$ident,
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

msb_unpack - unpacks a MobileSheetsPro backup set

=head1 SYNOPSIS

msb_unpack [options] file

 Options:
   --zip=XXX		produce a zip
   --ident		show identification
   --help		brief help message
   --man                full documentation
   --verbose		verbose information

=head1 OPTIONS

=over 8

=item B<--zip=>I<XXX>

Instead of unpacking everything into the current directory, produces a
zip file containing everything. Experimental.

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

More verbose information. In particular, the song number for each
entry is reported.

=item I<file>

The MobileSheetsProBackup set to unpack.

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
