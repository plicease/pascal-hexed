(*============================================================================
| lowint.pas
|    low interface accessed by user functions.
|    sorry, i'm confused.
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$I-}
{$PACKRECORDS 1}

Unit LowInt; {Low Interface (accessed by user functions)}

INTERFACE

Uses
  Header;

{++PROCEDURES++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Procedure FastInsert(Var D:DataType; X,size:LongInt;  bi:Byte);
Procedure DoInsert(Var D:DataType;  am:LongInt;  bi:Byte);

{++FUNCTIONS+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Function IfStrThere(Var D:DataType; Var i:LongInt; S:String):Boolean;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

IMPLEMENTATION

Uses
  FUTIL,OUTCRT,ViewU,CFG,VCrt,VConvert;

{----------------------------------------------------------------------}

Procedure FastInsert(Var D:DataType; X,size:LongInt;  bi:Byte);
Var l:LongInt; count,wtn:Word;
Begin
  Dec(X);
  SaveSegment(D);

  l:=0;
  While (l+1)*$FFFF+X<FileSize(D.stream) Do
    Inc(l);

  For l:=l DownTo 0 Do
    Begin
      Seek(D.stream,l*$FFFF+X);
      BlockRead(D.stream,D.D^,imagesize,count);
      Seek(D.stream,l*$FFFF+X+size);
      BlockWrite(D.stream,D.D^,count,wtn);
      If count<>wtn Then
        Begin
          ErrorMsg('error moving writing segments');
          Exit;
        End;
    End;

  FillChar(D.D^,imagesize,bi);
  Seek(D.stream,X);
  While size>0 Do
    If size>$FFFF Then
      Begin
        BlockWrite(D.stream,D.D^,$FFFF);
        If IOResult=0 Then
          ;
        size:=size-$FFFF;
      End
    Else
      Begin
        BlockWrite(D.stream,D.D^,size);
        If IOResult=0 Then
          ;
        size:=size-size;
      End;

  RestoreSegment(D);
  D.EOF:=FileSize(D.stream);
End;

{------------------------------------------------------------------------}

Procedure DoInsert(Var D:DataType;  am:LongInt;  bi:Byte);
Var index:LongInt; Filler:Array [0..10] Of Byte;  error:Word;
    X,Y:Byte;
Begin
  If D.EOF<imagesize-1 Then
    Begin
      For index:=D.EOF DownTo D.X+D.offset Do
        D.D^[index+am]:=D.D^[index];
      For index:=D.X+D.offset To D.X+D.offset+am-1 Do
        D.D^[index]:=bi;
      D.EOF:=D.EOF+am;
      ToggleChanges(D);
    End
  Else
    FastInsert(D,D.X+D.offset,am,bi);
End;

{------------------------------------------------------------------------}

Function IfStrThere(Var D:DataType; Var i:LongInt; S:String):Boolean;
Var index:LongInt;
Begin
  IfStrThere:=False;
  For index:=1 To Length(S) Do
    If D.D^[i+index-1]<>Ord(S[index]) Then
      Exit;
  IfStrThere:=True;
End;

{======================================================================}

End.
