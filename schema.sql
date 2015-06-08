-- Schema for MobileSheetsPro database.
-- Version: MobileSheetsPro 1.0.7

PRAGMA foreign_keys=OFF;

-- To speed up loading.

BEGIN TRANSACTION;

-- Songs. The heart of it all.

CREATE TABLE Songs
 ( Id INTEGER PRIMARY KEY,
   Title VARCHAR(255),
   Difficulty INTEGER,
   Custom VARCHAR(255) DEFAULT '',
   Custom2 VARCHAR(255) DEFAULT '',
   LastPage INTEGER,
   OrientationLock INTEGER,
   Duration INTEGER,
   Stars INTEGER DEFAULT 0,
   VerticalZoom FLOAT DEFAULT 1,
   SortTitle VARCHAR(255) DEFAULT '',
   Sharpen INTEGER DEFAULT 0,
   SharpenLevel INTEGER DEFAULT 4,
   CreationDate INTEGER DEFAULT 0,
   LastModified INTEGER DEFAULT 0,
   Keywords VARCHAR(255) DEFAULT ''
 );

-- MIDI data.

CREATE TABLE MIDI
 ( Id INTEGER PRIMARY KEY,
   SongId INTEGER,
   CommandType INTEGER,
   Cable INTEGER,
   Channel INTEGER,
   MSB INTEGER,
   LSB INTEGER,
   Value INTEGER,
   CustomField INTEGER,
   SendOnLoad INTEGER,
   LoadOnRecv INTEGER
 );
CREATE INDEX midi_song_id_idx ON MIDI(SongId);

CREATE TABLE MidiSysex
 ( Id INTEGER PRIMARY KEY,
   MidiId INTEGER,
   SongId INTEGER,
   SysexBytes BLOB
 );
CREATE INDEX midi_sysex_midi_id_idx ON MidiSysex(MidiId);

-- Source types, or sources.
-- Table SourceTypeSongs maintains an N-N relationship with Songs.

CREATE TABLE SourceType
 ( Id INTEGER PRIMARY KEY,
   Type VARCHAR(255)
 );
INSERT INTO SourceType VALUES(1, 'Sheet Music');
INSERT INTO SourceType VALUES(2, 'Tab');
INSERT INTO SourceType VALUES(3, 'Lyrics');
INSERT INTO SourceType VALUES(4, 'Chords');
INSERT INTO SourceType VALUES(5, 'Lead Sheet');
INSERT INTO SourceType VALUES(6, 'Charts');

CREATE TABLE SourceTypeSongs
 ( Id INTEGER PRIMARY KEY,
   SourceTypeId INTEGER,
   SongId INTEGER
 );
CREATE INDEX scrtype_type_id_idx ON SourceTypeSongs(SourceTypeId);
CREATE INDEX srctype_song_id_idx ON SourceTypeSongs(SongId);

-- Custom groups.
-- Table CustomGroupSongs maintains an N-N relationship with Songs.

CREATE TABLE CustomGroup
 ( Id INTEGER PRIMARY KEY,
   Name VARCHAR(255)
 );

CREATE TABLE CustomGroupSongs
 ( Id INTEGER PRIMARY KEY,
   GroupId INTEGER,
   SongId INTEGER
 );
CREATE INDEX cgroup_group_id_idx ON CustomGroupSongs(GroupId);
CREATE INDEX cgroup_song_id_idx ON CustomGroupSongs(SongId);

-- Composers.
-- Table ComposerSongs maintains an N-N relationship with Songs.

CREATE TABLE Composer
 ( Id INTEGER PRIMARY KEY,
   Name VARCHAR(255)
 );

CREATE TABLE ComposerSongs
 ( Id INTEGER PRIMARY KEY,
   ComposerId INTEGER,
   SongId INTEGER
 );
CREATE INDEX composer_composer_id_idx ON ComposerSongs(ComposerId);

-- Files belonging to Songs.
-- Every song can have zero or more files associated, with some
-- restrictions.
-- Field SongId is a foreign key into Songs.

