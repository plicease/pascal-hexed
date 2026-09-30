(*============================================================================
| futil.pas
|   file functions for hexed.
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$I-}
{$PACKRECORDS 1}

Unit FUtil;

INTERFACE

Uses
  Header;

{++PROCEDURES++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Procedure RestoreTemp(Var B:BinaryImage; index:Integer);
Procedure SaveSegment(Var D:DataType);
Procedure RestoreSegment(Var D:DataType);
Procedure Relocate(Var D:DataType);
Procedure LoadFile(Var D:DataType);
Procedure LoadFile2(Var D:DataType);
Procedure ToggleChanges(Var D:DataType);
Procedure CheckIOError(S:String; exc:Integer);
Procedure CheckFileType(Var D:DataType);

{++FUNCTIONS+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Function SaveTemp(Var B:BinaryImage; index:Integer):Boolean;
Function GetFileByte(Var F:File; index:LongInt):Byte;
Function GetFileWord(Var F:File; index:LongInt):Word;
Function GetFileLong(Var F:File; index:LongInt):LongInt;
Function SizeOfFile(S:String):LongInt;
Function TempFileName(S:String):String;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

IMPLEMENTATION

Uses
  DOS,CNT,OutCRT,VCrt,ViewU,VConvert,CFG,Center;

{------------------------------------------------------------------------}

Procedure CheckIOError(S:String; exc:Integer);
Var Error:Integer; X,Y:Byte;
Begin
  Error:=IOResult;
  If (Error<>0) And (Error<>exc) Then
    Begin
      X:=WhereX;  Y:=WhereY;
      ErrorMsg('IOError on '+S+' err#'+IntToStr(Error,0));
      GotoXY(X,Y);
      TextAttr:=ICFG.LoLight;
    End;
End;

{-----------------------------------------------------------------}

Function SizeOfFile(S:String):LongInt;
{This function just finds the size of a file}
Var
  DirInfo:SearchRec;
Begin
  FindFirst(S,AnyFile,DirInfo);
  SizeOfFile:=DirInfo.Size;
  FindClose(DirInfo);
End;

{------------------------------------------------------------------------}

Function GetFileByte(Var F:File; index:LongInt):Byte;
{Get the byte at the specified index in the file pointed to by F}
Var B:Byte;
Begin
  B:=0;
  Seek(F,index);
  BlockRead(F,B,1);
  GetFileByte:=B;
End;

{------------------------------------------------------------------------}

Function GetFileWord(Var F:File; index:LongInt):Word;
{Get the byte at the specified index in the file pointed to by F}
Var B:Word;
Begin
  B:=0;
  Seek(F,index);
  BlockRead(F,B,2);
  GetFileWord:=B;
End;

{------------------------------------------------------------------------}

Function GetFileLong(Var F:File; index:LongInt):LongInt;
{Get the byte at the specified index in the file pointed to by F}
Var B:LongInt;
Begin
  B:=0;
  Seek(F,index);
  BlockRead(F,B,4);
  GetFileLong:=B;
End;

{------------------------------------------------------------------------}

Procedure SaveSegment(Var D:DataType);
Var error:Word;
Begin
  If Not D.changes Then
    Exit;
  D.Changes:=False;
  {Secondary is Nil when there is only one file; DOS let us read through
   a Nil pointer, nothing else does}
  If (Secondary=Nil) Or (D.FN<>Secondary^.FN) Then
    WriteScreen(D);
  Seek(D.stream,D.offset);
  If D.offset+imagesize-1<=D.EOF Then
    BlockWrite(D.stream,D.D^,imagesize-1)
  Else
    BlockWrite(D.stream,D.D^,D.EOF-D.offset);
  error:=IOResult;
  If error<>0 Then
    Begin
      WriteContactMsg;
      Writeln('error #',error,' writing a segment to file ',D.FN);
      Halt;
    End;
  If FileSize(D.stream)>D.EOF Then
    Begin
      Seek(D.stream,D.EOF);
      Truncate(D.stream);
    End;
End;

{------------------------------------------------------------------------}

Procedure RestoreSegment(Var D:DataType);
Var br,error:Word;
Begin
  FillChar(D.D^,imagesize,0);
  Seek(D.stream,D.offset);
  If D.offset+imagesize-1<=FileSize(D.stream) Then
    BlockRead(D.stream,D.D^,imagesize-1)
  Else
    Begin
      br:=FileSize(D.stream)-D.offset;
      BlockRead(D.stream,D.D^,br,error);
    End;
  error:=IOResult;
  If (Error<>0) And (Error<>100) Then
    Begin
      WriteContactMsg;
      Writeln('error #',error,' reading a segment from file ',D.FN);
      Halt;
    End;
End;

{------------------------------------------------------------------------}

Procedure Relocate(Var D:DataType);
Var x:LongInt;
Begin
  If (D.EOF<imagesize-1) And (D.offset<>0) Then
    Begin
      SaveSegment(D);
      D.offset:=0;
      D.X:=D.X+D.offset;
      RestoreSegment(D);
      Exit;
    End;
  If (D.X+D.offset<=1) Then
    D.X:=1-D.offset;
  If (D.X+D.offset>D.EOF) Then
    D.X:=D.EOF-D.offset;
  If (D.EOF<imagesize-1) Or ((D.X<imagesize-Bookend) And
     (D.X>Bookend)) Or ((D.offset=0) And (D.X<imagesize-Bookend)) Then
    exit;
  x:=D.X+D.offset;
  SaveSegment(D);
  D.X:=imagesize div 2;
  D.offset:=x-imagesize div 2;
  If x<imagesize Then
    Begin
      D.offset:=0;
      D.X:=x;
    End;
  RestoreSegment(D);
End;

{------------------------------------------------------------------------}

{ where to put scratch files.  DOS used %TEMP% or the current directory;
  elsewhere more than one hexed can be running so the process id is
  worked in to the name. }
Function TempFileName(S:String):String;
Var Dir:String;
Begin
  Dir:=GetEnv('TEMP');
  {$IFDEF UNIX}
  If Dir='' Then
    Dir:=GetEnv('TMPDIR');
  If Dir='' Then
    Dir:='/tmp';
  S:=IntToStr(GetProcessID,0)+'.'+S;
  {$ENDIF}
  While (Dir<>'') And (Dir[Length(Dir)] In AllowDirectorySeparators) Do
    Delete(Dir,Length(Dir),1);
  If Dir='' Then
    TempFileName:=S
  Else
    TempFileName:=Dir+DirectorySeparator+S;
End;

{------------------------------------------------------------------------}

Function SaveTemp(Var B:BinaryImage; index:Integer):Boolean;
Var  F:File of BinaryImage;
Begin
  SaveTemp:=FALSE;
  Assign(F,TempFileName('HEXED'+IntToStr(index,0)+'.TMP'));
  Rewrite(F);
  If IOResult <> 0 Then
    Exit;
  Write(F,B);
  If IOResult <> 0 Then
    Begin
      Close(F);
      If IOResult <> 0 Then
        ;
      Erase(F);
      If IOResult <> 0 Then
        ;
    End;
  Close(F);
  SaveTemp:=TRUE;
End;

{------------------------------------------------------------------------}

Procedure RestoreTemp(Var B:BinaryImage; index:Integer);
Var F:File of BinaryImage;
Begin
  Assign(F,TempFileName('HEXED'+IntToStr(index,0)+'.TMP'));
  Reset(F);
  Read(F,B);
  Close(F);
  Erase(F);
End;

{------------------------------------------------------------------------}

Procedure LoadFile(Var D:DataType);
Var I:Word;     Error:Word;
Begin
  If MemAvail<SizeOf(binaryImage) Then
    Begin
      TextAttr:=ICFG.Error;
      Writeln('Error: Not enough memory for binary image.');
      TextAttr:=SaveTextAttr;
      Halt;
    End;
  New(D.D);
  FillChar(D.D^,SizeOf(D.D^),0);
  TextAttr:=ICFG.Highlight;
  Write('Loading file...');
  Assign(D.stream,D.FN);
  Reset(D.stream,1);
  Error:=IOResult;
  If Error<>0 Then
    Begin
      TextAttr:=ICFG.Error;
      Writeln('Error: could not open file for reading Error number ',Error);
      TextAttr:=SaveTextAttr;
      Halt;
    End;
  D.EOF:=SizeOfFile(D.FN);
  D.offset:=Seek_To;
  Seek(D.stream,D.offset);
  BlockRead(D.stream,D.D^,$FFFE,Error);
  If ((Error<D.EOF) And (D.EOF<$FFFE)) Or ((Error<$FFFE) And (D.EOF>$FFFE)) Then
    Begin
      ErrorMsg('did not read entire file '+IntToStr(Error,0)+'/'+IntToStr(D.EOF,0));
      Halt;
    End;
  Writeln('file loaded');
  D.X:=1;
End;

{------------------------------------------------------------------------}

Procedure LoadFile2(Var D:DataType);
Var I:Word;     Error:Word;
Begin
  D.changes:=FALSE;
  D.BlockStart:=0;
  D.BlockFinish:=0;

  FillChar(D.D^,SizeOf(D.D^),0);

  Assign(D.stream,D.FN);
  Reset(D.stream,1);
  Error:=IOResult;
  If Error<>0 Then
    Begin
      Window(1,1,80,25);
      TextAttr:=ICFG.Error;
      ClrScr;
      Writeln('Error: could not open file for reading Error number ',Error);
      TextAttr:=SaveTextAttr;
      Halt;
    End;
  D.EOF:=SizeOfFile(D.FN);
  Seek(D.stream,D.offset);
  If Seek_To<>0 Then
    Begin
      D.offset:=Seek_To;
      Seek(D.stream,D.offset);
    End;
  BlockRead(D.stream,D.D^,$FFFE,Error);
End;

{------------------------------------------------------------------------}

Procedure ToggleChanges(Var D:DataType);
{This procedure changes the changes field the true so that HEXED can tell if
 the user has made changes when he tries to quit.  This way HEXED can say
 "You have unsaved changes (if he/she does).  Do you want to quit?"}
Begin
  If Not D.changes Then
    Begin
      D.changes:=True;
      WriteScreen(D);
    End;
End;

{------------------------------------------------------------------------}

Procedure DetectEXE;
Var
  Sig:Byte;
  Sig2:LongInt;
  W:Word;
Begin
  With Data.ED Do
    Begin
      NumRlc:=0;
      Seek(Data.stream,$06);
      If IOResult=0 Then
        BlockRead(Data.stream,NumRlc,2);

      Seek(Data.stream,$18);
      If IOResult=0 Then
        BlockRead(Data.stream,OffRlc,2);

      Seek(Data.stream,$08);
      If IOResult=0 Then
        Begin
          HeadSize:=512;
          BlockRead(Data.stream,W,2);
          If IOResult<>0 Then
            HeadSize:=W*16;
        End;

      Tp:=0;
      Seek(Data.stream,$1E);
      If IOResult=0 Then
        Begin
          BlockRead(Data.stream,Sig,1);
          If (IOResult=0) And (Sig=$FB) Then
            Tp:=2;
        End;

      Seek(Data.stream,$1C);
      If IOResult=0 Then
        Begin
          BlockRead(Data.stream,Sig2,4);
          If IOResult=0 Then
            If Sig2=$58534A52 Then
              Tp:=3
            Else If Sig2=$39305A4C Then
              Tp:=4
            Else If Sig2=$31395A4C Then
              Tp:=5
            Else If Sig2=$018A0001 Then
              Tp:=9
            Else If Sig2=$00020001 Then
              Tp:=10
            Else If Word(Sig2)=$000F Then
              Tp:=11;
        End;

    End;
End;

{------------------------------------------------------------------------}

Procedure CheckFileType(Var D:DataType);
Var
  Dir:DirStr;
  Name:NameStr;
  Ext:ExtStr;
  tmp:Byte;
  ID:Array [1..4] of Char;
Begin
  D.BlockStart:=-1;
  D.BlockFinish:=-2;
  FSplit(D.FN,Dir,Name,Ext);
  For tmp:=1 To 4 Do
    Ext[tmp]:=UpCase(Ext[tmp]);
  D.BFT:=1;
  If (Ext='.PCX') Then
    D.BFT:=2;
  If ((Ext='.PAL') Or (Ext='.COL')) Then
    D.BFT:=3;
  If (Ext='.CMF') Then
    D.BFT:=4;
  If (Ext='.SBI') Then
    D.BFT:=5;
  If (Ext='.GIF') Then
    D.BFT:=6;
  If (Ext='.VOC') Then
    D.BFT:=7;
  If (Ext='.IMG') Then
    D.BFT:=8;
  If (Ext='.MOD') Then
    Begin
      Seek(D.Stream,1080);
      If IOResult <> 0 Then
        Exit;
      BlockRead(D.Stream,ID,4);
      If IOResult <> 0 Then
        Exit;
      If (ID='M.K.') Or (ID='FLT4') Then
        D.BFT:=9
      Else
        D.BFT:=10;
    End;
  If (Ext='.IBK') Then
    D.BFT:=11;
  If (Ext='.FLI') Then
    D.BFT:=12;
  If (Ext[1]='.') And (Ext[2]='F') And (Ext[3]>='0') And (Ext[3]<='9') And
     (Ext[4]>='0') And (Ext[4]<='9') Then
    Begin
      Seek(D.stream,0);
      If IOResult <>0 Then
        Exit;
      ID[4]:='1';
      BlockRead(D.stream,ID,3);
      If (ID='FRG1') Then
        Begin
          D.BFT:=13;
          Seek(D.stream, 30);
          BlockRead(D.stream, D.FragOffset, 2);
        End;
    End;
  If (Ext='.EXE') Or (Ext='.COM') Then
    Begin
      D.BFT:=14;
      DetectEXE;
    End;
End;

{======================================================================}

End.
