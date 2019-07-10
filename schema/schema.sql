PRAGMA user_version = 54;

BEGIN TRANSACTION;

CREATE TABLE android_metadata
  ( locale                     TEXT );

CREATE TABLE Songs
  ( Id                         INTEGER         PRIMARY KEY,
    Title                      VARCHAR(255),
    Difficulty                 INTEGER,
    Custom                     VARCHAR(255)    DEFAULT '',
    Custom2                    VARCHAR(255)    DEFAULT '',
    LastPage                   INTEGER,
    OrientationLock            INTEGER,
    Duration                   INTEGER,
    Stars                      INTEGER         DEFAULT 0,
    VerticalZoom               FLOAT           DEFAULT 1,
    SortTitle                  VARCHAR(255)    DEFAULT '',
    Sharpen                    INTEGER         DEFAULT 0,
    SharpenLevel               INTEGER         DEFAULT 4,
    CreationDate               INTEGER         DEFAULT 0,
    LastModified               INTEGER         DEFAULT 0,
    Keywords                   VARCHAR(255)    DEFAULT '',
    AutoStartAudio             INTEGER         DEFAULT 0,
    SongId                     INTEGER         DEFAULT 0 );

CREATE TABLE MIDI
  ( Id                         INTEGER         PRIMARY KEY,
    SongId                     INTEGER,
    CommandType                INTEGER,
    Cable                      INTEGER,
    Channel                    INTEGER,
    MSB                        INTEGER,
    LSB                        INTEGER,
    Value                      INTEGER,
    CustomField                INTEGER,
    SendOnLoad                 INTEGER,
    LoadOnRecv                 INTEGER,
    SendMSB                    INTEGER         DEFAULT 1,
    SendLSB                    INTEGER         DEFAULT 1,
    SendValue                  INTEGER         DEFAULT 1,
    InputPort                  VARCHAR(255)    DEFAULT '',
    OutputPort                 VARCHAR(255)    DEFAULT '',
    Label                      VARCHAR(255)    DEFAULT '' );

CREATE TABLE MidiSysex
  ( Id                         INTEGER         PRIMARY KEY,
    MidiId                     INTEGER,
    SongId                     INTEGER,
    SysexBytes                 BLOB );

CREATE TABLE SourceType
  ( Id                         INTEGER         PRIMARY KEY,
    Type                       VARCHAR(255),
    SortBy                     INTEGER         DEFAULT 1,
    Ascending                  INTEGER         DEFAULT 1,
    DateCreated                INTEGER         DEFAULT 1458673884582,
    LastModified               INTEGER         DEFAULT 1458673884582 );

CREATE TABLE SourceTypeSongs
  ( Id                         INTEGER         PRIMARY KEY,
    SourceTypeId               INTEGER,
    SongId                     INTEGER );

CREATE TABLE CustomGroup
  ( Id                         INTEGER         PRIMARY KEY,
    Name                       VARCHAR(255),
    SortBy                     INTEGER         DEFAULT 1,
    Ascending                  INTEGER         DEFAULT 1,
    DateCreated                INTEGER         DEFAULT 1458673884582,
    LastModified               INTEGER         DEFAULT 1458673884582 );

CREATE TABLE CustomGroupSongs
  ( Id                         INTEGER         PRIMARY KEY,
    GroupId                    INTEGER,
    SongId                     INTEGER );

CREATE TABLE Composer
  ( Id                         INTEGER         PRIMARY KEY,
    Name                       VARCHAR(255),
    SortBy                     INTEGER         DEFAULT 1,
    Ascending                  INTEGER         DEFAULT 1,
    DateCreated                INTEGER         DEFAULT 1458673884582,
    LastModified               INTEGER         DEFAULT 1458673884582 );

CREATE TABLE ComposerSongs
  ( Id                         INTEGER         PRIMARY KEY,
    ComposerId                 INTEGER,
    SongId                     INTEGER );

CREATE TABLE Files
  ( Id                         INTEGER         PRIMARY KEY,
    SongId                     INTEGER,
    Path                       VARCHAR(255),
    PageOrder                  VARCHAR(255),
    FileSize                   INTEGER,
    LastModified               INTEGER,
    Source                     INTEGER,
    Type                       INTEGER,
    Password                   VARCHAR(255)    DEFAULT '' );

