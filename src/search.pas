(*============================================================================
| search.pas
|    search binary file for a particular string or binary array.
|    nice and fast from what i recall.
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$I-}
{$PACKRECORDS 1}

Unit Search;

INTERFACE

Uses
  Header;

{++PROCEDURES++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Procedure DoFindSearch(Var D:DataType);
Procedure FindArray(Var D:DataType);

{++FUNCTIONS+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

IMPLEMENTATION

Uses
  VCrt,VConvert,ViewU,FUTIL,CFG,Cursor,UModify;

{----------------------------------------------------------------------}

Procedure DisplayArray;
Var I:Integer;
Begin
  GotoXY(1,1);
  ClrEol;
  For I:=1 To NumElement Do
    Begin
      If (I=CurrentElement) Then
        TextAttr:=ICFG.MsgColor;
      Write(FArray[I]:4);
      If (I=CurrentElement) Then
        TextAttr:=ICFG.MsgLolight;
    End;
  Writeln;
  ClrEol;
  For I:=1 To NumElement Do
    Begin
      If (I=CurrentElement) Then
        TextAttr:=ICFG.MsgColor;
      Write('  ');
      Write(Byte2Str(FArray[I]));
      If (I=CurrentElement) Then
        TextAttr:=ICFG.MsgLolight;
    End;
End;

{------------------------------------------------------------------------}

Procedure ModifyByte(Var B:Byte);
Begin
  ClrScr;
  TextAttr:=ICFG.MsgColor;
  Writeln('Enter in new value for byte.');
  Write('> ');
  B:=StrToInt(StringEdit(IntToStr(B,0),4,NumSet));
End;

{------------------------------------------------------------------------}

Procedure wtCmdLine(S:String);
Var x:Byte;
Begin
  TextAttr:=ICFG.MsgLolight;
  For x:=1 To Length(S) Do
    Begin
      If ((S[x]>='A') And (S[x]<='Z')) Or (S[x]='<') Or (S[x]='>') Then
        TextAttr:=ICFG.MsgColor;
      Write(S[x]);
      If ((S[x]>='A') And (S[x]<='Z')) Or (S[x]='<') Or (S[x]='>') Then
        TextAttr:=ICFG.MsgLolight;
    End;
End;

{------------------------------------------------------------------------}

Function EnterInArray:Boolean;
Var C:Char;
Begin
  Repeat
    DisplayArray;
    Writeln;
    WtCmdLine(' < and > change array size LEFT and RIGHT to move current element');
    Writeln;
    WtCmdLine(' UP to modify byte <ENTER> to search <ESC> to exit');
    HideCursor;
    C:=Readkey;
    ShowCursor;
    If (C='<') Or (C=',') Then
      NumElement:=NumElement-1;
    If (C='>') Or (C='.') Then
      NumElement:=NumElement+1;
    If (NumElement<1) Then
      NumElement:=1;
    If (NumElement>ArrayLength) Then
      NumElement:=ArrayLength;
    If (CurrentElement>NumElement) Then
      CurrentElement:=NumElement;
    If (C=#0) Then
      Begin
        C:=Readkey;
        If (C=#75) Then
          CurrentElement:=CurrentElement-1;
        If (C=#77) Then
          CurrentElement:=CurrentElement+1;
        If (C=#72) Then
          ModifyByte(FArray[CurrentElement]);
        If (CurrentElement<1) Then
          CurrentElement:=1;
        If (CurrentElement>NumElement) Then
          CurrentElement:=NumElement;
      End;
  Until (C=#13) Or (C=#27);
  If C=#13 Then
    EnterInArray:=True
  Else
    EnterInArray:=False;
  CloseWindow;
End;

{------------------------------------------------------------------------}

Function ScanArrays(P1,P2:Pointer; Count:Byte):Boolean;
Var I:LongInt;
Begin
  ScanArrays:=True;
  For I:=1 To Count Do
    If PByte(PtrUInt(P1)+I)^<>PByte(PtrUInt(P2)+I)^ Then
      ScanArrays:=False;
End;

{------------------------------------------------------------------------}

Function ScanArrays2(Var D:DataType;  P2:Pointer; Count:Byte; i2:LongInt):Boolean;
Var I:LongInt;
Begin
  ScanArrays2:=True;
  For I:=1 To Count Do
    If GetFileByte(D.stream,I2+I)<>PByte(PtrUInt(P2)+I)^ Then
      ScanArrays2:=False;
End;

{------------------------------------------------------------------------}

Procedure DoFindSearchOld(Var D:DataType);
Var I:LongInt;
Begin
  IF D.EOF<imagesize-1 Then
    Begin
      For I:=D.X+D.offset+1 To D.EOF Do
        If (D.D^[I]=FArray[1]) And (ScanArrays(@D.D^[I],@FArray,NumElement-1)) Then
          Begin
            D.X:=I-D.offset;
            Exit;
          End;
    End
  Else
    Begin
      OpenWindow(10,10,70,10,ICFG.MsgColor);
      Write(D.EOF:30,' $',Long2Str(D.EOF));
      For I:=D.X+D.offset To D.EOF Do
        Begin
          If (I mod 100=0) Then
            Begin
              GotoXY(1,1);
              Write(I:11,' $',Long2Str(I));
              GotoXY(50,1);
              Write(((I*100) div D.EOF):3,'%');
            End;
          If (GetFileByte(D.stream,I)=FArray[1]) And (ScanArrays2(D,@FArray,NumElement-1,I)) Then
            Begin
              D.X:=I-D.offset+1;
              CloseWindow;
              Exit;
            End;
          If (KeyPressed) Then
            Begin
              CloseWindow;
              Exit;
            End;
        End;
      CloseWindow;
    End;
End;

{------------------------------------------------------------------------}

Procedure DoFindSearch(Var D:DataType);
Var
  Buff:binaryImagePointer;
  I:LongInt;
  Count,N,Sz,J:Word;
  B:Boolean;
Begin
  If (D.EOF<imageSize) Or (MaxAvail<700) Then
    Begin
      DoFindSearchOld(D);
      Exit;
    End;

  Sz:=65520;   {was MaxAvail, which a Word cut down to size under DOS}
  GetMem(Buff,Sz);

  Seek(D.Stream,D.X+D.Offset);
  I:=D.X+D.Offset;

  OpenWindow(10,10,70,10,ICFG.MsgColor);
  Write(D.EOF:30,' $',Long2Str(D.EOF),' NEW');

  HideCursor;
  While NOT EOF(D.stream) And NOT KeyPressed DO
    Begin
      BlockRead(D.Stream,Buff^,Sz,Count);
      GotoXY(1,1);
      Write(I:11,' $',Long2Str(I));
      GotoXY(50,1);
      Write(((I*100) div D.EOF):3,'%');

      For N:=1 To Count Do
        If Buff^[N]=FArray[1] Then
          Begin
            B:=True;
            For J:=1 To NumElement-1 Do
              If (N+J>Count) Or (Buff^[N+J]<>FArray[J+1]) Then
                B:=False;
            If B Then
              Begin
                D.X:=(I+N)-D.offset;
                FreeMem(Buff,Sz);
                ShowCursor;
                CloseWindow;
                Exit;
              End;
          End;

      {back up so a match across two reads isn't missed}
      If Not EOF(D.stream) And (Count>NumElement) Then
        Begin
          Inc(I,Count-(NumElement-1));
          Seek(D.stream,I);
        End
      Else
        Inc(I,count);
    End;
  ShowCursor;

  CloseWindow;

  FreeMem(Buff,Sz);
End;

{------------------------------------------------------------------------}

Procedure FindArray(Var D:DataType);
Begin
  OpenWindow(2,12,79,15,ICFG.MsgColor);
  If EnterInArray Then
    DoFindSearch(D);
End;

{======================================================================}

End.
