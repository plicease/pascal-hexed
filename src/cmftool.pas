{ Free Pascal port: the Sound Blaster FM driver (SBFMDRV.COM, INT 80h)
  doesn't exist outside of DOS, so this unit keeps its interface but always
  reports that the driver is missing.  the original implementation is in
  the git history. }

{$PACKRECORDS 1}
UNIT CMFTool;
{** Unit - uses SBFMDRV.COM **}
INTERFACE
USES Dos;
TYPE
  CMFFileTyp = FILE;
  CMFDataTyp = Pointer;
  CMFHeader = RECORD
    CMFFileID         : ARRAY[0..3] OF CHAR;
    CMFVersion        : WORD;
    CMFInstrBlockOfs  : WORD;
    CMFMusicBlockOfs  : WORD;
    CMFTickPerBeat    : WORD;
    CMFClockTicksPS   : WORD;
    CMFFileTitleOfs   : WORD;
    CMFComposerOfs    : WORD;
    CMFMusicRemarkOfs : WORD;
    CMFChannelsUsed   : ARRAY[0..15] OF CHAR;
    CMFInstrNumber    : WORD;
    CMFBasicTempo     : WORD;
  END;
CONST
   CMFToolVersion       = 'v1.0';
VAR
   CMFStatusByte      : BYTE;
   CMFErrStat         : WORD;
   CMFDriverInstalled : BOOLEAN;
   CMFDriverIRQ       : WORD;
   CMFSongPaused      : BOOLEAN;
   OldExitProc        : Pointer;
PROCEDURE PrintCMFErrMessage;
FUNCTION  CMFGetSongBuffer(VAR CMFBuffer : Pointer; CMFFile : STRING):BOOLEAN;
FUNCTION  CMFFreeSongBuffer (VAR CMFBuffer : Pointer):BOOLEAN;
FUNCTION  CMFInitDriver : BOOLEAN;
FUNCTION  CMFGetVersion : WORD;
PROCEDURE CMFSetStatusByte;
FUNCTION  CMFSetInstruments(VAR CMFBuffer : Pointer):BOOLEAN;
FUNCTION  CMFSetSingleInstruments(VAR CMFInstrument:Pointer; No:WORD):BOOLEAN;
PROCEDURE CMFSetSysClock(Frequency : WORD);
PROCEDURE CMFSetDriverClock(Frequency : WORD);
PROCEDURE CMFSetTransposeOfs (Offset : INTEGER);
FUNCTION  CMFPlaySong(VAR CMFBuffer : Pointer) : BOOLEAN;
FUNCTION  CMFStopSong : BOOLEAN;
FUNCTION  CMFResetDriver:BOOLEAN;
FUNCTION  CMFPauseSong : BOOLEAN;
FUNCTION  CMFContinueSong : BOOLEAN;
PROCEDURE InitCMFSB;
IMPLEMENTATION

PROCEDURE PrintCMFErrMessage;
BEGIN
   CASE CMFErrStat OF
      100 : Write(' SBFMDRV sound driver not available ');
      END;
   END;

FUNCTION CMFGetSongBuffer(VAR CMFBuffer : Pointer; CMFFile : STRING):BOOLEAN;
BEGIN
   CMFBuffer := NIL;
   CMFErrStat := 100;
   CMFGetSongBuffer := FALSE;
   END;

FUNCTION CMFFreeSongBuffer (VAR CMFBuffer : Pointer):BOOLEAN;
BEGIN
   CMFBuffer := NIL;
   CMFFreeSongBuffer := TRUE;
   END;

FUNCTION CMFInitDriver : BOOLEAN;
BEGIN
   CMFErrStat := 100;
   CMFInitDriver := FALSE;
   END;

FUNCTION CMFGetVersion : WORD;
BEGIN
   CMFGetVersion := 0;
   END;

PROCEDURE CMFSetStatusByte;
BEGIN
   END;

FUNCTION CMFSetInstruments(VAR CMFBuffer : Pointer):BOOLEAN;
BEGIN
   CMFSetInstruments := FALSE;
   END;

FUNCTION CMFSetSingleInstruments(VAR CMFInstrument:Pointer; No:WORD):BOOLEAN;
BEGIN
   CMFSetSingleInstruments := FALSE;
   END;

PROCEDURE CMFSetSysClock(Frequency : WORD);
BEGIN
   END;

PROCEDURE CMFSetDriverClock(Frequency : WORD);
BEGIN
   END;

PROCEDURE CMFSetTransposeOfs (Offset : INTEGER);
BEGIN
   END;

FUNCTION CMFPlaySong(VAR CMFBuffer : Pointer) : BOOLEAN;
BEGIN
   CMFErrStat := 500;
   CMFPlaySong := FALSE;
   END;

FUNCTION CMFStopSong : BOOLEAN;
BEGIN
   CMFStopSong := TRUE;
   END;

FUNCTION CMFResetDriver:BOOLEAN;
BEGIN
   CMFResetDriver := FALSE;
   END;

FUNCTION CMFPauseSong : BOOLEAN;
BEGIN
   CMFPauseSong := FALSE;
   END;

FUNCTION CMFContinueSong : BOOLEAN;
BEGIN
   CMFContinueSong := FALSE;
   END;

PROCEDURE InitCMFSB;
BEGIN
   CMFDriverInstalled := CMFInitDriver;
   END;

BEGIN
   CMFDriverInstalled := FALSE;
   CMFSongPaused := FALSE;
   CMFErrStat := 100;
END.