CREATE TABLE Books
  ( Id                         INTEGER         PRIMARY KEY,
    Title                      VARCHAR(255),
    SortBy                     INTEGER         DEFAULT 1,
    Ascending                  INTEGER         DEFAULT 1,
    DateCreated                INTEGER         DEFAULT 1458673884582,
    LastModified               INTEGER         DEFAULT 1458673884582 );

CREATE TABLE BookSongs
  ( Id                         INTEGER         PRIMARY KEY,
    BookId                     INTEGER,
    SongId                     INTEGER );

CREATE TABLE Artists
  ( Id                         INTEGER         PRIMARY KEY,
    Name                       VARCHAR(255),
    SortBy                     INTEGER         DEFAULT 1,
    Ascending                  INTEGER         DEFAULT 1,
    DateCreated                INTEGER         DEFAULT 1458673884582,
    LastModified               INTEGER         DEFAULT 1458673884582 );

CREATE TABLE ArtistsSongs
  ( Id                         INTEGER         PRIMARY KEY,
    ArtistId                   INTEGER,
    SongId                     INTEGER );

CREATE TABLE Genres
  ( Id                         INTEGER         PRIMARY KEY,
    Type                       VARCHAR(255),
    SortBy                     INTEGER         DEFAULT 1,
    Ascending                  INTEGER         DEFAULT 1,
    DateCreated                INTEGER         DEFAULT 1458673884582,
    LastModified               INTEGER         DEFAULT 1458673884582 );

CREATE TABLE GenresSongs
  ( Id                         INTEGER         PRIMARY KEY,
    GenreId                    INTEGER,
    SongId                     INTEGER );

CREATE TABLE "Key"
  ( Id                         INTEGER         PRIMARY KEY,
    Name                       VARCHAR(255),
    SortBy                     INTEGER         DEFAULT 1,
    Ascending                  INTEGER         DEFAULT 1,
    DateCreated                INTEGER         DEFAULT 1458673884582,
    LastModified               INTEGER         DEFAULT 1458673884582 );

CREATE TABLE KeySongs
  ( Id                         INTEGER         PRIMARY KEY,
    KeyId                      INTEGER,
    SongId                     INTEGER );

CREATE TABLE Signature
  ( Id                         INTEGER         PRIMARY KEY,
    Name                       VARCHAR(255),
    SortBy                     INTEGER         DEFAULT 1,
    Ascending                  INTEGER         DEFAULT 1,
    DateCreated                INTEGER         DEFAULT 1458673884582,
    LastModified               INTEGER         DEFAULT 1458673884582 );

CREATE TABLE SignatureSongs
  ( Id                         INTEGER         PRIMARY KEY,
    SignatureId                INTEGER,
    SongId                     INTEGER );

CREATE TABLE Years
  ( Id                         INTEGER         PRIMARY KEY,
    Name                       VARCHAR(255),
    SortBy                     INTEGER         DEFAULT 1,
    Ascending                  INTEGER         DEFAULT 1,
    DateCreated                INTEGER         DEFAULT 1458673884582,
    LastModified               INTEGER         DEFAULT 1458673884582 );

CREATE TABLE YearsSongs
  ( Id                         INTEGER         PRIMARY KEY,
    YearId                     INTEGER,
    SongId                     INTEGER );

CREATE TABLE ZoomPerPage
  ( Id                         INTEGER         PRIMARY KEY,
    SongId                     INTEGER,
    Page                       INTEGER,
    Zoom                       FLOAT,
    PortPanX                   FLOAT,
    PortPanY                   FLOAT,
    LandZoom                   FLOAT,
    LandPanX                   FLOAT,
    LandPanY                   FLOAT,
    FirstHalfY                 INTEGER,
    SecondHalfY                INTEGER );

CREATE TABLE Crop
  ( Id                         INTEGER         PRIMARY KEY,
    SongId                     INTEGER,
    Page                       INTEGER,
    Left                       INTEGER,
    Top                        INTEGER,
    Right                      INTEGER,
    Bottom                     INTEGER,
    Rotation                   INTEGER );

