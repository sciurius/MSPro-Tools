#! perl

# Author          : Johan Vromans
# Created On      : Sun May 26 09:39:06 2019
# Last Modified By: Johan Vromans
# Last Modified On: Mon May 27 11:25:51 2019
# Update Count    : 115
# Status          : Unknown, Use with caution!

package MobileSheetsPro::Sync;

use strict;
use warnings;

use constant DEFAULT_SEND_PORT => 16569;
use constant PC_VERSION => 20803;

# Message codes
use constant
  { CONNECTION_ACCEPTED_EVENT	 =>  1,
    CONNECTION_DISCONNECT_EVENT	 =>  5,
    REQUEST_FILE_RETRIEVE	 =>  7,
    REQUEST_FILE_SEND		 => 12,
    TABLET_SETTINGS_EVENT	 => 15,
    REQUEST_TABLET_VERSION	 => 20,
    REQUEST_PC_VERSION		 => 21,
    PING			 => 27,
    REQUEST_SQL_COMMAND		 => 45,
  };

use Encode;
use IO::Socket::IP;

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
    $self->readInt == 4 || warn("Missing init1\n");;
    $self->readInt == CONNECTION_ACCEPTED_EVENT || warn("Missing init2\n");;

    $self->writeInt( REQUEST_TABLET_VERSION );
    $self->readInt;		# 8
    $self->readInt;		# REQUEST_TABLET_VERSION
    $self->readInt;		# int ver
    $self->readString;		# package
    $self->readInt;		# 4
    $self->readInt;		# REQUEST_PC_VERSION
    $self->writeInt( REQUEST_PC_VERSION );
    $self->writeInt( 20803);

    $self->readInt;		# length
    $self->readInt;		# TABLET_SETTINGS_EVENT

    my $settings;
    $settings->{density} = $self->readDouble;

    $settings->{LibraryConfig} = {};
    for ( $settings->{LibraryConfig} ) {
	$_->{mCustomGroupName} = $self->readString;
	$_->{mSongTitleFormat} = $self->readString;
	$_->{mSongCaptionFormat} = $self->readString;
	$_->{mSortIgnoreWords} = [];
	foreach my $w ( 1 .. $self->readInt ) {
	    push( @{ $_->{mSortIgnoreWords} }, $self->readString );
	}
	$_->{storageDir} = $self->readString;
	$_->{mEnableSortIgnore} = $self->readBoolean;
	$_->{mNormalizeCharacters} = $self->readBoolean;
	$_->{mUseAggressiveCropping} = $self->readBoolean;
	$_->{mShowSimpleSongTitles} = $self->readBoolean;
	$_->{mShowSongCount} = $self->readBoolean;
    }

    $settings->{storageConfig} = {};
    for ( $settings->{storageConfig} ) {
	$_->{mCreateSubdirectories} = $self->readBoolean;
	$self->readBoolean;	# Unused, used to be add unique Id to filenames
	$_->{mManageFiles} = $self->readBoolean;
    }

    $settings->{textConfig} = {};
    for ( $settings->{textConfig} ) {
	$_->{mWrapText} = $self->readBoolean;
	$_->{mUseMultipleColumns} = $self->readBoolean;
	$_->{mPlaceChordsAbove} = $self->readBoolean;
	$_->{mUseFieldsForSongs} = $self->readBoolean;
	$_->{mModulateCapoDown} = $self->readBoolean;
	$_->{mUseOutputDirectorives} = $self->readBoolean;
	$_->{mKeyDetection} = $self->readInt;
	$_->{mAutoSizeFont} = $self->readBoolean;
	$_->{mMaxAutoFontSize} = $self->readInt;
	$_->{mEncoding} = $self->readInt;
	$_->{mFontFamily} = $self->readInt;
	$_->{mTitleSize} = $self->readInt;
	$_->{mMetaSize} = $self->readInt;
	$_->{mLyricsSize} = $self->readInt;
	$_->{mChordsSize} = $self->readInt;
	$_->{mTabSize} = $self->readInt;
	$_->{mChorusSize} = $self->readInt;
	$_->{mChordHighlight} = $self->readInt;
	$_->{mChordColor} = $self->readInt;
	$_->{mChordStyle} = $self->readInt;
	$_->{mShowTitle} = $self->readBoolean;
	$_->{mShowMeta} = $self->readBoolean;
	$_->{mShowChords} = $self->readBoolean;
	$_->{mShowLyrics} = $self->readBoolean;
	$_->{mLineSpacing} = $self->readDouble;
	$_->{mSupportMultipleMidiChannels} = $self->readBoolean;
	$_->{mMidiDeviceType} = $self->readInt;
	$_->{mMidiChannel} = $self->readInt;
	$_->{mHideChordBrackets} = $self->readBoolean;
    }

    $self->readDB;

    use DDumper; DDumper($settings) if $self->{debug};
    return $self;

}

