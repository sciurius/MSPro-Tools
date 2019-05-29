#! perl

# Author          : Johan Vromans
# Created On      : Sun May 26 09:39:06 2019
# Last Modified By: Johan Vromans
# Last Modified On: Wed May 29 08:20:30 2019
# Update Count    : 165
# Status          : Unknown, Use with caution!

package MobileSheetsPro::Sync;

=for doc

Server is MobileSheetsPro running on a tablet.

Client is MobileSheetsPro Companion running on a PC.

Server -> client (events)

       int4	 int, length of the event, exclusive
       data	 event data

       		 0001  CONNECTION_ACCEPTED_EVENT

		 0004  DATABASE_EVENT
		 ....  database data, bytes

		 0008  SONG_EVENT
		 ....  file data, bytes

		 0014  REQUEST_TABLET_VERSION
		 int4  server version as integer
		 nstr  string, package name (* NOT INCLUDED IN LENGTH *)

		 000f  TABLET_SETTINGS_EVENT
		 ....  settings data

		 0015  REQUEST_PC_VERSION

Client -> server (requests)

       int4	int, request type
       data	request data (var, opt)

       		0005   REQUEST_DISCONNECT

		0007   REQUEST_SONG_EVENT
		int4   song id
		       NOTE: Generates a series of SONG EVENTs,
		       one for each song file, ordered by id.

		000c   TRANSFER_SONG_FILES
		int4   number of files
		....   repeat for every file
		ndat   string, path name
		ndat   string, file data
		....   end repeat

       		0014   REQUEST_TABLET_VERSION

		0015   REQUEST_PC_VERSION
		int4   client version as integer, e.g. 20803

		001b   PING

		002d   REQUEST_SQL_COMMAND
		int4   number of commands
		....   repeat for every command
		int4   0 = Insert, 1 = Update, 2 = Delete
		data   tbd
		....   end repeat


=cut

use strict;
use warnings;

use constant DEFAULT_SEND_PORT	=> 16569;
use constant PC_VERSION		=> 20803;

# Message codes
use constant
  { CONNECTION_ACCEPTED_EVENT	 =>  1,
    DATABASE_EVENT	       	 =>  4,
    REQUEST_DISCONNECT		 =>  5,
    REQUEST_SONG_EVENT		 =>  7,
    SONG_EVENT			 =>  8,
    TRANSFER_SONG_FILES		 => 12,
    TABLET_SETTINGS_EVENT	 => 15,
    REQUEST_TABLET_VERSION	 => 20,
    REQUEST_PC_VERSION		 => 21,
    PING			 => 27,
    REQUEST_SQL_COMMAND		 => 45,
  };

use Encode;
use IO::Socket::IP;

