{ Free Pascal port: the Sound Blaster voice driver (CT-VOICE.DRV) was
  loaded into memory and far called, which can't work outside of DOS, so
  this unit keeps its interface but always reports that the driver is
  missing.  the original implementation is in the git history. }

{$PACKRECORDS 1}
UNIT VOCTOOL;
{* Unit - uses CT-VOICE.DRV. *}
INTERFACE
TYPE
   VOCFileTyp = File;
CONST
   VOCToolVersion  = 'v1.5';
   VOCBreakEnd     = 0;
   VOCBreakNow     = 1;
VAR
   VOCStatusWord        : WORD;
   VOCErrStat           : WORD;
   VOCFileHeader        : STRING;
   VOCFileHeaderLength  : BYTE;
   VOCPaused            : BOOLEAN;
   VOCDriverInstalled   : BOOLEAN;
   VOCDriverVersion     : WORD;
   VOCPtrToDriver       : Pointer;
   OldExitProc          : Pointer;
PROCEDURE PrintVOCErrMessage;
FUNCTION  VOCGetBuffer(VAR VoiceBuff : Pointer; Voicefile : STRING):BOOLEAN;
FUNCTION  VOCFreeBuffer(VAR VoiceBuff : Pointer):BOOLEAN;
FUNCTION  VOCGetVersion:WORD;
PROCEDURE VOCSetPort(PortNumber : WORD);
PROCEDURE VOCSetIRQ(IRQNumber : WORD);
FUNCTION  VOCInitDriver:BOOLEAN;
PROCEDURE VOCDeInstallDriver;
PROCEDURE VOCSetSpeaker(OnOff:BOOLEAN);
PROCEDURE VOCOutput(BufferAddress : Pointer);
PROCEDURE VOCOutputLoop (BufferAddress : Pointer);
PROCEDURE VOCStop;
PROCEDURE VOCPause;
PROCEDURE VOCContinue;
PROCEDURE VOCBreakLoop(BreakMode : WORD);
PROCEDURE InitVocSB;
IMPLEMENTATION

PROCEDURE PrintVOCErrMessage;
BEGIN
   CASE VOCErrStat OF
      100 : Write(' CT-VOICE.DRV sound driver not available ');
      END;
   END;

FUNCTION VOCGetBuffer(VAR VoiceBuff : Pointer; Voicefile : STRING):BOOLEAN;
BEGIN
   VoiceBuff := NIL;
   VOCErrStat := 100;
   VOCGetBuffer := FALSE;
   END;

FUNCTION VOCFreeBuffer(VAR VoiceBuff : Pointer):BOOLEAN;
BEGIN
   VoiceBuff := NIL;
   VOCFreeBuffer := TRUE;
   END;

FUNCTION VOCGetVersion:WORD;
BEGIN
   VOCGetVersion := 0;
   END;

PROCEDURE VOCSetPort(PortNumber : WORD);
BEGIN
   END;

PROCEDURE VOCSetIRQ(IRQNumber : WORD);
BEGIN
   END;

FUNCTION VOCInitDriver:BOOLEAN;
BEGIN
   VOCErrStat := 100;
   VOCInitDriver := FALSE;
   END;

PROCEDURE VOCDeInstallDriver;
BEGIN
   END;

PROCEDURE VOCSetSpeaker(OnOff:BOOLEAN);
BEGIN
   END;

PROCEDURE VOCOutput(BufferAddress : Pointer);
BEGIN
   END;

PROCEDURE VOCOutputLoop (BufferAddress : Pointer);
BEGIN
   END;

PROCEDURE VOCStop;
BEGIN
   END;

PROCEDURE VOCPause;
BEGIN
   END;

PROCEDURE VOCContinue;
BEGIN
   END;

PROCEDURE VOCBreakLoop(BreakMode : WORD);
BEGIN
   END;

PROCEDURE InitVocSB;
BEGIN
   VOCDriverInstalled := VOCInitDriver;
   END;

BEGIN
   VOCDriverInstalled := FALSE;
   VOCPaused := FALSE;
   VOCErrStat := 100;
   VOCDriverVersion := 0;
   VOCPtrToDriver := NIL;
   VOCStatusWord := 0;
END.