CREATE TABLE Files
 ( Id INTEGER PRIMARY KEY,
   SongId INTEGER,
   Path VARCHAR(255),
   PageOrder VARCHAR(255),
   FileSize INTEGER,
   LastModified INTEGER,
   Source INTEGER,
   Type INTEGER,
   Password VARCHAR(255) DEFAULT ''
 );
CREATE INDEX files_song_id_idx ON Files(SongId);

-- Albums. Books is the legacy name.
-- Table BookSongs maintains an N-N relationship with Songs.

CREATE TABLE Books
 ( Id INTEGER PRIMARY KEY,
   Title VARCHAR(255)
 );

CREATE TABLE BookSongs
 ( Id INTEGER PRIMARY KEY,
   BookId INTEGER,
   SongId INTEGER
 );
CREATE INDEX book_book_id_idx ON BookSongs(BookId);
CREATE INDEX book_song_id_idx ON BookSongs(SongId);

-- Artists.
-- Table ArtistsSongs maintains an N-N relationship with Songs.

CREATE TABLE Artists
 ( Id INTEGER PRIMARY KEY,
   Name VARCHAR(255)
 );

CREATE TABLE ArtistsSongs
 ( Id INTEGER PRIMARY KEY,
   ArtistId INTEGER,
   SongId INTEGER
 );
CREATE INDEX artist_artist_id_idx ON ArtistsSongs(ArtistId);
CREATE INDEX artist_song_id_idx ON ArtistsSongs(SongId);

-- Genres.
-- Table GenresSongs maintains an N-N relationship with Songs.

CREATE TABLE Genres
 ( Id INTEGER PRIMARY KEY,
   Type VARCHAR(255)
 );
INSERT INTO Genres VALUES( 1, 'Acapella');
INSERT INTO Genres VALUES( 2, 'Acoustic');
INSERT INTO Genres VALUES( 3, 'Alternative');
INSERT INTO Genres VALUES( 4, 'Ballad');
INSERT INTO Genres VALUES( 5, 'Big Band');
INSERT INTO Genres VALUES( 6, 'Bluegrass');
INSERT INTO Genres VALUES( 7, 'Blues');
INSERT INTO Genres VALUES( 8, 'Christmas');
INSERT INTO Genres VALUES( 9, 'Classical');
INSERT INTO Genres VALUES(10, 'Contemporary');
INSERT INTO Genres VALUES(11, 'Country');
INSERT INTO Genres VALUES(12, 'Dance');
INSERT INTO Genres VALUES(13, 'Death Metal');
INSERT INTO Genres VALUES(14, 'Disco');
INSERT INTO Genres VALUES(15, 'Folk');
INSERT INTO Genres VALUES(16, 'Hip Hop');
INSERT INTO Genres VALUES(17, 'Instrumental');
INSERT INTO Genres VALUES(18, 'Jazz');
INSERT INTO Genres VALUES(19, 'Mambo');
INSERT INTO Genres VALUES(20, 'Metal');
INSERT INTO Genres VALUES(21, 'Musicals');
INSERT INTO Genres VALUES(22, 'Oldies');
INSERT INTO Genres VALUES(23, 'Other');
INSERT INTO Genres VALUES(24, 'Pop');
INSERT INTO Genres VALUES(25, 'Punk');
INSERT INTO Genres VALUES(26, 'Rhythm and Blues');
INSERT INTO Genres VALUES(27, 'Ragtime');
INSERT INTO Genres VALUES(28, 'Rap');
INSERT INTO Genres VALUES(29, 'Rock');
INSERT INTO Genres VALUES(30, 'Soundtrack');
INSERT INTO Genres VALUES(31, 'Techno');
INSERT INTO Genres VALUES(32, 'Vocal');
INSERT INTO Genres VALUES(33, 'Waltz');
INSERT INTO Genres VALUES(34, 'Worship');

CREATE TABLE GenresSongs
 ( Id INTEGER PRIMARY KEY,
   GenreId INTEGER,
   SongId INTEGER
 );
