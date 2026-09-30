(*============================================================================
 |  HexEd -- Hexadecimal Editor version 1.60
 |  (c) Graham Ollis 1994, 1997
 |
 | This program was designed to view/edit binary files in hex, char and
 | decimal format all at the same time.  All the commands are documented in
 | a short text file HEXED.HLP which should be included in the same directory
 | as HEXED.EXE.  The help file can be viewed online using the up and down
 | keys to scroll.
 |
 | New feature as of v1.22: can edit/view files > one segment
 |
 | History:
 | Date       Author     Comment
 | ----       ------     -------
 | -- --- 94  G. Ollis	 created and developed program
 | 08 feb 97  G. Ollis   1.60
 |                       took out nast "incourage to register" mode thing
 |                       added support to the new unix style fragment (3.x)
 ===========================================================================*)

{$IFNDEF FPC}
{$N+,E+,G+,M 16384,0,350360}
{$ENDIF}
{$I-,R-}
(*============================================================================
 |  N+,E+ uses 80x87 co-processor (N+) if available for real type operations
 |        if 80x87 is not present then HEXED will emulate one internaly (E+)
 |  I-    turn off Turbo Pascal's checking of IO.  This lets me do my own,
 |        more friendly (although often produces fatal error in the same
 |        problems) IO checking
 |  R-    turns off range checking.
 |  G+    forces 80286 instructions.
 |  M     memory sizes, 16384 for stack size, 0 heap min 655360 heap max
 |        these are the defaults.  I have set heap max to 480360 so that
 |        I can load the digital voice driver.
|
|  Free Pascal: N, E, G and M are Turbo Pascal/DOS only.  Build with -Mtp
|  so Integer stays 16 bits.
 ===========================================================================*)

{$PACKRECORDS 1}

Program HexEdit;

Uses
     CFG,        {Read CFG file/check CFG settings}
     VCrt,        {do color/text/widows.  Basically this makes HEXED look nice}
     Dos,        {look for files}
     Ollis,      {Graphics Lib}
     GIF,        {Graphics Interchange Format and IMG file reproduction}
     ChFile,     {Function to choose a file from a list, or by typing the name}
     ViewU,      {view file Lib}
     Header,     {Constants, Types, Globals}
     FUtil,      {File Utilities}
     CNT,        {Contact Procedure}
     OUTCRT,     {Output functions/procedures for the VCrt}
     UModify,    {Routines to allow the user to modify words, bytes, etc.}
     LowInt,     {Low level functions accessed by user functions}
     VConvert,   {Convert Variable types (str --> int, etc.)}
     Help,       {Help Window}
     WTD,        {Write Type Data procedure}
     Second,     {Secondary File functions}
     Search,     {Search Functions}
     BinEd,      {Binary Editor}
     MouseIn,    {Mouse Interface}
     KeyIn,      {Keyboard Interface}
     Block,      {Block Commands}
     PrintU,     {Printer Functions}
     Center,     {Main Function}
     Math;       {FPU exception mask}

Begin
  {any 4/8/10 bytes of a file can be shown as a float; let the bad ones come
   out as Nan/Inf rather than bringing the program down}
  SetExceptionMask([exInvalidOp,exDenormalized,exZeroDivide,exOverflow,
                    exUnderflow,exPrecision]);
  Main;
End.
