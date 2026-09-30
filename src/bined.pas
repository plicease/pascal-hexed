(*============================================================================
| bined.pas
|   * allow the user to modify the current byte of the bit level
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$I-}
{$PACKRECORDS 1}

Unit BinEd;

INTERFACE

Uses
  Header;

{++PROCEDURES++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Procedure BinaryEditor(Var B:Byte; Var D:DataType);

{++FUNCTIONS+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

IMPLEMENTATION

Uses
  VCrt,VConvert,FUTIL,Cursor;

Var
  LastB:Byte;

{------------------------------------------------------------------------}

Procedure Display(B:Byte; CE:Integer; Y:Integer);
Var I,X:Integer;
Begin
  GotoXY(1,Y);
  For I:=8 DownTo 1 Do
    Begin
      If (I=CE) Then
        TextAttr:=ICFG.Highlight;
      If Boolean(B And Bit[I]) Then
        Write('1')
      Else
        Write('0');
      If (I=CE) Then
        TextAttr:=ICFG.Numbers;
    End;
  Write('  ');
  ClrEol;
  Write(Byte2Str(B),B:4,' ');
  If B<>Byte(^G) Then
    Write(Chr(B))
  Else
    Write(' ');
End;

{------------------------------------------------------------------------}

Procedure WriteCmdline(S:String;  X,Y:Byte);
Var Index:Integer;
Begin
  GotoXY(X,Y);
  TextAttr:=ICFG.Lolight;
  For Index:=1 To Length(S) Do
    Begin
      If ((S[Index]>='A') And (S[Index]<='Z')) Or (S[Index]='<')
        Or (S[Index]='>') Then
        TextAttr:=ICFG.Highlight;
      Write(S[Index]);
      If ((S[Index]>='A') And (S[Index]<='Z')) Or (S[Index]='<')
        Or (S[Index]='>') Then
        TextAttr:=ICFG.LoLight;
    End;
End;

{------------------------------------------------------------------------}

Procedure BinaryEditor(Var B:Byte; Var D:DataType);
Var
  CE:Integer;
  Temp:Byte;
  C:Char;
Begin
  HideCursor;
  Temp:=B;
  CE:=8;
  GotoXY(1,8);
  TextAttr:=ICFG.Lolight;
  ClrEOL;
  Window(1,6,80,7);
  ClrScr;
  WriteCMDLine('  <ENTER> save byte <ESC> exit ''<'' shift left ''>'' shift right',19,1);
  WriteCMDLine('  <SPACE> toggle Not And Or Xor Increment Decrement Swap',19,2);
  Window(1,6,19,7);
  Repeat
    Display(B,CE,1);
    Display(LastB,CE,2);
    C:=UpCase(Readkey);
    If (C='S') Then
      Begin
        B:=B XOr LastB;
        LastB:=B XOr LastB;
        B:=B XOr LastB;
      End;
    If (C='I') Then
      Inc(B);
    If (C='D') Then
      Dec(B);
    If (C='N') Then
      B:=NOT B;
    If (C='A') Then
      B:=B And LastB;
    If (C='O') Then
      B:=B Or LastB;
    If (C='X') Then
      B:=B XOr LastB;
    If (C=' ') Then
      If Boolean(B And Bit[CE]) Then
        B:=B And Not Bit[CE]
      Else
        B:=B XOR Bit[CE];
    If (C='<') Or (C=',') Then
      B:=B Shl 1;
    If (C='>') Or (C='.') Then
      B:=B Shr 1;
    If C=#0 Then
      Begin
        C:=Readkey;
        If (C=#75) Then
          CE:=CE+1;
        If (C=#77) Then
          CE:=CE-1;
        IF CE>8 Then
          CE:=8;
        If CE<1 Then
          CE:=1;
      End;
  Until (C=#13) Or (C=#27);
  If (C=#13) Then
    Begin
      LastB:=B;
      ToggleChanges(D);
    End
  Else
    B:=Temp;
  Window(1,6,80,7);
  ClrScr;
  TextAttr:=ICFG.LoLight;
  ClrScr;
  Window(1,1,80,25);
  ShowCursor;
End;

{======================================================================}

Begin
  LastB:=0;
End.