CREATE INDEX genre_genre_id_idx ON GenresSongs(GenreId);
CREATE INDEX genre_song_id_idx ON GenresSongs(SongId);

-- Keys.
-- Table KeySongs maintains an N-N relationship with Songs.

CREATE TABLE Key
 ( Id INTEGER PRIMARY KEY,
   Name VARCHAR(255)
 );
INSERT INTO Key VALUES( 1, 'C');
INSERT INTO Key VALUES( 2, 'Cm');
INSERT INTO Key VALUES( 3, 'C#');
INSERT INTO Key VALUES( 4, 'C#m');
INSERT INTO Key VALUES( 5, 'Db');
INSERT INTO Key VALUES( 6, 'Dbm');
INSERT INTO Key VALUES( 7, 'D');
INSERT INTO Key VALUES( 8, 'Dm');
INSERT INTO Key VALUES( 9, 'D#');
INSERT INTO Key VALUES(10, 'D#m');
INSERT INTO Key VALUES(11, 'Eb');
INSERT INTO Key VALUES(12, 'Ebm');
INSERT INTO Key VALUES(13, 'E');
INSERT INTO Key VALUES(14, 'Em');
INSERT INTO Key VALUES(15, 'F');
INSERT INTO Key VALUES(16, 'Fm');
INSERT INTO Key VALUES(17, 'F#');
INSERT INTO Key VALUES(18, 'F#m');
INSERT INTO Key VALUES(19, 'Gb');
INSERT INTO Key VALUES(20, 'Gbm');
INSERT INTO Key VALUES(21, 'G');
INSERT INTO Key VALUES(22, 'Gm');
INSERT INTO Key VALUES(23, 'G#');
INSERT INTO Key VALUES(24, 'G#m');
INSERT INTO Key VALUES(25, 'Ab');
INSERT INTO Key VALUES(26, 'Abm');
INSERT INTO Key VALUES(27, 'A');
INSERT INTO Key VALUES(28, 'Am');
INSERT INTO Key VALUES(29, 'A#');
INSERT INTO Key VALUES(30, 'A#m');
INSERT INTO Key VALUES(31, 'Bb');
INSERT INTO Key VALUES(32, 'Bbm');
INSERT INTO Key VALUES(33, 'B');
INSERT INTO Key VALUES(34, 'Bm');

CREATE TABLE KeySongs
 ( Id INTEGER PRIMARY KEY,
   KeyId INTEGER,
   SongId INTEGER
 );
CREATE INDEX key_key_id_idx ON KeySongs(KeyId);
CREATE INDEX key_song_id_idx ON KeySongs(SongId);

-- Signatures.
-- Yes, the signature is arbitrary text, not just 4/4 or 6/8.
-- The real signature is defined in MetronomeSettings.
-- Table SignatureSongs maintains an N-N relationship with Songs.

CREATE TABLE Signature
 ( Id INTEGER PRIMARY KEY,
   Name VARCHAR(255)
 );

CREATE TABLE SignatureSongs
 ( Id INTEGER PRIMARY KEY,
   SignatureId INTEGER,
   SongId INTEGER
 );
CREATE INDEX sig_sig_id_idx ON SignatureSongs(SignatureId);
CREATE INDEX sig_song_id_idx ON SignatureSongs(SongId);

-- Years.
-- Table YearsSongs maintains an N-N relationship with Songs.

CREATE TABLE Years
 ( Id INTEGER PRIMARY KEY,
   Name VARCHAR(255)
 );

CREATE TABLE YearsSongs
 ( Id INTEGER PRIMARY KEY,
   YearId INTEGER,
   SongId INTEGER
 );
CREATE INDEX year_year_id_idx ON YearsSongs(YearId);
CREATE INDEX year_song_id_idx ON YearsSongs(SongId);

-- ZoomPerPage
-- Zoom and pan values for each page of each song, in portrait end
-- landscape variants.

CREATE TABLE ZoomPerPage
 ( Id INTEGER PRIMARY KEY,
   SongId INTEGER,
   Page INTEGER,
   Zoom FLOAT,
   PortPanX FLOAT,
   PortPanY FLOAT,
   LandZoom FLOAT,
   LandPanX FLOAT,
   LandPanY FLOAT,
   FirstHalfY INTEGER,
   SecondHalfY INTEGER
 );
