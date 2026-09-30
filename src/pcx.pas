(*============================================================================
| pcx.pas
|    module for viewing pcx files.  pcx is a horrible format, but really
|    easy to parse.  this module is independant of the rest of hexed.
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$I-,O+,F+}

{$PACKRECORDS 1}

Unit PCX;

INTERFACE

Uses Ollis;

{++PROCEDURES++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{++FUNCTIONS+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Function DrawPCXMem(Var buff:Pointer; Var p:Pal):String;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

IMPLEMENTATION

Uses VCrt;

Type
  pcxHeader=Record
    Manufacturer,          (* should be set to $A0 *)
    version,               (* version number.  We suport 5 only *)
    encoding,              (* defines compression mode.  1 is the only known *)
    bits_per_pixel:Byte;   (* # of bits per pixel.  should be 8 *)
    X1,Y1,X2,Y2,           (* defines location an size of image *)
    hres,vres:Integer;     (* resolution of screen saved on.  useless *)
    EGAPalette:Array [1..48] of Byte;  (*EGA palette.  ignore *)
    reserved,
    color_planes:Byte;
    bytes_per_line,
    palette_type:Integer;
    filler:Array [1..58] of Byte;
  End;

{--------------------------------------------------------------------}

Function InBox(x,y,X1,Y1,X2,Y2:Integer):Boolean;
Begin
  If (x>=X1) And (x<=X2) And (y>=Y1) And (y<=Y2) Then
    InBox:=True
  Else
    InBox:=False;
End;

{--------------------------------------------------------------------}

Procedure CheckPCXHeader(S:String;  Var errstr:String; h:pcxHeader;  szc:Boolean);
Begin
  errstr:='';
  With h Do
    Begin
      If (manufacturer<>10) Then
        errstr:='manufacturer byte != 10 $0A';
      If (encoding<>1) Then
        errstr:='encoding byte != 1';
      If bits_per_pixel<>8 Then
        errstr:='is not a 256 color PCX file.';
      If szc Then
        If Not (InBox(X1,Y1,0,0,MaxX,MaxY)) Or
           Not (InBox(X2,Y2,0,0,MaxX,MaxY)) Then
          errstr:='does not fit in a '+IntToStr(MaxX+1)+
                       'x'+IntToStr(MaxY+1)+' res screen';
     End;
End;

{--------------------------------------------------------------------}

Type
  BytePointer=^Byte;

Procedure IncPtr(Var ofst:BytePointer;  Var b:Byte);
Begin
  Inc(ofst);
  b:=ofst^;
End;

{--------------------------------------------------------------------}

Function DrawPCXMem(Var buff:Pointer; Var p:Pal):String;
Var h:^PCXHeader;  ofst:BytePointer;  b:Byte;  x,y:Word;  I:Integer;
    errstr:String;
Begin
  DrawPCXMem:='Unknown error.';
  h:=buff;
  CheckPCXHeader('MEMORY PCX FILE',errstr,h^,TRUE);
  If (errstr<>'') Then
    Begin
      DrawPCXMem:=errstr;
      Exit;
    End;
  ofst:=@h^.filler[58];
  x:=h^.X1;  y:=h^.Y1;
  Repeat
    Repeat
      IncPtr(ofst,b);
      If (b And $C0)=$C0 Then
        Begin
          I:=b And $3F;
          IncPtr(ofst,b);
          For I:=I DownTo 1 Do
            Begin
              GraphAcc1^[y,x]:=b;
              Inc(x);
            End;
        End
      Else
        Begin
          GraphAcc1^[y,x]:=b;
          Inc(x);
        End;
    Until x>h^.X2;
    y:=y+1;
    x:=h^.X1;
    If KeyPressed Then
      Begin
        DrawPCXMem:='';
        Exit;
      End;
  Until y>h^.Y2;
  IncPtr(ofst,b);
  If b=$0C Then
    For I:=0 To $FF Do
      With p[I] Do
        Begin
          IncPtr(ofst,b);
          Red:=b shr 2;
          IncPtr(ofst,b);
          Green:=b shr 2;
          IncPtr(ofst,b);
          Blue:=b shr 2;
        End;
  DrawPCXMem:='';
End;

{======================================================================}

End.
