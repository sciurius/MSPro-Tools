#! perl

use strict;
use warnings;
use Carp;

package MobileSheetsPro::DB;

use DBI;

our $VERSION = "0.03";

my $dbh;
my $trace = 0;

our @EXPORT= qw( dbh db_open db_ins db_upd db_insupd db_insnodup
		 db_delall lookup
		 get_sourcetype get_genre get_collections get_key
		 get_tempo get_signature get_artist get_composer
		 get_encoding );

use base qw(Exporter);

sub db_open {
    my ( $dbname, $opts ) = @_;
    $opts ||= {};
    $trace = delete( $opts->{Trace} );
    Carp::croak("No database $dbname\n") unless -s $dbname;
    $opts->{sqlite_unicode} = 1;
    $dbh = DBI::->connect( "dbi:SQLite:dbname=$dbname", "", "", $opts );
}

sub dbh {
    $dbh;
}

my %sourcetype;
sub get_sourcetype {
    $sourcetype{$_[0]} //= get__id( "SourceType", "Type", $_[0] );
}

my %genre;
sub get_genre {
    $genre{$_[0]} //= get__id( "Genres", "Type", $_[0] );
}

my %collections;
sub get_collections {
    $collections{$_[0]} //= get__id( "Collections", "Name", $_[0] );
}

my %key;
sub get_key {
    $key{$_[0]} //= get__id( "Key", "Name", $_[0] );
}

my %tempo;
sub get_tempo {
    $tempo{$_[0]} //= get__id( "Tempos", "Name", $_[0] );
}

my %artist;
sub get_artist {
    $artist{$_[0]} //= get__id( "Artists", "Name", $_[0] );
}

my %composer;
sub get_composer {
    $composer{$_[0]} //= get__id( "Composer", "Name", $_[0] );
}

my %signature;
sub get_signature {
    $signature{$_[0]} //= get__id( "Signature", "Name", $_[0] );
}

sub get_encoding {
    for ( $_[0] ) {
	return 0 unless defined;
	return 2 if /^iso[-]?8859[.]?1$/i;
	return 0 if /^utf-?8$/i;
    }
    return 0;
}

sub lookup($$$) {
    my ( $table, $name, $id ) = @_;
    my $sql = "SELECT $name FROM $table WHERE Id = ?";
    my $ret = $dbh->selectrow_arrayref( $sql, {}, $id );
    if ( defined $ret->[0] ) {
	info( "$sql => ?", $id, $ret->[0] ) if $trace;
	return $ret->[0];
    }
    return;
}

sub get__id($$$) {
    my ( $table, $name, $value ) = @_;
    my $sql = "SELECT Id FROM $table WHERE $name = ?";
    my $ret = $dbh->selectrow_arrayref( $sql, {}, $value );
    if ( defined $ret->[0] ) {
	info( "$sql => ?", $value, $ret->[0] ) if $trace;
	return $ret->[0];
    }
    my $t = get__nextid($table);
    $sql = "INSERT INTO $table (Id, $name) VALUES (?, ?)";
    info( $sql, $t, $value ) if $trace;
    $dbh->do( $sql, {}, $t, $value );
    return $t;
}

sub get__nextid($) {
    my ( $table ) = @_;
    my $ret = $dbh->selectrow_arrayref( "SELECT MAX(Id) FROM $table" );
    $ret->[0] //= 0;
    return $ret->[0] + 1 if $ret;
    undef;
}

# db_ins: insert a new row in a table.
#
# $fields and $values must correspond.
# A new Id is automatically generated.
# Returns the new Id.

sub db_ins($$$) {
    my ( $table, $fields, $values ) = @_;

    die("db_ins(\"$table\") -- " .
	scalar(@$fields) . " fields, " . scalar(@$values) . " values\n" )
      unless @$fields == @$values;

    my $nextid = get__nextid($table);
    my $sql = "INSERT INTO $table (Id," . join(",",@$fields) . ") ".
      " VALUES(?," . join(",",("?") x @$fields) . ")";
    info( $sql, $nextid, @$values ) if $trace;
    $dbh->do( $sql, {}, $nextid, @$values);

    return $nextid;
}

# db_upd: update an existing row in a table.
#
# $fields and $values must correspond.
# The first $nkey (default: 1) $fields and $values form the key
# to look up the row. This row will be updated with the rest of
# $fields/$values.
# Returns the row Id.

