#!/usr/bin/perl -w

# Author          : Johan Vromans
# Created On      : Sun May 26 09:39:06 2019
# Last Modified By: Johan Vromans
# Last Modified On: Mon May 27 14:12:03 2019
# Update Count    : 31
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

# Package name.
my $my_package = 'Sciurix';
# Program name and version.
my ($my_name, $my_version) = qw( sync 0.02 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $server = "glaxxy.squirrel.nl";
my $savedb;
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
foreach my $file ( @ARGV ) {
    next if -r -s $file;
    warn("$file: $!\n");
}
die("Not all files accessible\n") if $fail;

my $msp = MobileSheetsPro::Sync->connect
  ( $server, { debug => $debug, verbose => $verbose, trace => $trace,
	       savedb => $savedb } );

$msp->ping;

$msp->writeFiles( @ARGV );

$msp->disconnect;

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

    # Process options.
    if ( @ARGV > 0 ) {
	GetOptions( 'server=s'	=> \$server,
		    'savedb=s'	=> \$savedb,
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
   --savedb=XXX		saves the database unter the given name
   --ident		shows identification
   --help		shows a brief help message and exits
   --man                shows full documentation and exits
   --verbose		provides more verbose information

=head1 OPTIONS

=over 8

=item B<--server=>I<XXX>

The name or IP address of the server running MSPro.

=item B<--savedb=>I<XXX>

If specified, the MSPro database will be saved on the local system
under the given name.

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
