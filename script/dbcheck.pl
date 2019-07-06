#!/usr/bin/perl -w

# Author          : Johan Vromans
# Created On      : Tue Jun 11 16:56:23 2019
# Last Modified By: Johan Vromans
# Last Modified On: Sat Jul  6 09:18:03 2019
# Update Count    : 70
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

# Package name.
my $my_package = 'MSProTools';
# Program name and version.
my ($my_name, $my_version) = qw( dbcheck 0.15 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $dbname = "mobilesheets.db";
my $verbose = 1;		# verbose processing
my $mail = 1;
my $fix = 0;

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

use MobileSheetsPro::DB;
use Encode;

db_open( $dbname, { NoVersionCheck => 2,
		    RaiseError => 1,
		    Trace => $trace } );

binmode( STDERR, ':utf8' );

my $sql;
my $did;
my $r;

#### SongId must match Song Id.

$did = 0;
$sql = "SELECT Id,SongId,Title FROM Songs WHERE Id != SongId";

$r = dbh->selectall_arrayref($sql);
foreach ( @$r ) {
    my ( $id, $songid, $title ) = @$_;
    add_msg( "=== Songs without matching SongIds\n\n" ) unless $did++;
    $songid //= "<?>";
    add_msg( sprintf("%5s [%5d: %s]\n", $songid, $id, $title ) );
}
add_msg("\n") if $did;

#### All files must reside under Partituren folder.

$did = 0;
$sql =
  "SELECT Files.Id,Path,Title, Files.SongId, Source".
  " FROM Files, Songs".
  " WHERE NOT Path like 'Partituren/%'".
  "  AND Files.SongId = Songs.Id";

$r = dbh->selectall_arrayref($sql);
foreach ( @$r ) {
    my ( $id, $path, $title, $songid, $source ) = @$_;
    add_msg( "=== Files outside Partituren area\n\n" ) unless $did++;
    $path ||= "<PlaceHolder>" if $source < 0;
    $path = "<?>" if $path eq "";
    add_msg( sprintf("%6d %s [%5d: %s]\n", $id, $path, $songid, $title ) );
}
add_msg("\n") if $did;

#### Check stale TextDisplaySettings entries.

$did = 0;
$sql =
  "SELECT TextDisplaySettings.Id,Songs.Id,TextDisplaySettings.FileId,Title".
  " FROM Songs,TextDisplaySettings".
  " WHERE Songs.Id = TextDisplaySettings.SongId".
  "  AND TextDisplaySettings.FileId NOT IN ( SELECT Id FROM Files )".
  " ORDER BY Songs.Id";

$r = dbh->selectall_arrayref($sql);
foreach ( @$r ) {
    my ( $id, $songid, $fileid, $title ) = @$_;
    add_msg( "=== ", scalar(@$r), " Stale entries in TextDisplaySettings\n\n" ) unless $did++;
    add_msg( sprintf("%6d [%5d: %s]\n", $fileid, $songid, $title ) );
    dbh->do( "DELETE FROM TextDisplaySettings WHERE Id = ?", {}, $id ) if $fix;
}
add_msg("\n") if $did;

#### Check unused artists.

unused( "Artists",
	"SELECT Id,Name FROM Artists".
	" WHERE Id NOT IN".
	"   ( SELECT ArtistId FROM ArtistsSongs )" );

#### Check unused albums.

unused( "Albums",
	"SELECT Id,Title FROM Books".
	" WHERE Id NOT IN".
	"   ( SELECT BookId FROM BookSongs )" );

#### Check unused key signatures.

unused( "Keys","SELECT Id,Name FROM Key".
	" WHERE id > 33".
	"  AND id NOT IN".
	"   ( SELECT KeyId FROM KeySongs )" );

#### Check unused time signatures.

unused( "Time Signatures",
	"SELECT Id,Name FROM Signature".
	" WHERE Id > 0".
	"  AND Id NOT IN".
	"   ( SELECT SignatureId FROM SignatureSongs )" );

send_msg();

################ Subroutines ################

sub unused {
    my ( $tag, $sql ) = @_;
    my $did = 0;
    $r = dbh->selectall_arrayref($sql);
    foreach ( @$r ) {
	my ( $id, $name ) = @$_;
	add_msg( "=== ".($fix ? "Fixed u":"U")."nused $tag\n\n" ) unless $did++;
	add_msg( sprintf("%3d: %s\n", $id, $name ) );
    }
    add_msg("\n") if $did;
    if ( $fix && $did ) {
	$sql =~ s/^SELECT .*? FROM/DELETE FROM/;
	dbh->do($sql);
    }
}

################ Subroutines ################

my $mh;
my $msg;

use Net::SMTP;

sub add_msg {
    unshift( @_, $msg ) if $msg;
    $msg = join('', @_ );
}

sub send_msg {
    return unless $msg;
    warn($msg) if $verbose;
    return unless $mail;

    # Connect to an SMTP server.
    my $smtp = Net::SMTP->new("smtp.squirrel.nl",
			      Debug => 0, Timeout => 30,
			      Hello => 'Ikke')
      or die "SMTP Connection Failed\n";
    my $sender = 'MSPro Watcher <nobody@squirrel.nl>';
    my $recipient = 'Johan Vromans <jvromans@squirrel.nl>';

    # sender's address here
    $smtp->mail($sender);

    # recipient"s address
    $smtp->to($recipient);

    # Start the mail
    $smtp->data();

    # Send the header.
    $smtp->datasend( "MIME-Version: 1.0\n" );
    $smtp->datasend( "Content-Type: text/plain; charset=\"UTF-8\" \n" );
    $smtp->datasend( "To: $recipient\n" );
    $smtp->datasend( "From: $sender\n" );
    $smtp->datasend( "Subject: MobileSheetsPro database inconsistencies\n" );
    $smtp->datasend( "Date: ", rfc822_gm(), "\n" );
    $smtp->datasend( "\n" );

    # Send the body.
    $smtp->datasend(encode_utf8($msg));

    # Finish sending the mail
    $smtp->dataend();

    # Close the SMTP connection
    $smtp->quit();
}

################ Subroutines ################

use Time::Local;

sub rfc822_local {
    my ( $self, $epoch ) = @_;
    $epoch //= time;
    my @time = localtime($epoch);

    use integer;

    my $tz_offset = (Time::Local::timegm(@time) - $epoch) / 60;
    my $tz = sprintf( '%s%02u%02u',
		      $tz_offset < 0 ? '-' : '+',
		      $tz_offset / 60, $tz_offset % 60 );

    my @month_names = qw(Jan Feb Mar Apr May Jun
                         Jul Aug Sep Oct Nov Dec);
    my @day_names = qw(Sun Mon Tue Wed Thu Fri Sat Sun);

    return sprintf( '%s, %02u %s %04u %02u:%02u:%02u %s',
		    $day_names[$time[6]], $time[3], $month_names[$time[4]],
		    $time[5] + 1900, $time[2], $time[1], $time[0], $tz);
}

sub rfc822_gm {
    my ( $epoch ) = @_;
    $epoch //= time;
    my @time = gmtime $epoch;

    my @month_names = qw(Jan Feb Mar Apr May Jun
                         Jul Aug Sep Oct Nov Dec);
    my @day_names = qw(Sun Mon Tue Wed Thu Fri Sat Sun);

    return sprintf( '%s, %02u %s %04u %02u:%02u:%02u +0000',
		    $day_names[$time[6]], $time[3], $month_names[$time[4]],
		    $time[5] + 1900, $time[2], $time[1], $time[0] );
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
	GetOptions('ident'	=> \$ident,
		   'db=s'	=> \$dbname,
		   'mail!'	=> \$mail,
		   'fix'	=> \$fix,
		   'verbose'	=> sub { $verbose++ },
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

dbcheck - check (and optioanlly fix) MSPro db inconsistencies

=head1 SYNOPSIS

flatten [options]

 Options:
   --db=XXX		the MSPro database (default mobilesheets.db)
   --fix		try fixing some inconsistencies
   --[no]mail           send a report
   --quiet              run quietly
   --ident		show identification
   --help		brief help message
   --man                full documentation
   --verbose		verbose information

=head1 OPTIONS

=over 8

=item B<--db=>I<XXX>

Specifies an alternative name for the MobileSheetsPro database.
Default is C<"mobilesheets.db">.

=item B<--fix>

Try to fix some of the inconsistencies.

=item B<--mail> B<--no-mail>

Send a report via email. Or not.
On by default.

Try to fix some of the inconsistencies.

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

More verbose information.

=back

=head1 DESCRIPTION

PDF documents are created for each file that has annotations. For
PDF sources the original document is included, so the new PDF
document contains the original plus the annotations. For other
source files, the PDF document will contain empty pages containing
the annotations.

Currently supported annotations:

- drawing annotations (line, rectangle, circle, free)

- text annotations, but no fancy font stuff

=head1 DISCLAIMER

This is 'work in progress' and 'works for me'.

Much is based upon reverse engineering the MSPro database contents and
backup set format. Many bits and bytes are still not taken into
account.

THERE IS NO GUARANTEE THAT THIS PROGRAM WILL DO ANYTHING USEFUL FOR YOU.

=cut