# Init and setup.
sub connect {
    my ( $pkg, $peer, $opts ) = @_;
    my $self = bless { %$opts }, $pkg;

    warn("Opening comm port...\n");
    $self->{port} = IO::Socket::IP->new( PeerAddr => $peer,
					 PeerPort => DEFAULT_SEND_PORT,
					 Type     => SOCK_STREAM,
					 Proto    => "tcp" );
    die($!) unless $self->{port};
    warn("Connected to $peer\n");

    # Upon connection, the server sends a CONNECTION_ACCEPTED_EVENT.
    $self->readInt(4);
    $self->readInt(CONNECTION_ACCEPTED_EVENT);

    return $self unless $self->{savedb} || $self->{full};

    # Request tablet identification and stuff.
    $self->writeInt( REQUEST_TABLET_VERSION );

    # Response from MSPro.
    $self->readInt(8);
    $self->readInt( REQUEST_TABLET_VERSION );
    $self->readInt;		# int ver
    $self->readString;		# package

    $self->readInt(4);
    $self->readInt( REQUEST_PC_VERSION );

    # Send my (faked) version.
    $self->writeInt( REQUEST_PC_VERSION );
    $self->writeInt( PC_VERSION );

    # MSPro now sends the full settings...
    $self->readInt;		# length
    $self->readInt( TABLET_SETTINGS_EVENT );

    my $settings;
    $settings->{density} = $self->readDouble;

    $settings->{LibraryConfig} = {};
    for ( $settings->{LibraryConfig} ) {
	$_->{mCustomGroupName}	    	   = $self->readString;
	$_->{mSongTitleFormat}	    	   = $self->readString;
	$_->{mSongCaptionFormat}    	   = $self->readString;
	$_->{mSortIgnoreWords} = [];
	foreach my $w ( 1 .. $self->readInt ) {
	    push( @{ $_->{mSortIgnoreWords} }, $self->readString );
	}
	$_->{storageDir}	    	   = $self->readString;
	$_->{mEnableSortIgnore}	    	   = $self->readBoolean;
	$_->{mNormalizeCharacters}  	   = $self->readBoolean;
	$_->{mUseAggressiveCropping}	   = $self->readBoolean;
	$_->{mShowSimpleSongTitles} 	   = $self->readBoolean;
	$_->{mShowSongCount}	    	   = $self->readBoolean;
    }

    $settings->{storageConfig} = {};
    for ( $settings->{storageConfig} ) {
	$_->{mCreateSubdirectories}	   = $self->readBoolean;
	$self->readBoolean;	# Unused, used to be add unique Id to filenames
	$_->{mManageFiles}		   = $self->readBoolean;
    }

    $settings->{textConfig} = {};
    for ( $settings->{textConfig} ) {
	$_->{mWrapText}			   = $self->readBoolean;
	$_->{mUseMultipleColumns}	   = $self->readBoolean;
	$_->{mPlaceChordsAbove}		   = $self->readBoolean;
	$_->{mUseFieldsForSongs}	   = $self->readBoolean;
	$_->{mModulateCapoDown}		   = $self->readBoolean;
	$_->{mUseOutputDirectorives}	   = $self->readBoolean;
	$_->{mKeyDetection}		   = $self->readInt;
	$_->{mAutoSizeFont}		   = $self->readBoolean;
	$_->{mMaxAutoFontSize}		   = $self->readInt;
	$_->{mEncoding}			   = $self->readInt;
	$_->{mFontFamily}		   = $self->readInt;
	$_->{mTitleSize}		   = $self->readInt;
	$_->{mMetaSize}			   = $self->readInt;
	$_->{mLyricsSize}		   = $self->readInt;
	$_->{mChordsSize}		   = $self->readInt;
	$_->{mTabSize}			   = $self->readInt;
	$_->{mChorusSize}		   = $self->readInt;
	$_->{mChordHighlight}		   = $self->readInt;
	$_->{mChordColor}		   = $self->readInt;
	$_->{mChordStyle}		   = $self->readInt;
	$_->{mShowTitle}		   = $self->readBoolean;
	$_->{mShowMeta}			   = $self->readBoolean;
	$_->{mShowChords}		   = $self->readBoolean;
	$_->{mShowLyrics}		   = $self->readBoolean;
	$_->{mLineSpacing}		   = $self->readDouble;
	$_->{mSupportMultipleMidiChannels} = $self->readBoolean;
	$_->{mMidiDeviceType}		   = $self->readInt;
	$_->{mMidiChannel}		   = $self->readInt;
	$_->{mHideChordBrackets}	   = $self->readBoolean;
    }

    $self->{settings} = $settings;

    # Then it sends its database.
    $self->readDB;

    if ( $self->{debug} ) {
	require DDumper;
	DDumper($settings);
    }

    # Ok, success!
    return $self;

}

# Gracefully disconnect.
sub disconnect {
    my ( $self ) = @_;
    $self->writeInt( REQUEST_DISCONNECT ) unless $self->{linger};
    # Just close, leave, exit, ...
}

################ High Level ################

# Read the database.
sub readDB {
    my ( $self ) = @_;
    my $n = $self->readInt - 4;	      # db length
    my $msg = $self->readInt;	      # this is the database (4)
    die( "readDB: Got msg $msg, expected " . DATABASE_EVENT . "\n" )
      unless $msg == DATABASE_EVENT;

    my $data = $self->read($n);
    warn("DB: ", length($$data), " bytes\n") if $self->{debug};
    if ( $self->{savedb} ) {
	open( my $db, '>:raw', $self->{savedb} );
	unless ( $db ) {
	    warn( $self->{savedb} . ": $!\n" );
	    return;
	}
	print $db $$data;
	close($db);
    }
}

