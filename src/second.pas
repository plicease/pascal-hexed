(*============================================================================
| second.pas
|   allow viewing two files on just ONE screen.  wow.  just like windows
|   only FAST!  you know... it's too bad no one will ever actually read
|   these comments.
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$I-}
{$PACKRECORDS 1}

Unit Second;

INTERFACE

Uses
  Header,CHFILE;

{++PROCEDURES++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Procedure AdditionalFile(Var D:DataType; InpFileName:MaskString; Bo:Boolean);
Procedure SwapFiles(Var D:DataType);
Procedure SearchDiff(Var D:DataType);

{++FUNCTIONS+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

IMPLEMENTATION

Uses
  VCrt,UModify,ViewU,FUTIL,CFG,OutCRT,VConvert,Cursor;

{----------------------------------------------------------------------}

Procedure AdditionalFile(Var D:DataType; InpFileName:MaskString; Bo:Boolean);
Var count:Word; i:Word; Error:Integer;  b:byte;
Begin
  Window(1,6,80,9);
  TextAttr:=ICFG.Lolight;
  ClrScr;
  AutomaticTUse:=False;
  If (Secondary<>Nil) Then
    Begin
      Window(1,1,80,25);
      If Not ReallyDispose(Secondary^) Then
        Exit;
      Close(Secondary^.stream);
      Dispose(Secondary^.D);
      Dispose(Secondary);
      Secondary:=Nil;
      Exit;
    End;
  If MaxAvail<SizeOf(DataType)+SizeOf(binaryimage) Then
    Begin
      ErrorMsg('Not enough memory.');
      Exit;
    End;
  New(Secondary);
  Secondary^.BlockStart:=-1;
  Secondary^.BlockFinish:=-2;
  SvTextScreen;
  If NOT Bo Then
    Secondary^.FN:=ChooseFileName('HEXED version '+versionnumber,'Load Secondary File',InpFileName)
  Else
    Secondary^.FN:=InpFileName;
  FilePath:=Secondary^.FN;
  RsTextScreen;
  If (SizeOf(BinaryImage)>MaxAvail) Then
    Begin
      ErrorMsg('Not enough memory');
      Dispose(Secondary);
      Secondary:=Nil;
      Exit;
    End;
  If (Secondary^.FN='') Then
    With Secondary ^ Do
      Begin
        Secondary^.FN:='NONAME.DAT';
        Assign(Secondary^.stream,Secondary^.FN);
        ReWrite(Secondary^.stream,1);
        B:=$00;
        BlockWrite(Secondary^.stream,B,1);
        Close(Secondary^.stream);
      End;
  New(Secondary^.D);
  FillChar(Secondary^.D^,imagesize,0);
  Assign(Secondary^.stream,Secondary^.FN);
  Reset(Secondary^.stream,1);
  Error:=IOResult;
  If Error<>0 Then
    Begin
      ErrorMsg('Error opening file for read '+IntToStr(Error,0));
      Dispose(Secondary^.D);
      Dispose(Secondary);
      Secondary:=Nil;
      Exit;
    End;
  If FileSize(Secondary^.stream)>imagesize-1 Then
    BlockRead(Secondary^.stream,Secondary^.D^,imagesize-1,Error)
  Else
    BlockRead(Secondary^.stream,Secondary^.D^,FileSize(Secondary^.stream));
  Secondary^.offset:=0;
  Error:=IOResult;
  If Error<>0 Then
    Begin
      ErrorMsg('Error reading file '+IntToStr(Error,0));
      If Secondary^.D<>Nil Then
        Dispose(Secondary^.D);
      Dispose(Secondary);
      Secondary:=Nil;
      Exit;
    End;
  Secondary^.Changes:=False;
  Secondary^.EOF:=SizeOfFile(Secondary^.FN);
  Secondary^.X:=D.X;
  Secondary^.BlockStart:=-1;
  Secondary^.BlockStart:=-2;
  Relocate(Secondary^);
  CheckFileType(Secondary^);
End;

{------------------------------------------------------------------------}

Procedure SwapFiles(Var D:DataType);
Var tmp:DataType;  tmpImage:BinaryImagePointer;  F:File Of BinaryImage;
    Error:Integer;
Begin
  If Secondary=Nil Then
    Exit;
  tmp:=Secondary^;
  Secondary^:=D;
  D:=tmp;
  Assign(F,TempFileName('VIRT.000'));
  Rewrite(F);
  Error:=IOResult;
  If Error<>0 Then
    Exit;
  Write(F,Secondary^.D^);
  Error:=IOResult;
  If Error<>0 Then
    Begin
      ErrorMsg('Error writing temp file');
      CloseWindow;
      Exit;
    End;
  Close(F);

  Secondary^.D^:=D.D^;

  Reset(F);
  Error:=IOResult;
  If Error<>0 Then
    Begin
      ErrorMsg('Error opeing temp file');
      Exit;
    End;
  Read(F,D.D^);
  If Error<>0 Then
    Begin
      ErrorMsg('Error reading temp file');
      Exit;
    End;
  Close(F);

  Erase(F);

  Repeat Until IOResult=0;
  tmpImage:=Secondary^.D;
  Secondary^.D:=D.D;
  D.D:=tmpImage;
  WriteScreen(D);
End;

{------------------------------------------------------------------------}

Procedure SearchDiff(Var D:DataType);
Var
  SaveX,SaveOffset:LongInt;
  I:Word;
Begin
  If Secondary=Nil Then
    Exit;
  SaveSegment(D);
  SaveX:=D.X;
  SaveOffset:=D.Offset;
  D.offset:=D.X+D.offset;
  Secondary^.offset:=D.offset;
  D.X:=1;
  Secondary^.X:=1;

  OpenWindow(10,10,70,12,ICFG.MsgColor);
  GotoXY(1,1);
  Write('Comparing ',D.FN,' to ',Secondary^.FN);

  HideCursor;
  While (D.offset+D.X<D.EOF) And NOT KeyPressed Do
    Begin

      GotoXY(1,2);
      Writeln('checking segment at offset :',D.X+D.offset,'/',D.EOF);
      Write('$',Long2Str(D.X+D.offset),'/$',Long2Str(D.EOF));

      RestoreSegment(D);
      RestoreSegment(Secondary^);
      For I:=1 To imagesize Do
        If D.D^[I]<>Secondary^.D^[I] Then
          Begin
            D.X:=I;
            CloseWindow;
            ShowCursor;
            Exit;
          End;

      D.offset:=D.offset+imagesize-100;
      Secondary^.offset:=D.offset;
      D.X:=1;
      Secondary^.X:=1;

    End;

  CloseWindow;

  D.X:=SaveX;
  D.Offset:=SaveOffset;
  RestoreSegment(D);

  If KeyPressed Then
    Readkey;

  ShowCursor;

End;

{======================================================================}

End.
