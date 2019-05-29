#!/usr/bin/perl -w

# Author          : Johan Vromans
# Created On      : Sun May 26 09:39:06 2019
# Last Modified By: Johan Vromans
# Last Modified On: Wed May 29 08:33:18 2019
# Update Count    : 44
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

# Package name.
my $my_package = 'Sciurix';
# Program name and version.
my ($my_name, $my_version) = qw( mspsync 0.03 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $server = "glaxxy.squirrel.nl";
my $savedb;			# save the db locally
my $linger;			# do not disconnect
my $full;			# retrieve all settings and db
my $strip = 0;			# strip components off source path
my $path = "";			# prefix for dest path
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

use MobileSheetsPro::Sync;

my $fail;
my @args;
foreach my $file ( @ARGV ) {
    warn("$file: $!\n"), next unless -r -s $file;
    push( @args, $file ), next unless $strip || $path;
    my $dst = $file;
    if ( $strip ) {
	my @p = split( /\/+/, $file );
	splice( @p, 0, $strip );
	$dst = join( '/', @p );
    }
    if ( $path ) {
	$dst = $path . '/' . $dst;
	$dst =~ s;//+;;g;
    }
    push( @args, [ $file, $dst ] );
}
die("Not all files accessible\n") if $fail;

my $msp = MobileSheetsPro::Sync->connect
  ( $server, { debug => $debug, verbose => $verbose, trace => $trace,
	       savedb => $savedb, full => $full, linger => $linger } );

$msp->ping;

$msp->sendFiles( @args );

#$msp->disconnect;

exit 0;

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

    Getopt::Long::Configure( qw(bundling) );

    # Process options.
    if ( @ARGV > 0 ) {
	GetOptions( 'server=s'	=> \$server,
		    'savedb=s'	=> \$savedb,
		    'linger'	=> \$linger,
		    'full'	=> \$full,
		    'strip|p=i'	=> \$strip,
		    'path=s'	=> \$path,
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

sync - sync files with MobileSheetsPro

=head1 SYNOPSIS

sync [options] [file ...]

 Options:
   --server=XXX		the tablet running MSPro
   --full		retrieve all settings and db upon connect
   --savedb=XXX		saves the database unter the given name
   --path=XXX		prefix for destination file names
   --strip=N		strip components of source file names
   --linger		do not disconnect
   --ident		shows identification
   --help		shows a brief help message and exits
   --man                shows full documentation and exits
   --verbose		provides more verbose information

=head1 OPTIONS

=over 8

=item B<--server=>I<XXX>

The name or IP address of the server running MSPro.

=item B<--full>

Upon connect, retrieve all settings and database from the tablet.

=item B<--savedb=>I<XXX>

If specified, the MSPro database will be saved on the local system
under the given name. Implies B<--full>.

=item B<--path=>I<XXX>

The destination path on the tablet is formed by appending the source
file name to this path prefix. See also B<--strip>.

=item B<--strip=>I<N>

Strip I<N> components from the start of the source file name before
appending to the path prefix to form the destination path on the
tablet.

For example:

    mspsync --path=extra --strip=1 foo/bar.png

This will transfer local file C<foo/bar.png> to C<extra/bar.png> on
the tablet.

=item B<--linger>

Do not close down the communication with the tablet. A new sync can be
initiated by hitting the C<RETRY> button.

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

Provides more verbose information.

=item I<file>

The file(s) to process, if any.

=back

=head1 DESCRIPTION

B<This program> will set up a communication with the MSPro app
on a tablet and transfer files to the tablet.

On the tablet MSPro must be running and waiting for communication
(choose Sync to PC from the overflow menu).

=cut
