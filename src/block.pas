(*============================================================================
| block.pas
|   allow the user to do block commands.  that is mark portions for movement
|   deletion, copying, etc.
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$I-}
{$PACKRECORDS 1}

Unit Block;

INTERFACE

Uses
  Header;

{++PROCEDURES++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Procedure XTract(Var D:DataType);
Procedure CopyBlock(Var Dt:DataType);
Procedure MoveBlock(Var D:DataType);
Procedure WriteBlock(Var D:DataType);
Procedure ReadBlock(Var D:DataType);
Procedure DeleteBlock(Var D:DataType;  X:LongInt; Size:Byte);

{++FUNCTIONS+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

IMPLEMENTATION

Uses
  ViewU,CFG,VCrt,FUTIL,LowInt,VConvert,UModify,OutCrt;

{------------------------------------------------------------------------}

Procedure DeleteBlock(Var D:DataType;  X:LongInt; Size:Byte);
Var I:LongInt;   count,wtn:Word;
Begin
  SaveSegment(D);
  OpenWindow(15,10,65,10,ICFG.MsgColor);
  Write(0:DataOffset,' $',Long2Str(0),' ',D.EOF:DataOffset,' $',
        Long2Str(D.EOF));
  I:=0;
  While (X+size+I*imagesize-1<FileSize(D.stream)) Do
    Begin
      GotoXY(1,1);
      Write(X+size+I*imagesize-1:DataOffset,' $',
            Long2Str(X+size+I*imagesize-1),' ',
            FileSize(D.stream):DataOffset,' $',Long2Str(FileSize(D.stream)));
      Seek(D.stream,X+size+I*imagesize-1);
      If IOResult=0 Then
        Begin
          BlockRead(D.stream,D.D^,imagesize,count);
          Seek(D.stream,X+I*imagesize-1);
          BlockWrite(D.stream,D.D^,count,wtn);
          If count<>wtn Then
            Begin
              CloseWindow;
              ErrorMsg('Error, bytes read<>bytes written DeleteBloc()');
              RestoreSegment(D);
              Exit;
            End;
        End;
      I:=I+1;
    End;
  Seek(D.stream,D.EOF-size);
  Truncate(D.stream);
  D.EOF:=FileSize(D.stream);
  CloseWindow;
  RestoreSegment(D);
End;

{----------------------------------------------------------------------}

Procedure XTract(Var D:DataType);
{copy a number of bytes from the main file in to the aditional file
 overwrites.}
Var numxt:Word;  l:LongInt;  S:String;
Begin
  If (Secondary=NIL) OR (Secondary^.D=NIL) Then
    Exit;
  OpenWindow(20,10,60,11,ICFG.MsgColor);
  Writeln('Enter Number of bytes to extract.');
  Write('> ');
  L:=StrToInt(StringEdit('0',5,NumSet));
  numxt:=l;
  CloseWindow;
  If L=0 Then
    Exit;
  For l:=Secondary^.EOF Downto Secondary^.X Do
    Secondary^.D^[l+numxt]:=Secondary^.D^[l];
  Inc(Secondary^.EOF,numxt);
  For l:=0 To numxt-1 Do
    Secondary^.D^[Secondary^.X+l]:=D.D^[D.X+l];
  ToggleChanges(Secondary^);
End;

{------------------------------------------------------------------------}

Procedure CopyBlock(Var Dt:DataType);
Var size,l:LongInt;     DestinationBefore:Boolean;
Begin
  If Dt.X<Dt.BlockStart Then
    DestinationBefore:=True
  Else
    DestinationBefore:=False;
  With Dt Do
    Begin
      If (BlockFinish<BlockStart) Or ((X>=BlockStart) And (X<=BlockFinish)) Then
        Exit;
      SaveSegment(Dt);
      Size:=BlockFinish-BlockStart+1;
      FastInsert(Dt,X+offset,Size,0);
      X:=X-1;
      l:=0;
      While Size>0 Do
        If Size>imagesize Then
          Begin
            If DestinationBefore Then
              Seek(stream,BlockStart+BlockFinish-BlockStart)
            Else
              Seek(stream,BlockStart+l*imagesize-1);
            BlockRead(stream,D^,imagesize);
            If IOResult=0 Then
              ;
            Seek(stream,X+l*imagesize);
            BlockWrite(stream,D^,imagesize);
            If IOResult=0 Then
              ;
            Size:=Size-imagesize;
          End
        Else
         Begin
            If DestinationBefore Then
              Seek(stream,BlockStart+BlockFinish-BlockStart)
            Else
              Seek(stream,BlockStart+l*imagesize-1);
            BlockRead(stream,D^,size);
            If IOResult=0 Then
              ;
            Seek(stream,X+l*imagesize);
            BlockWrite(stream,D^,size);
            If IOResult=0 Then
              ;
            Size:=Size-Size;
         End;

      X:=X+1;
      Size:=BlockFinish-BlockStart;
      BlockStart:=X;
      BlockFinish:=X+Size;
      RestoreSegment(Dt);
    End;
End;

{------------------------------------------------------------------------}

Procedure MoveBlock(Var D:DataType);
Var Start,Size:LongInt;
Begin
  SaveSegment(D);
  If (D.BlockStart<1)  Or (D.BlockFinish<1) Or
     ((D.X+D.offset>=D.BlockStart) And (D.X+D.offset<=D.BlockFinish)) Then
    Exit;
  Start:=D.BlockStart;
  Size:=D.BlockFinish-D.BlockStart+1;
  CopyBlock(D);
  If D.X+D.offset<Start Then
    Start:=Start+Size;
  DeleteBlock(D,Start,Size);
  If D.X+D.offset>Start Then
    Begin
      Dec(D.BlockStart,Size);
      Dec(D.BlockFinish,Size);
      Dec(D.X,Size);
    End;
  Relocate(D);
  RestoreSegment(D);
End;

{------------------------------------------------------------------------}

Procedure WriteBlock(Var D:DataType);
Var
  S:String;
  F:File;
  Size:LongInt;
  Count,wtn:Word;
Begin
  If (D.BlockStart<0) Or (D.BlockFinish<0) Then
    Exit;

  OpenWindow(10,10,70,11,ICFG.MsgColor);
  Writeln('Enter file name to write to.');
  Write('> ');
  S:=StringEdit('DEFAULT.DAT',58,FileSet);
  CloseWindow;
  If EscExit Then
    Exit;

  If Not SaveTemp(D.D^,0) Then
    Begin
      ErrorMsg('Not enough memory');
      Exit;
    End;

  Assign(F,S);
  Rewrite(F,1);
  If IOResult <> 0 Then
    Begin
      Write(^G);
      Exit;
    End;
  Size:=D.BlockFinish-D.BlockStart+1;
  Seek(D.stream,D.BlockStart-1);
  While Size>0 Do
    If Size<$FFFF Then
      Begin
        BlockRead(D.stream,D.D^,Size,count);
        BlockWrite(F,D.D^,count,wtn);
        Size:=Size-count;
      End
    Else
      Begin
        BlockRead(D.stream,D.D^,imagesize,count);
        BlockWrite(F,D.D^,count,wtn);
        Size:=Size-count;
      End;
  Close(F);

  RestoreTemp(D.D^,0);
End;

{------------------------------------------------------------------------}

Procedure ReadBlock(Var D:DataType);
Var
  S:String;
  F:FILE;
  count,wtn:Word;
Begin
  OpenWindow(10,10,70,11,ICFG.MsgColor);
  Writeln('Enter file name to read from.');
  Write('> ');
  S:=StringEdit('DEFAULT.DAT',58,FileSet);
  CloseWindow;

  If EscExit Then
    Exit;

  SaveSegment(D);
  Assign(F,S);
  Reset(F,1);
  D.BlockStart:=D.X+D.offset;
  D.BlockFinish:=D.X+D.offset+FileSize(F)-1;
  FastInsert(D,D.X+D.offset,FileSize(F),$00);
  Seek(D.stream,D.X+D.offset-1);
  While NOT EOF(F) Do
    Begin
      BlockRead(F,D.D^,imagesize,count);
      BlockWrite(D.stream,D.D^,count,wtn);
    End;
  Close(F);
  RestoreSegment(D);
End;

{======================================================================}

End.