CREATE INDEX zoom_song_id_idx ON ZoomPerPage(SongId);

-- Crop
-- Crop values for each page of each song.
-- SongId is a foreign key to table Songs.

CREATE TABLE Crop
 ( Id INTEGER PRIMARY KEY,
   SongId INTEGER,
   Page INTEGER,
   Left INTEGER,
   Top INTEGER,
   Right INTEGER,
   Bottom INTEGER,
   Rotation INTEGER
 );
CREATE INDEX crop_song_id_idx ON Crop(SongId);

-- AutoScroll
-- AutoScroll settings for each song.
-- SongId is a foreign key to table Songs.

CREATE TABLE AutoScroll
 ( Id INTEGER PRIMARY KEY,
   SongId INTEGER,
   Behavior INTEGER,
   PauseDuration INTEGER,
   Speed INTEGER,
   FixedDuration INTEGER,
   ScrollPercent INTEGER,
   ScrollOnLoad INTEGER,
   TimeBeforeScroll INTEGER
 );
CREATE INDEX auto_scroll_song_id_idx ON AutoScroll(SongId);

-- MetronomeSettings
-- MetronomeSettings settings for each song.
-- SongId is a foreign key to table Songs.

CREATE TABLE MetronomeSettings
 ( Id INTEGER PRIMARY KEY,
   SongId INTEGER,
   Sig1 INTEGER,		-- beats per measure
   Sig2 INTEGER,		-- beats type
				-- 0 = 1/4 quarter notes
				-- 1 = 1/8 eight notes
   Subdivision INTEGER,
   SoundFX INTEGER,
   AccentFirst INTEGER,
   AutoStart INTEGER DEFAULT 0,
   CountIn INTEGER DEFAULT 0,
   NumberCount INTEGER DEFAULT 0,
   AutoTurn INTEGER DEFAULT 0
 );
CREATE INDEX metronome_song_id_idx ON MetronomeSettings(SongId);

-- MetronomeBeatsPerPage
-- The number of metronome beats per page, for each song.
-- SongId is a foreign key to table Songs.

CREATE TABLE MetronomeBeatsPerPage
 ( Id INTEGER PRIMARY KEY,
   SongId INTEGER,
   Page INTEGER,
   BeatsPerPage INTEGER
 );
CREATE INDEX bpp_song_id_idx ON MetronomeBeatsPerPage(SongId);
CREATE INDEX bpp_page_idx ON MetronomeBeatsPerPage(Page);

-- Tempos
-- Tempo settings in beats per minutes. Songs can have multiple tempi
-- so Songs have a 1-N relation to Tempos. The TempoIndex determined
-- the order of the tempi for a song.
-- SongId is a foreign key to table Songs.

CREATE TABLE Tempos
 ( Id INTEGER PRIMARY KEY,
   SongId INTEGER,
   Tempo INTEGER,
   TempoIndex INTEGER
 );
CREATE INDEX tempo_song_id_idx ON Tempos(SongId);

-- AudioFiles
-- Associates audio files to songs.
-- SongId is a foreign key to table Songs.

CREATE TABLE AudioFiles
 ( Id INTEGER PRIMARY KEY,
   SongId INTEGER,
   Title VARCHAR(255),
   File VARCHAR(255),
   FileSource INTEGER,
   StartPos INTEGER,
   EndPos INTEGER,
   FileSize INTEGER,
   LastModified INTEGER,
   APosition INTEGER DEFAULT -1,
   BPosition INTEGER DEFAULT -1,
   ABEnabled INTEGER DEFAULT 0,
   FullDuration INTEGER,
   Volume FLOAT DEFAULT 0.75
 );
CREATE INDEX audio_song_id_idx ON AudioFiles(SongId);

-- ExtraData
-- SongId is a foreign key to table Songs.

