#!/usr/bin/perl

# Unpack a MobileSheetsPro backup file.

# Author          : Johan Vromans
# Created On      : Fri May  1 18:39:01 2015
# Last Modified By: Johan Vromans
# Last Modified On: Sun May 31 11:35:42 2015
# Update Count    : 91
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

sysopen( my $fd, $msbfile, O_RDONLY, 0 )
  or die("$msbfile: $!\n");

my $buf;
my $len;
my $eof_sentinel = "\xff" x 8;

# First 12 bytes
# 4996 02d4 0000 0000 0005 b000
# last 4 bytes are the length, in network byte order.

( $buf, $len ) = readbytes(12);
my $file = 0;
warn( "file $file, length = $len\n" ) if $debug;

# First file is the database.
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

    # Next 'header'. Contents not yet understood.
    # Bytes 0 .. 3: 11 de da 2c (so far)
    # Bytes 4 .. 7: 51 61 65 9c (so far)
    # Bytes 8 .. 11: zeroes (assumingly to distinguish from 'file' headers)
    ( $buf, $len ) = readbytes(12);
    warn( sprintf( "length = $len, %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x\n",
	  map { ord } split( //, $buf ) ) ) if $debug;

    # Next 'header' ('file' header?)
    # Bytes 0 .. 3:  file number
    # Bytes 4 .. 7:  zeroes (so far).
    # Bytes 8 .. 11: the length of the data
    ( $buf, $len ) = readbytes(12);
    $file = unpack( "N", substr( $buf, 0, 4 ) );
    my $rest = substr( $buf, 4, 4 );
    if ( $rest eq "\0\0\0\0" ) {
	warn("file = $file, length = $len\n") if $debug;
    }
    else {
	warn( sprintf( "file = $file, length = $len, rest = %02x %02x %02x %02x\n",
		       map { ord } split( //, $rest ) ) );
    }

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

sub readbytes {
    my ( $cnt ) = @_;
    my $buf;
    my $n = sysread( $fd, $buf, $cnt );

    if ( $n eq length($eof_sentinel) && $buf eq $eof_sentinel ) {
	warn("EOF\n") if $debug;
	exit;
    }
    if ( $n < $cnt ) {
	warn("short read: $n bytes instead of $cnt\n");
    }
    my $length = unpack( "N", substr( $buf, -4 ) );
    wantarray ? ( $buf, $length ) : $buf;
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
