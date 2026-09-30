(*============================================================================
| ollis.pas
|    graphics routines.  originally for a game.  pretty much independant
|    from everything else.  if you wanted to rip one thig from hexed, this
|    would be the unit to rip.
|
|    under Free Pascal the VGA and mouse hardware is emulated by VCrt:
|    GraphAcc1 points at an in-memory 320x200 frame that VCrt draws on the
|    terminal, and the palette lives in VCrt.VGAPal.
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$I-,O+,F+}

{$PACKRECORDS 1}

Unit Ollis;

INTERFACE

Type
  Pal=Array [0..255] of Record
    Red,Green,Blue:Byte;
  End;
  stdLineType=Array [0..319] Of Byte;
  ScreenType1=Array [0..199] Of stdLineType;
  PageType=^ScreenType1;

Var
  GraphAcc1:PageType;

  {Init Graph Constants}

Const
  {Graphics Modes}

  stdVGA=$13;
  BGIVGA=$100;

Type
  ResIdStr=Array [0..7] Of Char;

Const
  MinFontChar=0;
  MaxFontChar=255;
  FontNameSize=32;
  Resid:ResIDStr='ALCHRSRC';
  FontID:Array [1..4] Of Char='FONT';
  FontFileName:String[22]='Fonts.Res';
  {Fonts}
  Swiss9=2;
  Swiss10=3;
  Swiss12=4;
  Swiss14=5;
  Swiss18=6;
  Swiss20=7;
  Swiss24=8;
  OldEng18=9;
  MonoSpace9=10;
  MonoSpace12=11;
  Dutch9=12;
  Dutch10=13;
  Dutch12=14;
  Dutch14=15;
  Dutch18=16;
  Dutch20=17;
  Dutch24=18;
  MaskTable:Array [0..7] Of Byte=($80,$40,$20,$10,$08,$04,$02,$01);

Type
  ResHead=Record
    ID:ResIDStr;
    Description:Array [0..64] Of Char;
    Count:Word;
  End;

  UnsignedLong=LongInt;

  Resource=Record
    RType:Array [0..3] Of Char;
    number:UnsignedLong;
    size:Word;
  End;

  Font=Record
    Name:Array [0..FontNameSize] Of Char;
    number:Byte;
    PointSize:Byte;
    CharWide:Array [0..(MaxFontChar-MinFontChar)] Of Byte;
    CharOff:Array [0..(MaxFontChar-MinFontChar)] Of Word;
    BitMapWidth,
    BitMapdepth,
    BitMapBytes,
    WidestChar,
    PadWidth,
    SpaceWidth:Word;
  End;

  FPointer=^Font;

{--------------------------------------------------------------------}

Var
  MinX,MinY,MaxX,MaxY:Word;
  Color1,Color2:Byte;
  Mode:Word;
  CMFIOAddress:Word;

