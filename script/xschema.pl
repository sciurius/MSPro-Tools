#!/usr/bin/perl -w

# Author          : Johan Vromans
# Created On      : Wed Jul 10 10:25:02 2019
# Last Modified By: Johan Vromans
# Last Modified On: Thu Jul 11 13:21:26 2019
# Update Count    : 92
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

# Package name.
my $my_package = 'MSProTools';
# Program name and version.
my ($my_name, $my_version) = qw( xschema 0.02 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $dbname;			# database
my $addfk;			# enable/disable foreign keys
my $verbose = 0;		# verbose processing
my $output;			# output file

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $trace = 0;			# trace (show process)
my $test = 0;			# test mode.

# Process command line options.
app_options();

# Post-processing.
$trace |= ($debug || $test);
$addfk = defined($addfk) ? $addfk ? 1 : -1 : 0;

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

use MobileSheetsPro::DB;

my $opts = { AddForeignKeys => $addfk };

if ( $dbname ) {
    db_open( $dbname, { NoVersionCheck => 2 } );

    print format_sql( "PRAGMA user_version = " . dbversion() . ";\n" );
    my $schema = dbh->selectall_arrayref( "SELECT name,sql FROM sqlite_master WHERE type = 'table'" );

    print format_sql( "PRAGMA foreign_keys=OFF;\n", $opts );
    print format_sql( "BEGIN TRANSACTION;\n", $opts );
    foreach ( @$schema ) {
	print format_sql($_->[1] . ";\n", $opts );
    }
    print format_sql( "COMMIT;\n", $opts );
}
else {
    my $line = "";
    while ( <> ) {
	$line .= $_ if /\S/;
	next unless /;$/;
	print format_sql( $line, $opts );
	$line = "";
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
	GetOptions('output=s'	=> \$output,
		   'db=s'	=> \$dbname,
		   'fk!'	=> \$addfk,
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

xschema - extract schema from (MobileSheetsPro) database

=head1 SYNOPSIS

xschema [options] [file ...]

 Options:
   --db=XXX		uses database XXX
   --fk			adds foreign keys
   --no-fk		removes foreign keys
   --ident		shows identification
   --help		shows a brief help message and exits
   --man                shows full documentation and exits
   --verbose		provides more verbose information

=head1 OPTIONS

=over 8

=item B<--db=>I<XXX>

Gets information from the named database.

If no database is specified, processes a schema from input.

=item B<--fk>

Adds foreign keys to the database schema.

=item B<--no-fk>

Removes foreign keys from the database schema.

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

Provides more verbose information.

=item I<file>

A previously produced schema file will de read if no B<--db> option
was supplied.

=back

=head1 DESCRIPTION

B<This program> will output a neatly and consistently formatted schema
for the database.

=cut