sub disconnect {
    my ( $self ) = @_;
    $self->writeInt( CONNECTION_DISCONNECT_EVENT );
}

sub ping {
    my ( $self ) = @_;
    warn("> ping\n") if $self->{debug};
    $self->writeInt( PING );
}

sub writeInt {
    my ( $self, $val ) = @_;
    warn("> int $val\n") if $self->{debug};
    die unless syswrite( $self->{port}, pack( "N", $val ), 4 ) == 4;
}

sub readInt {
    my ( $self ) = @_;
    warn("? int\n") if $self->{debug};
    my $buf = "";
    my $n = sysread( $self->{port}, $buf, 4 );
    die $! unless $n == 4;
    my $val = unpack( "N", $buf );
    warn("< int $val [$n]\n") if $self->{debug};
    return $val;
}

sub readLong {
    my ( $self ) = @_;
    warn("? long\n") if $self->{debug};
    my $val = $self->readInt;
    return ($val << 32) | $self->readInt;
}

*readDouble = \&readLong;

sub readByte {
    my ( $self ) = @_;
    warn("? byte\n") if $self->{debug};
    my $buf = "";
    my $n = sysread( $self->{port}, $buf, 1 );
    die $! unless $n == 1;
    my $val = unpack( "C", $buf );
    warn("< byte $val [$n]\n") if $self->{debug};
    return $val;
}

*readBoolean = \&readByte;

sub readRaw {
    my ( $self, $nn ) = @_;
    warn("? raw $nn\n") if $self->{debug};
    my $buf = "";
    my $off = 0;
    while ( $off < $nn ) {
	my $n = sysread( $self->{port}, $buf, $nn, $off );
	die("$!") unless defined $n && $n >= 0;
	$off += $n;
    }
    return \$buf;
}

sub readString {
    my ( $self ) = @_;
    warn("? str\n") if $self->{debug};
    my $buf = "";
    my $n = sysread( $self->{port}, $buf, 2 );
    die($!) unless $n == 2;
    my $l = unpack( "n", $buf );
    $buf = "";
    $n = sysread( $self->{port}, $buf, $l );
    die($!) unless $n == $l;
    my $val = decode_utf8($buf);
    warn("< str \"$val\" [$l]\n") if $self->{debug};
    return $val;
}


sub readDB {
    my ( $self ) = @_;
    my $n = $self->readInt - 4;	      # db length
    $self->readInt;		      # this is the database (4)

    my $data = $self->readRaw($n);
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

sub writeString {
    my ( $self, $data ) = @_;
    $data = encode_utf8($data);
    my $l = length($data);
    warn("> str \"$data\" [$l]\n") if $self->{debug};
    my $buf = pack("n", $l);
    $l += length($buf);
    $buf .= $data;
    my $n = syswrite( $self->{port}, $buf, $l );
    die($!) unless $n == $l;
    return;
}

sub writeData {
    my ( $self, $data ) = @_;
    my $l = length($data);
    warn("> data [$l]\n") if $self->{debug};
    my $buf = pack("N", $l);
    $l += length($buf);
    $buf .= $data;
    my $n = syswrite( $self->{port}, $buf, $l );
    die($!) unless $n == $l;
    return;
}

sub writeFiles {
    my ( $self, @files ) = @_;
    $self->writeInt(12);		# send files
    $self->writeInt(scalar(@files));
    foreach my $file ( @files ) {
	$self->_writeFile($file);
    }
}

sub _writeFile {
    my ( $self, $file, $data ) = @_;

    unless ( defined $data ) {
	open( my $fd, "<:raw", $file );
	unless ( $fd ) {
	    die("$file: $!");
	    next;
	}
	$data = do { local $/; <$fd> };
    }

    $self->writeData($file);	# path
    $self->writeData($data);	# content
}