{++PROCEDURES++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{Graphics}

Procedure PutHor(Y:Integer;  l:stdLineType);
Procedure GetHor(Y:Integer;  Var l:stdLineType);
Procedure GraphFunc(Var f,n1,n2,dseg,dofs:Integer);
Procedure UnInitGraph;
Procedure SetPal(P:Pal);
Procedure SetRGBPalette(index,R,G,B:Byte);
Procedure GetPal(Var P:Pal);
Procedure FadeTo(from,P:Pal; FadeSpeed:Integer);
Function InScreen(x,y:Integer):Boolean;
Procedure PutPix(X,Y:Integer; C:Byte);
Procedure PutBar(X1,Y1,X2,Y2:Word);
Procedure PutLine(X1,Y1,X2,Y2:Integer);
Procedure PutString(s:String; fp:Fpointer; x,y:Integer);
Procedure PutRectangle(X1,Y1,X2,Y2:Integer);
Procedure SetVisualPage(page:Integer);

{Mouse}

Procedure HideMC;
Procedure ShowMC;
Procedure Mouse(Var m1,m2,m3,m4:Word);

{++FUNCTIONS+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{Number conversions}

Function IntToStr(I: Longint): String;
Function UpString(S:String):String;

{Graphics}

Function InitGraph(B:Word):Boolean;
Function LoadPal(S:String; Var P:Pal):Boolean;
Function SavePal(S:String; P:Pal):Boolean;
Function GetPix(X,Y:Integer):Byte;
Function SaveScreen(S:String):Boolean;
Function RestoreScreen(S:String):Boolean;
Function LoadFont(s:String; n:UnsignedLong):FPointer;
Function TextHeight(fp:FPointer):Integer;
Function TextWidth(fp:FPointer; s:String):Integer;
Function GetVisualPage:Integer;

{Mouse}

Function InitMC:Boolean;
Function GetMouseX:Word;
Function GetMouseY:Word;
Function MouseButtonPressed(wb:Word):Boolean;
Function MouseButtonReleased(wb:Word):Boolean;
Function MouseInBox(x1,y1,x2,y2:Integer):Boolean;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

IMPLEMENTATION

Uses Dos,VCrt;

{--------------------------------------------------------------------}

Procedure PutHor(Y:Integer;  l:stdLineType);
Var GA:^stdLineType;
Begin
  GA:=@GraphAcc1^[Y,0];
  GA^:=l;
End;

{--------------------------------------------------------------------}

Procedure GetHor(Y:Integer;  Var l:stdLineType);
Var GA:^stdLineType;
Begin
  GA:=@GraphAcc1^[Y,0];
  l:=GA^;
End;

{--------------------------------------------------------------------}

Procedure GraphFunc(Var f,n1,n2,dseg,dofs:Integer);
Begin
  {was a raw INT 10h call; there is no video BIOS to call any more}
End;

{--------------------------------------------------------------------}

Procedure UnInitGraph;
Begin
  LeaveGraphMode;
End;

{--------------------------------------------------------------------}

Function InitGraph(B:Word):Boolean;
Begin
  InitGraph:=False;
  Color1:=0;
  Color2:=255;
  If B=stdVGA Then
    Begin
      MinX:=0;
      MinY:=0;
      MaxX:=319;
      MaxY:=199;
      Mode:=B;
    End
  Else If B=BGIVGA Then
    Begin
      MinX:=0;
      MinY:=0;
      MaxX:=319;
      MaxY:=199;
      Mode:=StdVGA;
    End
  Else
    Exit;
  EnterGraphMode;
  InitGraph:=True;
End;

{--------------------------------------------------------------------}

Procedure SetPal(P:Pal);
Var I:Integer;
Begin
  For I:=0 To 255 Do
    Begin
      VGAPal[I,0]:=P[I].Red And $3F;
      VGAPal[I,1]:=P[I].Green And $3F;
      VGAPal[I,2]:=P[I].Blue And $3F;
    End;
End;

{--------------------------------------------------------------------}

Procedure SetRGBPalette(index,R,G,B:Byte);
Var p:Pal;
Begin
  GetPal(p);
  With p[index] Do
    Begin
      Red:=R;
      Green:=G;
      Blue:=B;
    End;
  SetPal(p);
End;

{--------------------------------------------------------------------}

Procedure GetPal(Var P:Pal);
Var I:Integer;
Begin
  For I:=0 To 255 Do
    Begin
      P[I].Red:=VGAPal[I,0];
      P[I].Green:=VGAPal[I,1];
      P[I].Blue:=VGAPal[I,2];
    End;
End;

{----------------------------------------------------------------}

Procedure FadeTo(from,P:Pal; FadeSpeed:Integer);
Var cur:Pal;  index,index2,distance:integer;
Begin
  For index:=$0 To FadeSpeed Do
    Begin
      For index2:=$00 To $FF Do
        Begin
          distance:=P[index2].Red-from[index2].Red;
          cur[index2].Red:=from[index2].Red+Round(distance/FadeSpeed*index);

          distance:=P[index2].Green-from[index2].Green;
          cur[index2].Green:=from[index2].Green+Round(distance/FadeSpeed*index);

          distance:=P[index2].Blue-from[index2].Blue;
          cur[index2].Blue:=from[index2].Blue+Round(distance/FadeSpeed*index);
        End;
      SetPal(cur);
    End;
End;

{----------------------------------------------------------------}

Function InScreen(x,y:Integer):Boolean;
Begin
  If (x>=MinX) And (x<=MaxX) And (y>=MinY) And (y<=MaxY) Then
    InScreen:=True
  Else
    InScreen:=False;
End;

{----------------------------------------------------------------}

Procedure PutPix(X,Y:Integer; C:Byte);
Begin
  If InScreen(X,Y) Then
    GraphAcc1^[Y,X]:=C;
End;

{----------------------------------------------------------------}

Procedure PutBar(X1,Y1,X2,Y2:Word);
Var x,y:Integer;
Begin
  For x:=X1 To X2 Do
    For y:=Y1 To Y2 Do
      If InScreen(X,Y) Then
        GraphAcc1^[Y,X]:=Color1;
End;

{----------------------------------------------------------------}

Function ReadChar(Var F:File):Boolean;
Var C:Char; count:Integer;
Begin
  BlockRead(F,C,1,count);
  If count=1 Then
    ReadChar:=False
  Else
    ReadChar:=True;
End;

{----------------------------------------------------------------}

Procedure Swap(Var a,b:Integer);
Var temp:Integer;
Begin
  temp:=a;
  a:=b;
  b:=temp;
End;

{----------------------------------------------------------------}

    {don't even try to understand this procedure.  It just draws a
     line from (x1,y1) to (x2,y2)}

Procedure PutLine(X1,Y1,X2,Y2:Integer);
Var
  dx,dy,x,y,x_sign,y_sign,flag:Integer;
Begin
  dx:=Abs(x2-x1);
  dy:=Abs(y2-y1);
  If ((dx >= dy) And (x1 > x2)) Or
     ((dy >  dx) And (y1 > y2)) Then
    Begin
      Swap(x1,x2);
      Swap(y1,y2);
    End;
  If (y2-y1) < 0 Then
    y_sign:=-1
  Else
    y_sign:=1;
  If (x2-x1) <0 Then
    x_sign:=-1
  Else
    x_sign:=1;
  If dx>=dy Then
    Begin
      x:=x1;
      y:=y1;
      flag:=0;
      While x<=x2 Do
        Begin
          if flag>=dx Then
            Begin
              flag:=flag-dx;
              y:=y+y_sign;
            End;
          If InScreen(x,y) Then
            GraphAcc1^[y,x]:=Color1;
          x:=x+1;
          flag:=flag+dy;
        End;
    End
  Else
    Begin
      x:=x1;
      y:=y1;
      flag:=0;
      While y<=y2 Do
        Begin
          If flag>=dy Then
            Begin
              flag:=flag-dy;
              x:=x+x_sign;
            End;
          If InScreen(x,y) Then
            GraphAcc1^[y,x]:=Color1;
          y:=y+1;
          flag:=flag+dx;
        End;
    End;
End;

{----------------------------------------------------------------}

Procedure PutString(s:String; fp:Fpointer; x,y:Integer);
Var
  bmp:Pointer;
  n,i,j,k,kl,cp,cb:Integer;
Begin
  x:=x-(fp^.bitmapdepth div 10*9);
  n:=Length(s)+1;
  bmp:=Pointer(PtrUInt(fp)+SizeOf(Font));
  For i:=0 To fp^.bitmapdepth-1 Do
    Begin
      cb:=x;
      For j:=0 To n-1 Do
        Begin
          If S[j]<>#32 Then
            Begin
              kl:=fp^.CharWide[Ord(s[j])];
              cp:=fp^.charoff[Ord(s[j])];
              For k:=0 To kl-1 Do
                Begin
                  If Boolean(PByte(PtrUInt(bmp)+cp Shr 3)^ and
                             masktable[cp and $0007]) Then
                    If (InScreen(cb,y+i)) And (j<>0) Then
                      GraphAcc1^[y+i,cb]:=Color1;
                  cb:=cb+1;
                  cp:=cp+1;
                End;
              cb:=cb+fp^.padwidth;
            End
          Else
            cb:=cb+(fp^.spacewidth+fp^.padwidth);
        End;
      bmp:=Pointer(PtrUInt(bmp)+fp^.bitmapbytes);
    End;
End;

{----------------------------------------------------------------}

Procedure PutRectangle(X1,Y1,X2,Y2:Integer);
Var index:Integer;
Begin
  PutLine(X1,Y1,X1,Y2);
  PutLine(X1,Y1,X2,Y1);
  PutLine(X2,Y2,X1,Y2);
  PutLine(X2,Y2,X2,Y1);
End;

{----------------------------------------------------------------}

Procedure SetVisualPage(page:Integer);
Begin
  {only one page on a terminal}
End;

{----------------------------------------------------------------}

Procedure HideMC;
Begin
  {the terminal draws its own mouse pointer}
End;

{----------------------------------------------------------------}

Procedure ShowMC;
Begin
End;

{----------------------------------------------------------------}

{ a small INT 33h work-alike on top of VCrt, for the functions hexed uses:
  0 reset, 1 show, 2 hide, 3 position/buttons, 5 press count,
  6 release count. }
Procedure Mouse(Var m1,m2,m3,m4:Word);
Begin
  Case m1 Of
    0 : If MouseInstalled Then
          Begin
            m1:=$FFFF;
            m2:=3;
          End
        Else
          m1:=0;
    3 : Begin
          m3:=MousePixelX;
          m4:=MousePixelY;
          m2:=0;
        End;
    5 : m2:=MousePressCount(m2);
    6 : m2:=MouseReleaseCount(m2);
  End;
End;

{--------------------------------------------------------------------}

function IntToStr(I: Longint): String;
{ Convert any integer type to a string }
var
 S: string[11];
begin
 Str(I, S);
 IntToStr := S;
end;

{--------------------------------------------------------------------}

Function UpString(S:String):String;
Var Index:Integer;
Begin
  For Index:=1 To Length(S) Do
    S[index]:=UpCase(S[index]);
  UpString:=S;
End;

{----------------------------------------------------------------}

Function LoadPal(S:String; Var P:Pal):Boolean;
Var F:File Of Pal;
Begin
  LoadPal:=False;
  Assign(F,S);
  Reset(F);
  If IOResult<>0 Then
    Exit;
  Read(F,P);
  If IOResult<>0 Then
    Exit;
  Close(F);
  LoadPal:=True;
End;

{----------------------------------------------------------------}

Function SavePal(S:String; P:Pal):Boolean;
Var F:File Of Pal;
Begin
  SavePal:=False;
  Assign(F,S);
  Rewrite(F);
  If IOResult<>0 Then
    Exit;
  Write(F,P);
  If IOResult<>0 Then
    Exit;
  Close(F);
  SavePal:=True;
End;

{----------------------------------------------------------------}

Function GetPix(X,Y:Integer):Byte;
Begin
  GetPix:=GraphAcc1^[Y,X]
End;

{----------------------------------------------------------------}

Function SaveScreen(S:String):Boolean;
Var F:File Of ScreenType1;
Begin
  SaveScreen:=False;
  Assign(F,S);
  ReWrite(F);
  If IOResult <> 0 Then
    Exit;
  Write(F,GraphAcc1^);
  If IOResult <> 0 Then
    Exit;
  Close(F);
  SaveScreen:=True;
End;

{----------------------------------------------------------------}

Function RestoreScreen(S:String):Boolean;
Var F:File Of ScreenType1;
Begin
  RestoreScreen:=False;
  Assign(F,S);
  Reset(F);
  If IOResult <> 0 Then
    Exit;
  Read(F,GraphAcc1^);
  If IOResult <> 0 Then
    Exit;
  Close(F);
  RestoreScreen:=True;
End;

{----------------------------------------------------------------}

Function LoadFont(s:String; n:UnsignedLong):FPointer;
Var rh:ResHead;
    rc:Resource;
    fp:FPointer;
    F:File;
    count,index:Integer;
Begin

  (* Open resource file *)
  Assign(F,s);
  Reset(F,1);
  If IOResult<>0 Then
    Begin
      LoadFont:=Nil;
      Exit;
    End;

  (* Read the Header *)
  BlockRead(F,rh,SizeOf(ResHead),count);
  If count<>SizeOf(ResHead) Then
    Begin
      LoadFont:=Nil;
      Close(F);
      Exit;
    End;

  (* Make sure its a resource file *)
  If Not (rh.id=ResId) Then
    Begin
      LoadFont:=Nil;
      Close(F);
      Exit;
    End;

  (* Look for all the resources *)
  For index:=0 To rh.count-1 Do
    Begin

      (* Fetch the resource *)
      BlockRead(F,rc,SizeOf(Resource),count);
      If count<>SizeOf(Resource) Then
        Begin
          LoadFont:=Nil;
          Close(F);
          Exit;
        End;

      (* If its a font and the one we want, load it *)
      If (rc.RType=FontID) And (rc.number=n) Then
        Begin

          (* Allocate a buffer for the area *)
          If MemAvail<rc.size Then
            Begin
              LoadFont:=Nil;
              Close(F);
              Exit;
            End;
          GetMem(fp,rc.size);

          (* Read the data *)
          BlockRead(F,fp^,rc.size,count);
          If rc.size<>count Then
            Begin
              FreeMem(fp,rc.size);
              LoadFont:=Nil;
              Close(F);
              Exit;
            End;

          (* we're done - go away *)
          Close(F);
          LoadFont:=fp;
          Exit;
        End;
      (* Otherwise seek the next resource *)
      For count:=1 To rc.Size Do
        If ReadChar(F) Then
          Begin
            LoadFont:=Nil;
            Close(F);
            Exit;
          End;
    End;
  Close(F);
  LoadFont:=Nil;
  Exit;
End;

{----------------------------------------------------------------}

Function TextHeight(fp:FPointer):Integer;
Begin
  TextHeight:=fp^.bitmapdepth;
End;

{----------------------------------------------------------------}

Function TextWidth(fp:FPointer; s:String):Integer;
Var
  bmp:Pointer;
  n,i,j,k,kl,cp,cb,x,y,maxx:Integer;
Begin
  x:=0;
  y:=0;
  maxx:=0;
  x:=x-(fp^.bitmapdepth div 10*9);
  n:=Length(s)+1;
  bmp:=Pointer(PtrUInt(fp)+SizeOf(Font));
  For i:=0 To fp^.bitmapdepth-1 Do
    Begin
      cb:=x;
      For j:=0 To n-1 Do
        Begin
          If S[j]<>#32 Then
            Begin
              kl:=fp^.CharWide[Ord(s[j])];
              cp:=fp^.charoff[Ord(s[j])];
              For k:=0 To kl-1 Do
                Begin
                  If Boolean(PByte(PtrUInt(bmp)+cp Shr 3)^ and
                             masktable[cp and $0007]) Then
                    If InScreen(cb,y+i) Then
                      Begin
                        If cb>maxx Then
                          maxx:=cb;
                      End;
                  cb:=cb+1;
                  cp:=cp+1;
                End;
              cb:=cb+fp^.padwidth;
            End
          Else
            cb:=cb+(fp^.spacewidth+fp^.padwidth);
        End;
      bmp:=Pointer(PtrUInt(bmp)+fp^.bitmapbytes);
    End;
  TextWidth:=maxx+1;
End;

{----------------------------------------------------------------}

Function GetVisualPage:Integer;
Begin
  GetVisualPage:=0;
End;

{----------------------------------------------------------------}

Function InitMC:Boolean;
Var m1,m2,m3,m4:Word;
Begin
  {like loading MOUSE.COM: have the terminal start reporting the mouse}
  EnableMouse;
  m1:=0;
  Mouse(m1,m2,m3,m4);
  If m1=0 Then
    InitMC:=False
  Else
    InitMC:=True;
End;

{----------------------------------------------------------------}

Procedure GetMouseCoords(Var x,y:Integer);
Var m1,m2,m3,m4:Word;
Begin
  m1:=3;
  m3:=x;  m4:=y;
  Mouse(m1,m2,m3,m4);
  x:=m3;  y:=m4;
  If MaxX=319 Then
    x:=x div 2;
End;

{----------------------------------------------------------------}

Function GetMouseX:Word;
Var x,y:Integer;
Begin
  GetMouseCoords(x,y);
  GetMouseX:=x;
End;

{----------------------------------------------------------------}

Function GetMouseY:Word;
Var x,y:Integer;
Begin
  GetMouseCoords(x,y);
  GetMouseY:=y;
End;

{----------------------------------------------------------------}

Function MouseButtonPressed(wb:Word):Boolean;
Var m1,m2,m3,m4:Word;
Begin
  m1:=5;
  m2:=wb;
  Mouse(m1,m2,m3,m4);
  If m2>0 Then
    MouseButtonPressed:=True
  Else
    MouseButtonPressed:=False;
End;

{----------------------------------------------------------------}

Function MouseButtonReleased(wb:Word):Boolean;
Var m1,m2,m3,m4:Word;
Begin
  m1:=6;
  m2:=wb;
  Mouse(m1,m2,m3,m4);
  If m2>0 Then
    MouseButtonReleased:=True
  Else
    MouseButtonReleased:=False;
End;

{----------------------------------------------------------------}

Function MouseInBox(x1,y1,x2,y2:Integer):Boolean;
Var x,y:Integer;
Begin
  x:=GetMouseX;    y:=GetMouseY;
  If (x>=x1) And (x<=x2) And (y>=y1) And (y<=y2) Then
    MouseInBox:=True
  Else
    MouseInBox:=False;
End;

{======================================================================}

Begin
  GraphAcc1:=PageType(GraphFrame);
End.
