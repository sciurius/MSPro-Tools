#!/usr/bin/perl -w

# Author          : Johan Vromans
# Created On      : Wed Jul 10 10:25:02 2019
# Last Modified By: Johan Vromans
# Last Modified On: Wed Jul 10 13:54:09 2019
# Update Count    : 73
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

# Package name.
my $my_package = 'Sciurix';
# Program name and version.
my ($my_name, $my_version) = qw( xschema 0.01 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $dbname;				# database
my $indent = 4;
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

################ Presets ################

$indent = " " x $indent;
my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

my $dbh;

if ( $dbname ) {
    require DBI;
    my $opts = {};
    $opts->{sqlite_unicode} = 1;
    $dbh = DBI::->connect( "dbi:SQLite:dbname=$dbname", "", "", $opts );
    my $dbversion = $dbh->selectrow_array("pragma user_version");

    print fmtsql( "PRAGMA user_version = $dbversion;\n" );
    my $schema = $dbh->selectall_arrayref( "SELECT tbl_name,sql FROM sqlite_master WHERE type = 'table'" );

    print fmtsql( "BEGIN TRANSACTION;\n" );
    foreach ( @$schema ) {
	print fmtsql($_->[1] . ";\n");
    }
    print fmtsql( "COMMIT;\n" );
}
else {
    while ( <> ) {
	print fmtsql( $_ );
    }
}

################ Subroutines ################

sub id {
    my $name = shift;
    return '"' . $name . '"' if $name =~ /^(key)$/i;
    $name;
}

sub fmtsql {
    my ( $sql ) = @_;
    my $ret = "";
    if ( $sql =~ m/ ^
		    create \s+ table \s* (\S+) \s* \( (.*) \) \s*
		    ;
		  /xsi ) {
	my $table = $1;
	return if $table eq "sqlite_stat1";
	my $sql = $2;
	my @el;
	foreach my $el ( split( /,/, $sql ) ) {
	    $el =~ s/^\s+//s;
	    $el =~ s/\s+$//s;
	    if ( $el =~ m/ ^
			   foreign \s+ key \s*
			   \( (.*?) \) \s*
			   references \s+ (\S+) \s*
			   \( (.*?) \)
			 /xsi ) {
		push( @el,
		      sprintf("FOREIGN KEY%-15s REFERENCES %s%s",
			      "(" . id($1) . ")",
			      id($2),
			      "(". id($3) .")" ) );
	    }
	    elsif ( $el =~ m/ ^
			      (\S+) \s+ 
			      (\S+)
			      ( \s+ ( primary \s key ) )?
			      ( \s+ ( default ) \s+ (.*) )?
			    /ix ) {
		push( @el,
		      sprintf( "%-26s %-15s%s%s",
			       id($1),
			       uc($2),
			       defined($3) ? " ".uc($4) : '',
			       defined($5) ? " ".uc($6)." ".$7 : '',
			     ) );
		$el[-1] =~ s/\s+$//;
	    }
	    elsif ( $el =~ /^(\w+)$/ ) {
		push( @el, sprintf( "%-26s TEXT",
				    id($el) ) );
	    }
	    else {
		push( @el, $el . " //?" );
	    }
	}
	return join( "", "CREATE TABLE ",
		     id($table),
		     "\n",
		     "  ( ",
		     join( ",\n$indent", @el ),
		     " );\n\n" );
    }
    elsif ( $sql =~ /^(pragma|begin\s+transaction|commit)/si ) {
	return $sql."\n";
    }
    elsif ( $sql =~ /^(insert|create\s+index|analyze)/si ) {
	# print( "- ", $_ ) if $debug;
	return;
    }
    "SKIPPED: $sql";
}

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
	GetOptions('output=s'	=> \$output,
		   'db=s'	=> \$dbname,
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

sample - skeleton for GetOpt::Long and Pod::Usage

=head1 SYNOPSIS

sample [options] [file ...]

 Options:
   --ident		shows identification
   --help		shows a brief help message and exits
   --man                shows full documentation and exits
   --verbose		provides more verbose information

=head1 OPTIONS

=over 8

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

Provides more verbose information.

=item I<file>

The input file(s) to process, if any.

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do someting
useful with the contents thereof.

=cut
