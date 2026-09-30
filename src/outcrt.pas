(*============================================================================
| outcrt.pas
|    output to the screen.  high level routines.
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$I-}
{$PACKRECORDS 1}

Unit OutCRT;

INTERFACE

Uses
  Header;

{++PROCEDURES++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Procedure WriteScreen(Var D:DataType);
Procedure WriteCharStrip(Var D:DataType; y:Byte);
Procedure ShowDataStrip(Var D:DataType;  y:Byte);
Procedure DisplayData(Var D:DataType;  hp:HelpPointer;  x:Byte);
Procedure ErrorMsg(S:String);
Procedure InsertSpaces(Var D:DataType;  Var hp:HelpPointer);
Procedure DefaultOutPut;

{++FUNCTIONS+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Function Path2File(S:String):String;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

IMPLEMENTATION

Uses
  VCrt,CFG,DOS,VConvert,ViewU,FUTIL,WTD,Res,Cursor;

{------------------------------------------------------------------------}

Function Path2File(S:String):String;
Var Dir:DirStr;  Name:NameStr;  Ext:ExtStr;
Begin
  FSplit(S,Dir,Name,Ext);
  {$IFDEF UNIX}
  Path2File:=Name+Ext;     {case matters here}
  {$ELSE}
  Path2File:=UpString(Name+Ext);
  {$ENDIF}
End;

{----------------------------------------------------------------------}

Procedure WriteScreen(Var D:DataType);
{This procedure writes the status bar (bottom line) and the info bar (just
 under the file lines) on to the screen }
Var
  FileType,Name:String;
  Room:Integer;
Begin
  FileType:=BinFileType[D.BFT];
  If D.BFT=14 Then
    FileType:=FileType+' '+ExeFileType[D.ED.Tp];
  {the status bar was laid out for 8.3 names; cut longer ones down (from
   the front) so it doesn't run off the end of the line}
  Name:=Path2File(D.FN);
  Room:=80-40-Length(' Editing file ""')-Length(' (*) ')-Length(FileType)-1;
  If Length(Name)>Room Then
    Name:='~'+Copy(Name,Length(Name)-Room+2,Room-1);
  If AltMode=StdMode Then
    Window(1,25,80,25)
  Else
    Window(1,Resolution,80,Resolution);
  TextAttr:=ICFG.StatusVer;
  ClrScr;
  GotoXY(2,25);
  Write(' HEXED version ',versionnumber,' by Graham THE Ollis.');
  GotoXY(40,25);
  TextAttr:=ICFG.StatusFN;
  Write(' Editing file "'+Name+'"');
  TextAttr:=ICFG.StatusSave;
  If D.changes Then
    Write(' (*) ')
  Else
    Write(' ( ) ');
  TextAttr:=ICFG.StatusVer;
  Write(FileType);
  GotoXY(1,1);
  Write(' ');
  Window(1,1,80,25);
  If AltMode<>StdMode Then
    Exit;
  GotoXY(1,5);
  TextAttr:=ICFG.StatusMid;
  Write('X:',(D.X+D.offset-1):DataOffSet,' $'+Long2Str((D.X+D.offset - 1))+' EOF:',D.EOF:DataOffSet,' $'+
    Long2Str(D.EOF)+ '  ');
  Write('Word:',PWord(@D.D^[D.X])^:6,' $'+Word2Str(PWord(@D.D^[D.X])^));
  ClrEol;
  GotoXY(77,WhereY);
  Case DefVarEd Of
    DefHex : Write('H');
    DefDec : Write('D');
  End;
  ClrEol;
End;

{------------------------------------------------------------------------}

Procedure WriteCharStrip(Var D:DataType; y:Byte);
Const
  StripSize1=12;
  StripSize2=14;
Var index:LongInt;  Answer:Array [-StripSize1..StripSize2] of Char;
Begin
  If (viewMode=1) Or (viewMode=2) Or (viewMode=4) Then
    Begin
      Writeln;
      Exit;
    End;
  for index:=-StripSize1 To StripSize2 Do
    If (index+D.X+D.offset>0) And (index+D.X+D.offset<=D.EOF) Then
      Answer[index]:=Chr(D.D^[index+D.X])
    Else
      Answer[index]:=' ';
  GotoXY(1,y+3);
  for index:=-StripSize1 To StripSize2 Do
    Begin
      TextAttr:=ICFG.Numbers;
      If D.X+D.offset+index=1 Then
        TextAttr:=ICFG.BOF_Color;
      If D.X+D.offset+index=D.EOF Then
        TextAttr:=ICFG.EOF_Color;
      If (D.X+D.offset+index>=D.BlockStart) And
         (D.X+D.offset+index<=D.BlockFinish) Then
        TextAttr:=ICFG.Block_Color;
      If index=0 Then
        TextAttr:=ICFG.Highlight;
      If (D.X+index+D.offset<=0) Or (D.X+index+D.offset>D.EOF) Then
        TextAttr:=ICFG.Lolight;
      If index=StripSize2 Then
        Begin
          If Byte(Answer[index])>32 Then
            Write(Answer[index],' ')
          Else
            Write('  ');
        End
      Else If Byte(Answer[index])>32 Then
        Write(Answer[index],'  ')
      Else
        Write('   ');
    End;
End;

{------------------------------------------------------------------------}

Procedure ShowDataStrip(Var D:DataType;  y:Byte);
Const
  StripSize1=12;
  StripSize2=14;
Var i,index:Longint;  X:Byte;
Begin
  X:=1;
  GotoXY(1,1);
  If (viewMode=0) Or (viewMode=1) Or (viewMode=4) Or (viewMode=5) Then
    for index:=D.X-StripSize1 To D.X+StripSize2 Do
      Begin
        TextAttr:=ICFG.Numbers;
        If index+D.offset=1 Then
          TextAttr:=ICFG.BOF_Color;
        If index+D.offset=D.EOF Then
          TextAttr:=ICFG.EOF_Color;
        If (index+D.offset>=D.BlockStart) And
           (index+D.offset<=D.BlockFinish) Then
          TextAttr:=ICFG.Block_Color;
        If index=D.X Then
          TextAttr:=ICFG.Highlight;
        GotoXY(X,Y+1);
        If (index+D.offset>0) And (index+d.offset<=D.EOF) Then
          Begin
            Write(D.D^[index]);
            If D.D^[index]<10 Then
              Write('  ')
            Else If D.D^[index]<100 Then
              Write(' ');
          End
        Else
          Begin
            TextAttr:=ICFG.LoLight;
            Write('   ');
          End;
        Inc(X,3);
      End;
  X:=1;
  If (viewMode=0) Or (viewMode=2) Or (viewMode=4) Or (viewMode=6) Then
    for index:=D.X-StripSize1 To D.X+StripSize2 Do
      Begin
        TextAttr:=ICFG.Numbers;
        If index+D.offset=1 Then
          TextAttr:=ICFG.BOF_Color;
        If index+D.offset=D.EOF Then
          TextAttr:=ICFG.EOF_Color;
        If (index+D.offset>=D.BlockStart) And
           (index+D.offset<=D.BlockFinish) Then
          TextAttr:=ICFG.Block_Color;
        If index=D.X Then
          TextAttr:=ICFG.Highlight;
        GotoXY(X,Y+2);
        If (index+D.offset>0) And (index+D.offset<=D.EOF) Then
          Write(Byte2Str(D.D^[index]),' ')
        Else
          Begin
            TextAttr:=ICFG.Lolight;
            Write('   ');
          End;
        X:=X+3;
      End;
  WriteCharStrip(D,y);
  GotoXY(37,y+4);
  TextAttr:=ICFG.Highlight;
  Write(#$18'  ');
End;

{------------------------------------------------------------------------}

Type
  WordPointer=^Word;

Procedure DisplayData(Var D:DataType;  hp:HelpPointer;  x:Byte);
Begin
  ShowDataStrip(D,x);
  If x<>0 Then
    Exit;
  GoToXY(1,5);
  TextAttr:=ICFG.StatusMid;
  GotoXY(3,WhereY);
  Write((D.X+D.offset-1):DataOffSet);
  GotoXY(WhereX+2,WhereY);
  Write(Long2Str(D.X+D.offset-1));
  GotoXY(WhereX+5,WhereY);
  Write((D.EOF-1):DataOffSet);
  GotoXY(WhereX+2,WhereY);
  Write(Long2Str(D.EOF-1));
  GotoXY(WhereX+7,WhereY);
  Write(WordPointer(@D.D^[D.X])^:6, ' $');
  Writeln(Word2Str(WordPointer(@D.D^[D.X])^));
End;

{------------------------------------------------------------------------}

Procedure ErrorMsg(S:String);
Begin
  OpenWindow(40-Length(S) div 2 -1,10,40+Length(S) div 2 +1,10,ICFG.Error);
  Write(' '+S);
  HideCursor;
  Pause;
  ShowCursor;
  CloseWindow;
End;

{------------------------------------------------------------------------}

Procedure InsertSpaces(Var D:DataType;  Var hp:HelpPointer);
Begin
  If viewMode=1 Then
    Begin
      GotoXY(1,2);
      ClrEol;
      GotoXY(1,3);
      ClrEol;
      If Secondary<>Nil Then
        Begin
          GotoXY(1,7);
          ClrEol;
          GotoXY(1,8);
          ClrEol;
        End;
    End;
  If viewMode=2 Then
    Begin
      GotoXY(1,1);
      ClrEol;
      GotoXY(1,3);
      ClrEol;
      If Secondary<>Nil Then
        Begin
          GotoXY(1,6);
          ClrEol;
          GotoXY(1,8);
          ClrEol;
        End;
    End;
  If viewMode=3 Then
    Begin
      GotoXY(1,1);
      ClrEol;
      GotoXY(1,2);
      ClrEol;
      If Secondary<>Nil Then
        Begin
          GotoXY(1,6);
          ClrEol;
          GotoXY(1,7);
          ClrEol;
        End;
    End;
  If viewMode=4 Then
    Begin
      GotoXY(1,3);
      ClrEol;
      If Secondary<>Nil Then
        Begin
          GotoXY(1,8);
          ClrEol;
        End;
    End;
  If viewMode=5 Then
    Begin
      GotoXY(1,2);
      ClrEol;
      If Secondary<>Nil Then
        Begin
          GotoXY(1,7);
          ClrEol;
        End;
    End;
  If viewMode=6 Then
    Begin
      GotoXY(1,1);
      ClrEol;
      If Secondary<>Nil Then
        Begin
          GotoXY(1,6);
          ClrEol;
        End;
    End;
  DefaultOutPut;
End;

{------------------------------------------------------------------------}

Procedure DefaultOutPut;
Begin
  Relocate(Data);
  If (Secondary<>Nil) Then
    Relocate(Secondary^);
  If (Secondary<>Nil) And Not Paused Then
    Begin
      Secondary^.X:=(Data.X+Data.offset)-Secondary^.offset;
      Relocate(Secondary^);
    End;
  DisplayData(Data,hp,0);
  If AutomaticTUse Then
    WriteTypeData(Data.D^[Data.X],Data);
  If (Secondary<>Nil) And (Secondary^.D<>Nil) Then
    DisplayData(Secondary^,hp,5);
  GotoXY(1,25);
End;

{======================================================================}

End.
