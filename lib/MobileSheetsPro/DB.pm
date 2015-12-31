#! perl

use strict;
use warnings;
use Carp;

package MobileSheetsPro::DB;

use DBI;

our $VERSION = "0.03";

my $dbh;
my $trace = 0;

our @EXPORT= qw( dbh db_open db_ins db_upd db_insupd lookup
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

sub lookup {
    my ( $table, $name, $id ) = @_;
    my $sql = "SELECT $name FROM $table WHERE Id = ?";
    my $ret = $dbh->selectrow_arrayref( $sql, {}, $id );
    if ( defined $ret->[0] ) {
	info( "$sql => ?", $id, $ret->[0] ) if $trace;
	return $ret->[0];
    }
    return;
}

sub get__id {
    my ( $table, $name, $value ) = @_;
    my $sql = "SELECT Id FROM $table WHERE $name = ?";
    my $ret = $dbh->selectrow_arrayref( $sql, {}, $value );
    if ( defined $ret->[0] ) {
	info( "$sql => ?", $value, $ret->[0] ) if $trace;
	return $ret->[0];
    }
    my $t = get__nextid($table);
    $sql = "INSERT INTO $table (Id, Name) VALUES (?, ?)";
    info( $sql, $t, $value ) if $trace;
    $dbh->do( $sql, {}, $t, $value );
    return $t;
}

sub get__nextid {
    my ( $table ) = @_;
    my $ret = $dbh->selectrow_arrayref( "SELECT MAX(Id) FROM $table" );
    $ret->[0] //= 0;
    return $ret->[0] + 1 if $ret;
    undef;
}

sub db_ins {
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

sub db_upd {
    my ( $table, $fields, $values, $nkey ) = @_;
    $nkey ||= 1;

    die("db_upd(\"$table\") -- " .
	scalar(@$fields) . " fields, " . scalar(@$values) . " values\n" )
      unless @$fields == @$values;

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

sub db_insupd {
    my ( $table, $fields, $values, $nkey ) = @_;
    $nkey ||= 1;

    die("db_insupd(\"$table\") -- " .
	scalar(@$fields) . " fields, " . scalar(@$values) . " values\n" )
      unless @$fields == @$values;

    my $name = $fields->[0];
    my $id = $values->[0];
    my $sql = "SELECT Id FROM $table WHERE $name = ?";
    $sql .= " AND ".$fields->[$_]." = ?" for 1..$nkey-1;
    my $ret = $dbh->selectrow_arrayref( $sql,
					{},
					@{$values}[0..$nkey-1] );

    if ( defined $ret->[0] ) {
	$id = $ret->[0];
	splice( @$fields, 0, $nkey );
	splice( @$values, 0, $nkey );
	$sql = "UPDATE $table SET " .
	  join( ", ", map { "$_ = ?" } @$fields ) .
	    " WHERE Id = ?";
	info( $sql, @$values, $id ) if $trace;
	$dbh->do( $sql, {}, @$values, $id );
	return $id;
    }

    my $nextid = get__nextid($table);
    $sql = "INSERT INTO $table (Id," . join(",",@$fields) . ") ".
      " VALUES(?," . join(",",("?") x @$fields) . ")";
    info( $sql, $nextid, @$values ) if $trace;
    $dbh->do( $sql, {}, $nextid, @$values);

    return $nextid;
}

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

=head1 LICENSE

Copyright (C) 2015, Johan Vromans,

This module is free software. You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

1;