CREATE TABLE ExtraData
 ( Id INTEGER PRIMARY KEY,
   SongId INTEGER,
   Notes VARCHAR(1024),
   Tag VARCHAR(255),
   AutoStartAudio INTEGER
 );

-- Bookmarks.
-- SongId is a foreign key to table Songs.

CREATE TABLE Bookmarks
 ( Id INTEGER PRIMARY KEY,
   SongId INTEGER,
   Name VARCHAR(255),
   PageNum INTEGER,
   ShowInLibrary INTEGER
 );
CREATE INDEX bookmark_song_id_idx ON Bookmarks(SongId);

-- Recents
-- Maintains a list of recently used songs.
-- Song is a foreign key to table Songs.

CREATE TABLE Recent
 ( Id INTEGER PRIMARY KEY,
   Song INTEGER,
   RecentType INTEGER DEFAULT 0
 );

-- Setlists
-- Table SetlistSong maintains an N-N relationship with Songs.

CREATE TABLE Setlists
 ( Id INTEGER PRIMARY KEY,
   Name VARCHAR(255),
   LastPage INTEGER,
   LastIndex INTEGER,
   SortBy INTEGER
 );

CREATE TABLE SetlistSong
 ( Id INTEGER PRIMARY KEY,
   SetlistId INTEGER,
   SongId INTEGER
 );
CREATE INDEX setlist_setlist_id_idx ON SetlistSong(SetlistId);
CREATE INDEX setlist_song_id_idx ON SetlistSong(SongId);

-- SetlistSeparators

CREATE TABLE SetlistSeparators
 ( Id INTEGER PRIMARY KEY,
   SetlistId INTEGER,
   SeparatorIndex INTEGER,
   SeparatorText VARCHAR(255),
   TextColor INTEGER,
   BackgroundColor INTEGER,
   Popup VARCHAR(255)
 );
CREATE INDEX set_sep_id_idx ON SetlistSeparators(SetlistId);

-- Collections
-- Table CollectionSong maintains an N-N relationship with Songs.

CREATE TABLE Collections
 ( Id INTEGER PRIMARY KEY,
   Name VARCHAR(255)
 );

CREATE TABLE CollectionSong
 ( Id INTEGER PRIMARY KEY,
   CollectionId INTEGER,
   SongId INTEGER
 );
CREATE INDEX col_col_id_idx ON CollectionSong(CollectionId);
CREATE INDEX col_song_id_idx ON CollectionSong(SongId);

-- Links
-- SongId is a foreign key to table Songs.

CREATE TABLE Links
 ( Id INTEGER PRIMARY KEY,
   SongId INTEGER,
   StartPointX FLOAT,
   StartPointY FLOAT,
   EndPointX FLOAT,
   EndPointY FLOAT,
   StartPage INTEGER,
   EndPage INTEGER,
   ZoomXStart FLOAT,
   ZoomYStart FLOAT,
   ZoomXEnd FLOAT,
   ZoomYEnd FLOAT,
   Radius INTEGER
 );
CREATE INDEX links_song_id_idx ON Links(SongId);

-- AnnotationsBase
-- This table associates annotations with pages in songs.
-- SongId is a foreign key to table Songs.

CREATE TABLE AnnotationsBase
 ( Id INTEGER PRIMARY KEY,
   SongId INTEGER,
   Page INTEGER,
   Type INTEGER,		-- type of annotation
				-- 0 = text
				-- 1 = draw
				-- 2 = highlight
   GroupNum INTEGER,
   Alpha INTEGER,		--   0 = transparent
   	 			--  80 = typical highlight
   	 			-- 255 = opaque
   Zoom FLOAT,
   ZoomY FLOAT,
   Version INTEGER
 );
CREATE INDEX ann_song_id_idx ON AnnotationsBase(SongId);

-- DrawAnnotations
-- This table has the settings for a draw annotation.
-- The parameters (e.g., the path) are in table AnnotationPath.
-- BaseId is a foreign key to table AnnotationsBase.