# Send files to MSPro.
sub sendFiles {
    my ( $self, @files ) = @_;
    return unless @files;
    $self->writeInt( TRANSFER_SONG_FILES );
    $self->writeInt(scalar(@files));
    foreach my $file ( @files ) {
	if ( UNIVERSAL::isa( $file, 'ARRAY' ) ) {
	    $self->_writeFile(@$file);
	}
	else {
	    $self->_writeFile($file);
	}
    }
}

################ Medium Level ################

# Keepalive messages. Send every 3 seconds.
# Not required for batch.
sub ping {
    my ( $self ) = @_;
    warn("> ping\n") if $self->{debug};
    $self->writeInt( PING );
}

# Write integer value in 4 byte network order.
sub writeInt {
    my ( $self, $val ) = @_;
    warn("> int $val\n") if $self->{debug};
    my $buf = pack( "N", $val );
    $self->write(\$buf);
}

# Read integer value in 4 byte network order.
sub readInt {
    my ( $self, $exp ) = @_;
    warn("? int\n") if $self->{debug};
    my $bufp = $self->read(4);
    my $val = unpack( "N", $$bufp );
    warn("< int $val [4]\n") if $self->{debug};
    die("readInt: got $val, want $exp\n") if defined $exp && $exp != $val;
    return $val;
}

# Read long value in 2*4 byte network order.
sub readLong {			# UNTESTED
    my ( $self ) = @_;
    warn("? long\n") if $self->{debug};
    my $bufp = $self->read(8);
    return unpack( "Q", $$bufp );
}

# Read double value.
sub readDouble {
    my ( $self ) = @_;
    warn("?double\n") if $self->{debug};
    my $bufp = $self->read(8);
    my $val = unpack( "d>", $$bufp );
    warn("< double $val [8]\n") if $self->{debug};
}

# Read a single byte.
sub readByte {
    my ( $self ) = @_;
    warn("? byte\n") if $self->{debug};
    my $bufp = $self->read(1);
    my $val = unpack( "C", $$bufp );
    warn("< byte $val [1]\n") if $self->{debug};
    return $val;
}

# Boolean is same as byte.
*readBoolean = \&readByte;

# Read a UTF string with 2-byte length prefix. Returns the perl string.
sub readString {
    my ( $self ) = @_;
    warn("? str\n") if $self->{debug};
    my $bufp = $self->read(2);
    my $l = unpack( "n", $$bufp );
    $bufp = $self->read($l);
    my $val = decode_utf8($$bufp);
    warn("< str \"$val\" [$l]\n") if $self->{debug};
    return $val;
}

# Write a (perl) string as UTF data and 2-byte length prefix.
sub writeString {
    my ( $self, $data ) = @_;
    $data = encode_utf8($data);
    my $l = length($data);
    warn("> str \"$data\" [$l]\n") if $self->{debug};
    my $buf = pack( "n", $l );
    $buf .= $data;
    $self->write(\$buf);
    return;
}

# Write raw data with 4-byte length prefix.
sub writeData {
    my ( $self, $data, $tag ) = @_;
    $tag = defined $tag ? "$tag " : "";
    my $l = length($data);
    warn("> data $tag"."[$l]\n") if $self->{debug};
    my $buf = pack("N", $l);
    $buf .= $data;
    $self->write(\$buf);
    return;
}

# (internal) Send data as file.
sub _writeFile {
    my ( $self, $file, $path, $data ) = @_;

    unless ( defined $data ) {
	open( my $fd, "<:raw", $file );
	unless ( $fd ) {
	    die("$file: $!");
	    next;
	}
	$data = do { local $/; <$fd> };
    }

    $self->writeData($path, $path);	# path
    $self->writeData($data, "content");	# content
}

################ Low Level ################

sub read {
    my ( $self, $nn ) = @_;
    my $buf = "";
    my $off = 0;
    while ( $off < $nn ) {
	my $n = sysread( $self->{port}, $buf, $nn, $off );
	die("$!") unless defined $n && $n > 0;
	$off += $n;
    }
    return \$buf;
}

sub write {
    my ( $self, $bufp ) = @_;
    my $nn = length($$bufp);
    my $off = 0;
    while ( $off < $nn ) {
	my $n = syswrite( $self->{port}, $$bufp, $nn, $off );
	die("$!") unless defined $n && $n > 0;
	$off += $n;
    }
    return $bufp;
}