sub db_upd($$$;$) {
    my ( $table, $fields, $values, $nkey ) = @_;
    $nkey ||= 1;

    die("db_upd(\"$table\") -- " .
	scalar(@$fields) . " fields, " . scalar(@$values) . " values\n" )
      unless @$fields == @$values;

    if ( $table eq "TextDisplaySettings" && $nkey == 2 ) {
	# The rows in this table seem to spring into existance.
	my %a;
	@a{ @$fields } = @$values;
	db_vfy_textdisplaysettings( $a{FileId}, $a{SongId} );
    }

    my @keys = splice( @$fields, 0, $nkey );
    my $sql = "UPDATE $table SET " .
      join( ", ", map { "$_ = ?" } @$fields ) .
	" WHERE $keys[0] = ?";
    $sql .= " AND ".$keys[$_]." = ?" for 1..$nkey-1;
    push( @$values, splice( @$values, 0, $nkey ) );
    info( $sql, @$values ) if $trace;
    if ( $dbh->do( $sql, {}, @$values ) < 1 ) {
	info( $sql, @$values ) unless $trace;
	Carp::croak("Record not found");
    }
}

# db_upd: update an existing row in a table or insert a new one.
#
# $fields and $values must correspond.
# The first $nkey (default: 1) $fields and $values form the key
# to look up the row.
# If a row is found, it will be updated with the rest of
# $fields/$values.
# Otherwise, a new row is inserted with all $fields/$values.
# Returns the row Id.

sub db_insupd($$$;$) {
    my ( $table, $fields, $values, $nkey ) = @_;
    $nkey ||= 1;

    die("db_insupd(\"$table\") -- " .
	scalar(@$fields) . " fields, " . scalar(@$values) . " values\n" )
      unless @$fields == @$values;

    my $id;
    eval { $id = db_upd( $table, $fields, $values, $nkey ) };
    return $id unless $@;
    die($@) unless $@ =~ /Record not found/;

    # Insert a new row.
    return db_ins( $table, $fields, $values );
}

# db_insnodup: insert a row in a table unless it exists.
#
# $fields and $values must correspond.
# The $fields and $values form the key to look up the row.
# If it is not found, it will be added.
# Returns the row Id.

sub db_insnodup($$$) {
    my ( $table, $fields, $values ) = @_;

    die("db_insnodup(\"$table\") -- " .
	scalar(@$fields) . " fields, " . scalar(@$values) . " values\n" )
      unless @$fields == @$values;

    my $sql = "SELECT Id FROM $table" .
	" WHERE " . join( " AND ", map { "$_ = ?" } @$fields );
    info( $sql, @$values ) if $trace;
    my $ret = $dbh->selectrow_arrayref( $sql, {}, @$values );
    if ( defined $ret->[0] ) {
	return $ret->[0];
    }

    return db_ins( $table, $fields, $values );
}

# db_delall: delete all rows that match.
#
# $fields and $values must correspond.
# The $fields and $values form the key to look up the rows to delete.
# Returns nothing sensible.

sub db_delall($$$) {
    my ( $table, $fields, $values ) = @_;

    die("db_delall(\"$table\") -- " .
	scalar(@$fields) . " fields, " . scalar(@$values) . " values\n" )
      unless @$fields == @$values;

    my $sql = "DELETE FROM $table" .
	" WHERE " . join( " AND ", map { "$_ = ?" } @$fields );
    info( $sql, @$values ) if $trace;
    $dbh->do( $sql, {}, @$values );
}

# info: tracing information for sql statements.
#
# The SQL placeholders are replaced by the values.

sub info {
    my ( $sql, @values ) = @_;
    foreach ( @values ) {
	my $t = $_;
	if ( defined $t ) {
	    $t = "'$t'" unless $t =~ /^-?\d[\d.]*$/;
	}
	else {
	    $t = "<undef>";
	}
	$sql =~ s/\?/$t/;
    }
    warn($sql, "\n");
}

# Structure info: Fields in TextDisplaySettings table.
# First three fields are Id, FileId and SongId.

sub textdisplayfields {
    qw( Capo
	ChordColor ChordHighlight ChordStyle ChordsSize
	ChorusSize
	EnableCapo EnableTranpose
	Encoding
	FontFamily Key LineSpacing
	LyricsSize MetaSize
	NumberChords
	ShowChords ShowLyrics ShowMeta ShowTabs ShowTitle
	Structure TabSize TitleSize Transpose TransposeKey );
}

sub db_vfy_textdisplaysettings {
    my ( $fileid, $songid ) = @_;
    my $sql = "SELECT Id FROM TextDisplaySettings WHERE FileId = ? AND SongId = ?";
    info( $sql, $fileid, $songid ) if $trace;
    my $ret = $dbh->selectall_arrayref( $sql, {}, $fileid, $songid );
    return if $ret && $ret->[0];
    db_ins( "TextDisplaySettings", [ qw( FileId SongId ), textdisplayfields() ],
	    [ $fileid, $songid,
	      # NOTE: Most of these 'defaults' are mine :) .
	      0,
	      0x000000 - 0x1000000, 0x00ff00 - 0x1000000, 1, 30,
	      28,
	      0, 0,
	      2,
	      0, 0, 1.2,
	      28, 30,
	      6,
	      1, 1, 1, 1, 1,
	      undef, 28, 37, 0, 0 ].
	    2 )

}

=head1 LICENSE

Copyright (C) 2015, 2016, Johan Vromans,

This module is free software. You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

1;