CREATE TABLE DrawAnnotations
 ( Id INTEGER PRIMARY KEY,
   BaseId INTEGER,
   LineColor INTEGER,
   FillColor INTEGER,
   LineWidth INTEGER,
   DrawMode INTEGER,		-- draw mode
   	    			-- 0 = line
   	    			-- 1 = rectangle
   	    			-- 2 = circle
   	    			-- 3 = freehand
   PenMode INTEGER,
   SmoothMode INTEGER
 );
CREATE INDEX draw_ann_id_idx ON DrawAnnotations(BaseId);

-- StampAnnotations
-- This table has the settings for a stamp annotation.
-- The parameters (e.g., the coordinates) are in table AnnotationPath.
-- BaseId is a foreign key to table AnnotationsBase.

CREATE TABLE StampAnnotations
 ( Id INTEGER PRIMARY KEY,
   BaseId INTEGER,
   StampIndex INTEGER,
   CustomSymbol VARCHAR(255),
   StampSize INTEGER
 );
CREATE INDEX stamp_ann_id_idx ON StampAnnotations(BaseId);

-- TextBoxAnnotations
-- This table has the settings for a (boxed) text annotation.
-- The parameters (e.g., the coordinates) are in table AnnotationPath.
-- BaseId is a foreign key to table AnnotationsBase.

CREATE TABLE TextboxAnnotations
 ( Id INTEGER PRIMARY KEY,
   BaseId INTEGER,
   TextColor INTEGER,
   Text VARCHAR(255),
   FontFamily INTEGER,
   FontSize INTEGER,
   FontStyle INTEGER,
   FillColor INTEGER,
   BorderColor INTEGER,
   TextAlign INTEGER,		-- 0 = left
   	     			-- 1 = center
   	     			-- 2 = right
   HasBorder INTEGER,
   BorderWidth INTEGER,
   AutoSize INTEGER,
   Density FLOAT
 );

-- AnnotationPath
-- This table holds the spatial arguments for the annotations.
-- E.g., for a rectangle, the first entry specifies the lower-left
-- point and the second entry the upper-right point of the rectangle.
-- For a circle, the first entry has the center, and PointX of the
-- second entry determines the radius (subtract PointX of the center).
-- For a line, starting and ending points.
-- For freehand drawing, its basically a series of points with some
-- obscure magic mixed in.
-- AnnotationId is a foreign key to table AnnotationsBase.

CREATE TABLE AnnotationPath
 ( Id INTEGER PRIMARY KEY,
   AnnotationId INTEGER,
   PointX FLOAT,
   PointY FLOAT
 );
CREATE INDEX ann_ann_id_idx ON AnnotationPath(AnnotationId);

-- ExtraBitmaps

CREATE TABLE ExtraBitmaps
 ( Id INTEGER PRIMARY KEY,
   Path VARCHAR(255)
 );

-- TextDisplaySettings
-- This table contains the display settings for ChordPro files.
-- SongId is a foreign key to table Songs.

CREATE TABLE TextDisplaySettings
 ( Id INTEGER PRIMARY KEY,
   FileId INTEGER,
   SongId INTEGER,
   FontFamily INTEGER,
   TitleSize INTEGER,
   MetaSize INTEGER,
   LyricsSize INTEGER,
   ChordsSize INTEGER,
   LineSpacing FLOAT,
   ChordHighlight INTEGER,
   ChordColor INTEGER,
   ChordStyle INTEGER,
   Transpose INTEGER,
   Capo INTEGER,
   NumberChords INTEGER,
   ShowTitle INTEGER,
   ShowMeta INTEGER,
   ShowLyrics INTEGER,
   ShowChords INTEGER,
   EnableTranpose INTEGER,
   EnableCapo INTEGER,
   ShowTabs INTEGER,
   Structure VARCHAR(255),	-- unused?
   Key INTEGER,
   Encoding INTEGER
 );
CREATE INDEX text_display_id_idx ON TextDisplaySettings(SongId);

-- Android specific.

CREATE TABLE android_metadata
 ( locale TEXT
 );
INSERT INTO "android_metadata" VALUES('en_US');

-- Finished loading.

COMMIT;
