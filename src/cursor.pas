(*============================================================================
| cursor.pas
|   routines to hide/show the cursor in text mode.  these used to be
|   BIOS calls, now they go through VCrt.
|   this module is not tightly connected to the rest of hexed.
|   you should be able to use it elsewhere if needed.
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$I-}
{$PACKRECORDS 1}

Unit Cursor;

INTERFACE

{++PROCEDURES++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Procedure HideCursor;
Procedure ShowCursor;
Procedure BigCursor;

{++FUNCTIONS+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

IMPLEMENTATION

Uses
  VCrt;

{----------------------------------------------------------------------------}

Procedure HideCursor;
Begin
  CursorHide;
End;

{----------------------------------------------------------------------------}

Procedure ShowCursor;
Begin
  CursorNormal;
End;

{----------------------------------------------------------------------------}

Procedure BigCursor;
Begin
  CursorBlock;
End;

{======================================================================}

End.
