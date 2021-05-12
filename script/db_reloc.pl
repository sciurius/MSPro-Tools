#!/usr/bin/perl

# Relocate filenames in a MobileSheetsPro database.

# Author          : Johan Vromans
# Created On      : Tue Mar 15 07:50:53 2016
# Last Modified By: Johan Vromans
# Last Modified On: Wed May 12 19:36:17 2021
# Update Count    : 25
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

# Package name.
my $my_package = 'MSProTools';
# Program name and version.
my ($my_name, $my_version) = qw( db_reloc 0.02 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $dbfile = "mobilesheets.db";
my $newdbfile = "mobilesheets_reloc.db";
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
$dbfile = shift if @ARGV == 1;
$trace ||= ($debug || $test);
$verbose ||= $trace;
$verbose = 9 if $debug;

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

use DBI;
use Encode;

die("$dbfile: $!\n") unless -s $dbfile;

my $dbh = DBI::->connect( "dbi:SQLite:dbname=$dbfile", "", "",
			  { sqlite_unicode => 1,
			    sqlite_open_readonly => 1,
			  } );
$dbh->sqlite_backup_to_file($newdbfile);
warn("Database $dbfile has been copied to $newdbfile\n")
  if $verbose;

$dbh = DBI::->connect( "dbi:SQLite:dbname=$newdbfile", "", "",
		       { sqlite_unicode => 1,
		       } );
warn("Database $newdbfile has been reopened\n") if $verbose;

my $res = $dbh->selectall_arrayref("SELECT count(*) FROM Files", {});
warn("Processing $res->[0]->[0] file entries...\n")
  if $verbose;

my $tally = 0;
my $rr = 0;
my $sth = $dbh->prepare("SELECT Id,Path,Type FROM Files");
$sth->execute;
while ( my $file = $sth->fetch ) {
    $tally++;
    next if $file->[2] == 5; # placeholder
    warn("File ", $file->[0], " has no path?\n"), next unless $file->[1];
    my $fn = $file->[1];
    if ( $srcpath && $srcpath eq substr($fn, 0, length($srcpath)) ) {
	$fn = $dstpath . substr($fn, length($srcpath));
    }
    if ( $fn ne $file->[1] ) {
	$dbh->do("UPDATE Files SET Path = ? WHERE Id = ?", {},
		 $fn, $file->[0]);
	$rr++;
	warn("Reloc $rr/$tally...\n")
	  if $verbose && $rr % 100 == 0;
    }
}

$res = $dbh->selectall_arrayref("SELECT count(*) FROM AudioFiles", {});
warn("Processing $res->[0]->[0] audiofile entries...\n")
  if $verbose;

$sth = $dbh->prepare("SELECT Id,File FROM AudioFiles");
$sth->execute;
while ( my $file = $sth->fetch ) {
    $tally++;
    warn("File ", $file->[0], " has no path?\n"), next unless $file->[1];
    my $fn = $file->[1];
    if ( $srcpath && $srcpath eq substr($fn, 0, length($srcpath)) ) {
	$fn = $dstpath . substr($fn, length($srcpath));
    }
    if ( $fn ne $file->[1] ) {
	$dbh->do("UPDATE AudioFiles SET File = ? WHERE Id = ?", {},
			 $fn, $file->[0]);
	$rr++;
	warn("Reloc $rr/$tally...\n")
	  if $verbose && $rr % 100 == 0;
    }
}

warn("Datatase $newdbfile: $tally file entries, $rr have been relocated\n")
  if $verbose;

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
		   'output=s'	=> \$newdbfile,
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

db_reloc - relocates filenames in a MobileSheetsPro database

=head1 SYNOPSIS

msb_reloc [options] [ dbfile ]

 Options:
   --src=XXX		old path prefix
   --dst=XXX		new path prefix
   --output=XXX		new database name
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

=item B<--output=>I<XXX>

Name of the modified database.

Default is C<mobilesheets_reloc.db>.

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

The MobileSheetsProBackup database to relocate.

Default is C<mobilesheets.db>.

The relocated database will be written to C<mobilesheets_reloc.db>
unless an alternative name was specified with the B<--output> option.

=back

=head1 DESCRIPTION

B<db_reloc> will copy the contents of the given database into a new
database. The new database will be identical to the old one, except
that all path names have been changed according to the B<--src> and
B<--dst> arguments.

For example, if your files are currently residing on
C</storage/sdcard1> and you want to use the database on a tablet
where the external SDcard is called C</storage/0123-4567>, you can use
the following command:

  perl db_reloc --src=/storage/sdcard1/ --dst=/storage/0123-4567/

(Note the trailing slashes.)

=head1 DISCLAIMER

This is 'work in progress' and 'works for me'.

Much is based upon reverse engineering the MSPro database contents and
backup set format. Many bits and bytes are still not taken into
account.

THERE IS NO GUARANTEE THAT THIS PROGRAM WILL DO ANYTHING USEFUL FOR YOU.

=cut