CREATE TABLE AutoScroll
  ( Id                         INTEGER         PRIMARY KEY,
    SongId                     INTEGER,
    Behavior                   INTEGER,
    PauseDuration              INTEGER,
    Speed                      INTEGER,
    FixedDuration              INTEGER,
    ScrollPercent              INTEGER,
    ScrollOnLoad               INTEGER,
    TimeBeforeScroll           INTEGER );

CREATE TABLE MetronomeSettings
  ( Id                         INTEGER         PRIMARY KEY,
    SongId                     INTEGER,
    Sig1                       INTEGER,
    Sig2                       INTEGER,
    Subdivision                INTEGER,
    SoundFX                    INTEGER,
    AccentFirst                INTEGER,
    AutoStart                  INTEGER         DEFAULT 0,
    CountIn                    INTEGER         DEFAULT 0,
    NumberCount                INTEGER         DEFAULT 0,
    AutoTurn                   INTEGER         DEFAULT 0 );

CREATE TABLE MetronomeBeatsPerPage
  ( Id                         INTEGER         PRIMARY KEY,
    SongId                     INTEGER,
    Page                       INTEGER,
    BeatsPerPage               INTEGER );

CREATE TABLE Tempos
  ( Id                         INTEGER         PRIMARY KEY,
    SongId                     INTEGER,
    Tempo                      INTEGER,
    TempoIndex                 INTEGER );

CREATE TABLE AudioFiles
  ( Id                         INTEGER         PRIMARY KEY,
    SongId                     INTEGER,
    Title                      VARCHAR(255),
    File                       VARCHAR(255),
    FileSource                 INTEGER,
    StartPos                   INTEGER,
    EndPos                     INTEGER,
    FileSize                   INTEGER,
    LastModified               INTEGER,
    APosition                  INTEGER         DEFAULT -1,
    BPosition                  INTEGER         DEFAULT -1,
    ABEnabled                  INTEGER         DEFAULT 0,
    FullDuration               INTEGER,
    Volume                     FLOAT           DEFAULT 0.75,
    Artist                     VARCHAR(255)    DEFAULT '',
    PitchShift                 INTEGER         DEFAULT 0,
    TempoSpeed                 FLOAT           DEFAULT 1.0 );

CREATE TABLE Bookmarks
  ( Id                         INTEGER         PRIMARY KEY,
    SongId                     INTEGER,
    Name                       VARCHAR(255),
    PageNum                    INTEGER,
    ShowInLibrary              INTEGER,
    DateCreated                INTEGER         DEFAULT 1458673884582,
    LastModified               INTEGER         DEFAULT 1458673884582 );

CREATE TABLE Recent
  ( Id                         INTEGER         PRIMARY KEY,
    Song                       INTEGER,
    RecentType                 INTEGER         DEFAULT 0 );

CREATE TABLE Setlists
  ( Id                         INTEGER         PRIMARY KEY,
    Name                       VARCHAR(255),
    LastPage                   INTEGER,
    LastIndex                  INTEGER,
    SortBy                     INTEGER,
    Ascending                  INTEGER         DEFAULT 1,
    DateCreated                INTEGER         DEFAULT 1458673884582,
    LastModified               INTEGER         DEFAULT 1458673884582 );

CREATE TABLE SetlistSong
  ( Id                         INTEGER         PRIMARY KEY,
    SetlistId                  INTEGER,
    SongId                     INTEGER );

CREATE TABLE SetlistSeparators
  ( Id                         INTEGER         PRIMARY KEY,
    SetlistId                  INTEGER,
    SeparatorIndex             INTEGER,
    SeparatorText              VARCHAR(255),
    TextColor                  INTEGER,
    BackgroundColor            INTEGER,
    Popup                      VARCHAR(255) );

CREATE TABLE Collections
  ( Id                         INTEGER         PRIMARY KEY,
    Name                       VARCHAR(255),
    SortBy                     INTEGER         DEFAULT 1,
    Ascending                  INTEGER         DEFAULT 1,
    DateCreated                INTEGER         DEFAULT 1458673884582,
    LastModified               INTEGER         DEFAULT 1458673884582 );

