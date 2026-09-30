(*============================================================================
| gshift.pas
|   some kind of assembly function.  don't ask me, i only work here.
|   (it asked the BIOS for the shift key flags, now VCrt does.)
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$I-}
{$PACKRECORDS 1}

Unit GShift;

INTERFACE

Const
  KBRShift  =$01;
  KBLShift  =$02;
  KBCtrl    =$04;
  KBAlt     =$08;
  KBScroll  =$10;
  KBNum     =$20;
  KBCaps    =$40;
  KBInsert  =$80;

{++PROCEDURES++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Function GetShiftByte:Byte;

{++FUNCTIONS+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

IMPLEMENTATION

Uses
  VCrt;

{----------------------------------------------------------------------}

{ a terminal only tells us about shift keys along with a key press, so
  this is the state as of the last key, plus the insert toggle. }
Function GetShiftByte:Byte;
Begin
  GetShiftByte:=ShiftFlags;
End;

{======================================================================}

End.