CREATE TABLE CollectionSong
  ( Id                         INTEGER         PRIMARY KEY,
    CollectionId               INTEGER,
    SongId                     INTEGER );

CREATE TABLE Links
  ( Id                         INTEGER         PRIMARY KEY,
    SongId                     INTEGER,
    StartPointX                FLOAT,
    StartPointY                FLOAT,
    EndPointX                  FLOAT,
    EndPointY                  FLOAT,
    StartPage                  INTEGER,
    EndPage                    INTEGER,
    ZoomXStart                 FLOAT,
    ZoomYStart                 FLOAT,
    ZoomXEnd                   FLOAT,
    ZoomYEnd                   FLOAT,
    Radius                     INTEGER );

CREATE TABLE AnnotationsBase
  ( Id                         INTEGER         PRIMARY KEY,
    SongId                     INTEGER,
    Page                       INTEGER,
    Type                       INTEGER,
    GroupNum                   INTEGER,
    Alpha                      INTEGER,
    Zoom                       FLOAT,
    ZoomY                      FLOAT,
    Version                    INTEGER );

CREATE TABLE DrawAnnotations
  ( Id                         INTEGER         PRIMARY KEY,
    BaseId                     INTEGER,
    LineColor                  INTEGER,
    FillColor                  INTEGER,
    LineWidth                  INTEGER,
    DrawMode                   INTEGER,
    PenMode                    INTEGER,
    SmoothMode                 INTEGER );

CREATE TABLE StampAnnotations
  ( Id                         INTEGER         PRIMARY KEY,
    BaseId                     INTEGER,
    StampIndex                 INTEGER,
    CustomSymbol               VARCHAR(255),
    StampSize                  INTEGER );

CREATE TABLE TextboxAnnotations
  ( Id                         INTEGER         PRIMARY KEY,
    BaseId                     INTEGER,
    TextColor                  INTEGER,
    Text                       VARCHAR(255),
    FontFamily                 INTEGER,
    FontSize                   INTEGER,
    FontStyle                  INTEGER,
    FillColor                  INTEGER,
    BorderColor                INTEGER,
    TextAlign                  INTEGER,
    HasBorder                  INTEGER,
    BorderWidth                INTEGER,
    AutoSize                   INTEGER,
    Density                    FLOAT );

CREATE TABLE ExtraBitmaps
  ( Id                         INTEGER         PRIMARY KEY,
    Path                       VARCHAR(255) );

CREATE TABLE TextDisplaySettings
  ( Id                         INTEGER         PRIMARY KEY,
    FileId                     INTEGER,
    SongId                     INTEGER,
    FontFamily                 INTEGER,
    TitleSize                  INTEGER,
    MetaSize                   INTEGER,
    LyricsSize                 INTEGER,
    ChordsSize                 INTEGER,
    LineSpacing                FLOAT,
    ChordHighlight             INTEGER,
    ChordColor                 INTEGER,
    ChordStyle                 INTEGER,
    Transpose                  INTEGER,
    Capo                       INTEGER,
    NumberChords               INTEGER,
    ShowTitle                  INTEGER,
    ShowMeta                   INTEGER,
    ShowLyrics                 INTEGER,
    ShowChords                 INTEGER,
    EnableTranpose             INTEGER,
    EnableCapo                 INTEGER,
    ShowTabs                   INTEGER,
    Structure                  VARCHAR(255),
    "Key"                      INTEGER,
    Encoding                   INTEGER,
    TransposeKey               INTEGER         DEFAULT 0,
    TabSize                    INTEGER         DEFAULT 28,
    ChorusSize                 INTEGER         DEFAULT 28,
    RTL                        INTEGER         DEFAULT 0 );

CREATE TABLE SongNotes
  ( Id                         INTEGER         PRIMARY KEY,
    SongId                     INTEGER,
    ShowNotesOnLoad            INTEGER,
    DisplayTime                INTEGER,
    Notes                      VARCHAR(1024),
    TextSize                   INTEGER         DEFAULT 24,
    Alignment                  INTEGER         DEFAULT 0 );

CREATE TABLE SetlistSongNotes
  ( Id                         INTEGER         PRIMARY KEY,
    SetlistId                  INTEGER,
    SongId                     INTEGER,
    ShowNotesOnLoad            INTEGER,
    DisplayTime                INTEGER,
    Notes                      VARCHAR(1024),
    TextSize                   INTEGER         DEFAULT 24,
    Alignment                  INTEGER         DEFAULT 0 );

CREATE TABLE SongDisplaySettings
  ( Id                         INTEGER         PRIMARY KEY,
    SongId                     INTEGER,
    UseDefaultAdapter          INTEGER,
    PortraitAdapterType        INTEGER,
    LandscapeAdapterType       INTEGER,
    UseDefaultScaleMode        INTEGER,
    PortraitScaleMode          INTEGER,
    LandscapeScaleMode         INTEGER );

CREATE TABLE AnnotationPoints
  ( Id                         INTEGER         PRIMARY KEY,
    AnnotationId               INTEGER,
    Points                     BLOB,
    Count                      INTEGER );

CREATE TABLE BatchMIDI
  ( Id                         INTEGER         PRIMARY KEY,
    ParentId                   INTEGER,
    SongId                     INTEGER,
    CommandType                INTEGER,
    Cable                      INTEGER,
    Channel                    INTEGER,
    MSB                        INTEGER,
    LSB                        INTEGER,
    Value                      INTEGER,
    CustomField                INTEGER,
    SendMSB                    INTEGER         DEFAULT 1,
    SendLSB                    INTEGER         DEFAULT 1,
    SendValue                  INTEGER         DEFAULT 1,
    Label                      VARCHAR(255)    DEFAULT '' );

CREATE TABLE BatchMidiSysex
  ( Id                         INTEGER         PRIMARY KEY,
    MidiId                     INTEGER,
    SongId                     INTEGER,
    SysexBytes                 BLOB );

CREATE TABLE SmartButtons
  ( Id                         INTEGER         PRIMARY KEY,
    SongId                     INTEGER,
    Label                      VARCHAR(255),
    Page                       INTEGER,
    Action                     INTEGER,
    Value                      INTEGER,
    Value2                     INTEGER,
    XPos                       FLOAT,
    YPos                       FLOAT,
    ZoomX                      FLOAT,
    ZoomY                      FLOAT,
    File                       VARCHAR(255)    DEFAULT '',
    Size                       INTEGER         DEFAULT 1 );

CREATE TABLE SmartButtonMIDI
  ( Id                         INTEGER         PRIMARY KEY,
    ButtonId                   INTEGER,
    SongId                     INTEGER,
    CommandType                INTEGER,
    Cable                      INTEGER,
    Channel                    INTEGER,
    MSB                        INTEGER,
    LSB                        INTEGER,
    Value                      INTEGER,
    CustomField                INTEGER,
    SendMSB                    INTEGER         DEFAULT 1,
    SendLSB                    INTEGER         DEFAULT 1,
    SendValue                  INTEGER         DEFAULT 1,
    OutputPort                 VARCHAR(255)    DEFAULT '',
    Label                      VARCHAR(255)    DEFAULT '' );

CREATE TABLE SmartMidiSysex
  ( Id                         INTEGER         PRIMARY KEY,
    MidiId                     INTEGER,
    SongId                     INTEGER,
    SysexBytes                 BLOB );

CREATE TABLE MidiAction
  ( Id                         INTEGER         PRIMARY KEY,
    Action                     VARCHAR(255) );

CREATE TABLE BatchMidiAction
  ( Id                         INTEGER         PRIMARY KEY,
    ParentId                   INTEGER,
    CommandType                INTEGER,
    Cable                      INTEGER,
    Channel                    INTEGER,
    MSB                        INTEGER,
    LSB                        INTEGER,
    Value                      INTEGER,
    CustomField                INTEGER,
    SendMSB                    INTEGER         DEFAULT 1,
    SendLSB                    INTEGER         DEFAULT 1,
    SendValue                  INTEGER         DEFAULT 1,
    InputPort                  VARCHAR(255)    DEFAULT '',
    Label                      VARCHAR(255)    DEFAULT '' );

CREATE TABLE MidiActionSysex
  ( Id                         INTEGER         PRIMARY KEY,
    MidiId                     INTEGER,
    SysexBytes                 BLOB );

COMMIT;

