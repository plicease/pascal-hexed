(*============================================================================
| vcrt.pas
|   a Turbo Pascal Crt work-alike for Free Pascal.  output goes through the
|   portable Video unit.  on unix the keyboard and mouse are decoded here
|   from the terminal's escape sequences; elsewhere the Keyboard and Mouse
|   units are used.
|
|   hexed was written for MS-DOS and freely pokes at text mode video memory
|   ($B800) to draw shadows and to save/restore the screen behind windows.
|   to keep all of that working, this unit keeps an 80 column text mode
|   screen in memory with exactly the same layout as the real thing (one
|   character byte followed by one attribute byte per cell).  every Crt
|   style write goes into that buffer and it gets copied to the terminal
|   whenever the program waits for input.
|
|   it also stands in for the bits of the BIOS hexed used: the keyboard
|   shift flags, the cursor shape, the mouse driver and VGA mode $13 (which
|   is rendered to the terminal with 24 bit colour half block characters).
|
| History:
| Date       Author     Comment
| ----       ------     -------
| 30 sep 26  G. Ollis    created for the Free Pascal port
============================================================================*)

{$MODE OBJFPC}{$H-}{$I-}

Unit VCrt;

INTERFACE

Const
  Black        = 0;
  Blue         = 1;
  Green        = 2;
  Cyan         = 3;
  Red          = 4;
  Magenta      = 5;
  Brown        = 6;
  LightGray    = 7;
  DarkGray     = 8;
  LightBlue    = 9;
  LightGreen   = 10;
  LightCyan    = 11;
  LightRed     = 12;
  LightMagenta = 13;
  Yellow       = 14;
  White        = 15;
  Blink        = 128;

  ScreenCols   = 80;
  MaxRows      = 50;

  {shift flags, same bits as the BIOS keyboard flag byte}
  KBRShift  =$01;
  KBLShift  =$02;
  KBCtrl    =$04;
  KBAlt     =$08;
  KBScroll  =$10;
  KBNum     =$20;
  KBCaps    =$40;
  KBInsert  =$80;

Type
  TextScreenType=Array [0..MaxRows*ScreenCols*2-1] Of Byte;
  TextScreenPointer=^TextScreenType;

  GraphFrameType=Array [0..199,0..319] Of Byte;
  GraphFramePointer=^GraphFrameType;
  VGAPalType=Array [0..255,0..2] Of Byte;

Var
  TextAttr:Byte;
  WindMin,WindMax:Word;
  LastMode:Word;
  CheckBreak:Boolean;
  DirectVideo:Boolean;

  ScreenRows:Byte;              {number of text rows being emulated}
  TextScreen:TextScreenPointer; {the emulated $B800 segment}

  GraphMode:Boolean;            {true while "in" VGA mode $13}
  GraphFrame:GraphFramePointer; {the emulated $A000 segment}
  VGAPal:VGAPalType;            {DAC palette, 6 bits per component}

{Crt}

Procedure AssignCrt(Var F:Text);
Procedure ClrScr;
Procedure ClrEol;
Procedure GotoXY(X,Y:Byte);
Function  WhereX:Byte;
Function  WhereY:Byte;
Procedure Window(X1,Y1,X2,Y2:Byte);
Procedure TextColor(Color:Byte);
Procedure TextBackground(Color:Byte);
Procedure NormVideo;
Procedure HighVideo;
Procedure LowVideo;
Procedure InsLine;
Procedure DelLine;
Function  KeyPressed:Boolean;
Function  ReadKey:Char;
Procedure Delay(MS:Word);
Procedure Sound(Hz:Word);
Procedure NoSound;

{BIOS work-alikes}

Procedure SetScreenRows(Rows:Byte);
Procedure CursorHide;
Procedure CursorNormal;
Procedure CursorBlock;
Function  ShiftFlags:Byte;
Procedure EnterGraphMode;
Procedure LeaveGraphMode;
Procedure FlushScreen;
Procedure IdleWait;
Procedure Beep;
Procedure SuspendConsole;
Procedure ResumeConsole;

{mouse driver work-alike.  coordinates are in "pixels" (8 per text cell)
 like the DOS mouse driver reports in text mode}

Procedure EnableMouse;
Function  MouseInstalled:Boolean;
Function  MousePixelX:Word;
Function  MousePixelY:Word;
Function  MousePressCount(Button:Word):Word;
Function  MouseReleaseCount(Button:Word):Word;

{DOS heap functions.  there is no 640k limit any more, so report plenty}

Function MemAvail:LongInt;
Function MaxAvail:LongInt;

IMPLEMENTATION

Uses
  {$IFDEF UNIX}BaseUnix,Termio,{$ELSE}Keyboard,Mouse,{$ENDIF}
  {$IFDEF WINDOWS}Windows,{$ENDIF}
  Video,SysUtils;

Const
  NormAttr=LightGray;

Var
  CurX,CurY:Byte;           {cursor, 0 based, absolute screen coordinates}
  ShadowFrame:GraphFramePointer; {what is on the terminal in graph mode}
  ShadowPal:VGAPalType;
  WasGraph:Boolean;
  LastFlush:QWord;
  PendingScan:Char;         {second half of an extended key}
  LastShift:Byte;
  InsertOn:Boolean;
  BellPending:Boolean;
  CursorShape:Integer;
  MousePress,MouseRelease:Array [0..2] Of Word;
  MouseDown:Array [0..2] Of Boolean;
  MouseCol,MouseRow:Word;
  VideoUp:Boolean;

{----------------------------------------------------------------------}
{ the screen buffer                                                     }
{----------------------------------------------------------------------}

Function Cell(X,Y:Integer):Integer; inline;
Begin
  Cell:=(Y*ScreenCols+X)*2;
End;

Procedure ScrollWindowUp;
Var
  X1,Y1,X2,Y2,X,Y:Integer;
Begin
  X1:=Lo(WindMin);  Y1:=Hi(WindMin);
  X2:=Lo(WindMax);  Y2:=Hi(WindMax);
  For Y:=Y1 To Y2-1 Do
    Move(TextScreen^[Cell(X1,Y+1)],TextScreen^[Cell(X1,Y)],(X2-X1+1)*2);
  For X:=X1 To X2 Do
    Begin
      TextScreen^[Cell(X,Y2)]:=32;
      TextScreen^[Cell(X,Y2)+1]:=TextAttr;
    End;
End;

Procedure LineFeed;
Begin
  If CurY<Hi(WindMax) Then
    Inc(CurY)
  Else
    ScrollWindowUp;
End;

Procedure PutChar(C:Char);
Begin
  Case C Of
    #7  : BellPending:=True;
    #8  : If CurX>Lo(WindMin) Then
            Dec(CurX);
    #10 : Begin
            {Writeln only sends a line feed outside of DOS}
            CurX:=Lo(WindMin);
            LineFeed;
          End;
    #13 : CurX:=Lo(WindMin);
  Else
    Begin
      TextScreen^[Cell(CurX,CurY)]:=Byte(C);
      TextScreen^[Cell(CurX,CurY)+1]:=TextAttr;
      If CurX<Lo(WindMax) Then
        Inc(CurX)
      Else
        Begin
          CurX:=Lo(WindMin);
          LineFeed;
        End;
    End;
  End;
End;

Procedure ClrScr;
Var X,Y:Integer;
Begin
  For Y:=Hi(WindMin) To Hi(WindMax) Do
    For X:=Lo(WindMin) To Lo(WindMax) Do
      Begin
        TextScreen^[Cell(X,Y)]:=32;
        TextScreen^[Cell(X,Y)+1]:=TextAttr;
      End;
  CurX:=Lo(WindMin);
  CurY:=Hi(WindMin);
End;

Procedure ClrEol;
Var X:Integer;
Begin
  For X:=CurX To Lo(WindMax) Do
    Begin
      TextScreen^[Cell(X,CurY)]:=32;
      TextScreen^[Cell(X,CurY)+1]:=TextAttr;
    End;
End;

Procedure InsLine;
Var X1,X2,X,Y:Integer;
Begin
  X1:=Lo(WindMin);  X2:=Lo(WindMax);
  For Y:=Hi(WindMax) DownTo CurY+1 Do
    Move(TextScreen^[Cell(X1,Y-1)],TextScreen^[Cell(X1,Y)],(X2-X1+1)*2);
  For X:=X1 To X2 Do
    Begin
      TextScreen^[Cell(X,CurY)]:=32;
      TextScreen^[Cell(X,CurY)+1]:=TextAttr;
    End;
End;

Procedure DelLine;
Var X1,X2,X,Y:Integer;
Begin
  X1:=Lo(WindMin);  X2:=Lo(WindMax);
  For Y:=CurY To Hi(WindMax)-1 Do
    Move(TextScreen^[Cell(X1,Y+1)],TextScreen^[Cell(X1,Y)],(X2-X1+1)*2);
  For X:=X1 To X2 Do
    Begin
      TextScreen^[Cell(X,Hi(WindMax))]:=32;
      TextScreen^[Cell(X,Hi(WindMax))+1]:=TextAttr;
    End;
End;

Procedure GotoXY(X,Y:Byte);
Begin
  {like TP, coordinates outside the window are ignored}
  If (X<1) Or (Y<1) Then
    Exit;
  If (X-1+Lo(WindMin)>Lo(WindMax)) Or (Y-1+Hi(WindMin)>Hi(WindMax)) Then
    Exit;
  CurX:=X-1+Lo(WindMin);
  CurY:=Y-1+Hi(WindMin);
End;

Function WhereX:Byte;
Begin
  WhereX:=CurX-Lo(WindMin)+1;
End;

Function WhereY:Byte;
Begin
  WhereY:=CurY-Hi(WindMin)+1;
End;

Procedure Window(X1,Y1,X2,Y2:Byte);
Begin
  If (X1<1) Or (Y1<1) Or (X2>ScreenCols) Or (Y2>ScreenRows) Or
     (X1>X2) Or (Y1>Y2) Then
    Exit;
  WindMin:=(X1-1) Or ((Y1-1) Shl 8);
  WindMax:=(X2-1) Or ((Y2-1) Shl 8);
  CurX:=X1-1;
  CurY:=Y1-1;
End;

Procedure TextColor(Color:Byte);
Begin
  TextAttr:=(TextAttr And $70) Or (Color And $8F);
End;

Procedure TextBackground(Color:Byte);
Begin
  TextAttr:=(TextAttr And $8F) Or ((Color And $07) Shl 4);
End;

Procedure NormVideo;
Begin
  TextAttr:=NormAttr;
End;

Procedure HighVideo;
Begin
  TextAttr:=TextAttr Or $08;
End;

Procedure LowVideo;
Begin
  TextAttr:=TextAttr And $F7;
End;

Procedure SetScreenRows(Rows:Byte);
Begin
  If Rows<1 Then
    Rows:=25;
  If Rows>MaxRows Then
    Rows:=MaxRows;
  ScreenRows:=Rows;
  Window(1,1,ScreenCols,ScreenRows);
End;

{----------------------------------------------------------------------}
{ text file driver so Write/Writeln end up in the buffer                }
{----------------------------------------------------------------------}

Procedure CrtWrite(Var F:TextRec);
Var I:LongInt;
Begin
  For I:=0 To F.BufPos-1 Do
    PutChar(F.BufPtr^[I]);
  F.BufPos:=0;
End;

Procedure CrtNop(Var F:TextRec);
Begin
End;

Procedure CrtClose(Var F:TextRec);
Begin
  F.Mode:=fmClosed;
End;

Procedure CrtOpen(Var F:TextRec);
Begin
  If F.Mode=fmOutput Then
    Begin
      F.InOutFunc:=@CrtWrite;
      F.FlushFunc:=@CrtWrite;
    End
  Else
    Begin
      F.InOutFunc:=@CrtNop;
      F.FlushFunc:=@CrtNop;
    End;
  F.CloseFunc:=@CrtClose;
End;

Procedure AssignCrt(Var F:Text);
Begin
  Assign(F,'');
  TextRec(F).OpenFunc:=@CrtOpen;
End;

{----------------------------------------------------------------------}
{ getting it on to the terminal                                         }
{----------------------------------------------------------------------}

{ write straight to the terminal, bypassing Video.  S is UTF-8 and may
  hold escape sequences. }
Procedure RawOut(Const S:AnsiString);
{$IFDEF WINDOWS}
Var
  Written:DWord;
  W:UnicodeString;
{$ENDIF}
Begin
  If S='' Then
    Exit;
  {$IFDEF UNIX}
  fpWrite(1,S[1],Length(S));
  {$ENDIF}
  {$IFDEF WINDOWS}
  {WriteConsoleW doesn't care about the console code page}
  W:=UTF8Decode(S);
  If Not WriteConsoleW(GetStdHandle(STD_OUTPUT_HANDLE),PWideChar(W),
                       Length(W),Written,Nil) Then
    WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),S[1],Length(S),Written,Nil);
  {$ENDIF}
End;

{$IFDEF WINDOWS}
{ the graphics are drawn with escape sequences, which the Windows 10
  console understands once asked to }
Procedure EnableVTOutput;
Const
  ENABLE_VIRTUAL_TERMINAL_PROCESSING=$0004;
Var
  H:THandle;
  M:DWord;
Begin
  H:=GetStdHandle(STD_OUTPUT_HANDLE);
  If GetConsoleMode(H,M) Then
    SetConsoleMode(H,M Or ENABLE_VIRTUAL_TERMINAL_PROCESSING);
End;
{$ENDIF}

Procedure Beep;
Begin
  RawOut(#7);
End;

Procedure ApplyCursor;
Begin
  If GraphMode Or (CursorShape=crHidden) Then
    SetCursorType(crHidden)
  Else
    SetCursorType(CursorShape);
End;

Procedure CopyTextToVideo;
Var
  X,Y,W,H:Integer;
  Base:Integer;
Begin
  W:=ScreenWidth;
  If W>ScreenCols Then
    W:=ScreenCols;
  H:=ScreenHeight;
  If H>ScreenRows Then
    H:=ScreenRows;
  FillWord(VideoBuf^,ScreenWidth*ScreenHeight,$0720);
  For Y:=0 To H-1 Do
    Begin
      Base:=Y*ScreenWidth;
      For X:=0 To W-1 Do
        VideoBuf^[Base+X]:=TextScreen^[Cell(X,Y)] Or
                           (Word(TextScreen^[Cell(X,Y)+1]) Shl 8);
    End;
  If (CurX<ScreenWidth) And (CurY<ScreenHeight) Then
    SetCursorPos(CurX,CurY);
End;

{ render the 320x200 mode $13 frame with "upper half block" characters,
  two pixels per character cell.  each output pixel is the average of the
  source pixels it covers. }
Procedure RenderGraphics;
Const
  UpperHalf=#$E2#$96#$80;
Var
  OutW,OutH,X,Y,SX0,SX1,SY0,SY1,SX,SY,N,C:Integer;
  R,G,B:LongInt;
  Rows,Cols:Integer;
  Px:Array Of Array Of LongInt;
  S:AnsiString;
  Top,Bot,LastTop,LastBot:LongInt;
Begin
  Cols:=ScreenWidth;
  Rows:=ScreenHeight;
  {mode $13 fills a 4:3 display, half blocks give roughly square pixels}
  OutW:=Cols;
  OutH:=(OutW*3) Div 4;
  If OutH>Rows*2 Then
    Begin
      OutH:=Rows*2;
      OutW:=(OutH*4) Div 3;
    End;
  If OutH And 1=1 Then
    Dec(OutH);
  If (OutW<1) Or (OutH<2) Then
    Exit;
  SetLength(Px,OutH,OutW);
  For Y:=0 To OutH-1 Do
    Begin
      SY0:=(Y*200) Div OutH;
      SY1:=((Y+1)*200) Div OutH;
      If SY1<=SY0 Then
        SY1:=SY0+1;
      For X:=0 To OutW-1 Do
        Begin
          SX0:=(X*320) Div OutW;
          SX1:=((X+1)*320) Div OutW;
          If SX1<=SX0 Then
            SX1:=SX0+1;
          R:=0;  G:=0;  B:=0;  N:=0;
          For SY:=SY0 To SY1-1 Do
            For SX:=SX0 To SX1-1 Do
              Begin
                C:=GraphFrame^[SY,SX];
                Inc(R,VGAPal[C,0]);
                Inc(G,VGAPal[C,1]);
                Inc(B,VGAPal[C,2]);
                Inc(N);
              End;
          {6 bit DAC values to 8 bit}
          R:=(R*255) Div (N*63);
          G:=(G*255) Div (N*63);
          B:=(B*255) Div (N*63);
          Px[Y,X]:=(R Shl 16) Or (G Shl 8) Or B;
        End;
    End;

  S:=#27'[0m'#27'[2J';
  For Y:=0 To (OutH Div 2)-1 Do
    Begin
      S:=S+#27'['+IntToStr(Y+1)+';'+IntToStr((Cols-OutW) Div 2+1)+'H';
      LastTop:=-1;  LastBot:=-1;
      For X:=0 To OutW-1 Do
        Begin
          Top:=Px[Y*2,X];
          Bot:=Px[Y*2+1,X];
          If Top<>LastTop Then
            S:=S+#27'[38;2;'+IntToStr(Top Shr 16)+';'+
               IntToStr((Top Shr 8) And $FF)+';'+IntToStr(Top And $FF)+'m';
          If Bot<>LastBot Then
            S:=S+#27'[48;2;'+IntToStr(Bot Shr 16)+';'+
               IntToStr((Bot Shr 8) And $FF)+';'+IntToStr(Bot And $FF)+'m';
          S:=S+UpperHalf;
          LastTop:=Top;
          LastBot:=Bot;
        End;
      S:=S+#27'[0m';
    End;
  RawOut(S);
End;

{ the program writes straight into TextScreen and GraphFrame (as it did
  to video memory), so rather than tracking changes compare against what
  was sent last time.  Video.UpdateScreen does that for the text screen. }
Procedure FlushScreen;
Begin
  If Not VideoUp Then
    Exit;
  If GraphMode Then
    Begin
      If Not WasGraph Then
        Begin
          {let Video know the terminal is about to be scribbled on}
          SetCursorType(crHidden);
          UpdateScreen(False);
        End;
      If (Not WasGraph) Or
         (CompareByte(GraphFrame^,ShadowFrame^,SizeOf(GraphFrameType))<>0) Or
         (CompareByte(VGAPal,ShadowPal,SizeOf(VGAPalType))<>0) Then
        Begin
          RenderGraphics;
          ShadowFrame^:=GraphFrame^;
          ShadowPal:=VGAPal;
        End;
      WasGraph:=True;
    End
  Else
    Begin
      CopyTextToVideo;
      ApplyCursor;
      UpdateScreen(WasGraph);
      WasGraph:=False;
    End;
  If BellPending Then
    Begin
      Beep;
      BellPending:=False;
    End;
  LastFlush:=GetTickCount64;
End;

Procedure EnterGraphMode;
Begin
  If Not GraphMode Then
    FillChar(GraphFrame^,SizeOf(GraphFrameType),0);
  GraphMode:=True;
End;

Procedure LeaveGraphMode;
Begin
  GraphMode:=False;
End;

{----------------------------------------------------------------------}
{ cursor                                                                }
{----------------------------------------------------------------------}

Procedure CursorHide;
Begin
  CursorShape:=crHidden;
End;

Procedure CursorNormal;
Begin
  CursorShape:=crUnderLine;
End;

Procedure CursorBlock;
Begin
  CursorShape:=crBlock;
End;

{----------------------------------------------------------------------}
{ keyboard                                                              }
{----------------------------------------------------------------------}

{ keys are queued the way the BIOS would have given them to us: an ascii
  character, or a zero character with a scan code. }

Const
  KeyQSize=64;
  NoMods=0;
  ModShift=1;
  ModAlt=2;
  ModCtrl=4;

  {scan codes for Alt+letter / Alt+digit}
  AltLetter:Array ['A'..'Z'] Of Byte=(
    $1E,$30,$2E,$20,$12,$21,$22,$23,$17,$24,$25,$26,$32,
    $31,$18,$19,$10,$13,$1F,$14,$16,$2F,$11,$2D,$15,$2C);
  AltDigit:Array ['0'..'9'] Of Byte=(
    $81,$78,$79,$7A,$7B,$7C,$7D,$7E,$7F,$80);

Type
  {keys that have different scan codes depending on shift/ctrl/alt}
  SpecialKey=(skNone,skF1,skF2,skF3,skF4,skF5,skF6,skF7,skF8,skF9,skF10,
              skF11,skF12,skHome,skUp,skPgUp,skLeft,skMiddle,skRight,
              skEnd,skDown,skPgDn,skInsert,skDelete);

Var
  KeyQ:Array [0..KeyQSize-1] Of Word;   {lo = character, hi = scan code}
  KeyHead,KeyTail:Integer;

Procedure QueueKey(Ch,Scan:Byte);
Var N:Integer;
Begin
  N:=(KeyTail+1) Mod KeyQSize;
  If N=KeyHead Then
    Exit;                                {full, like the BIOS: beep and drop}
  KeyQ[KeyTail]:=Ch Or (Word(Scan) Shl 8);
  KeyTail:=N;
End;

Procedure QueueSpecial(K:SpecialKey; Mods:Byte);
Var S:Byte;
Begin
  S:=0;
  Case K Of
    skF1..skF10:
      If (Mods And ModAlt)<>0 Then
        S:=$68+Ord(K)-Ord(skF1)
      Else If (Mods And ModCtrl)<>0 Then
        S:=$5E+Ord(K)-Ord(skF1)
      Else If (Mods And ModShift)<>0 Then
        S:=$54+Ord(K)-Ord(skF1)
      Else
        S:=$3B+Ord(K)-Ord(skF1);
    skF11: If (Mods And ModAlt)<>0 Then S:=$8B
           Else If (Mods And ModCtrl)<>0 Then S:=$89
           Else If (Mods And ModShift)<>0 Then S:=$87
           Else S:=$85;
    skF12: If (Mods And ModAlt)<>0 Then S:=$8C
           Else If (Mods And ModCtrl)<>0 Then S:=$8A
           Else If (Mods And ModShift)<>0 Then S:=$88
           Else S:=$86;
    skHome:   If (Mods And ModCtrl)<>0 Then S:=$77 Else S:=$47;
    skUp:     If (Mods And ModCtrl)<>0 Then S:=$8D Else S:=$48;
    skPgUp:   If (Mods And ModCtrl)<>0 Then S:=$84 Else S:=$49;
    skLeft:   If (Mods And ModCtrl)<>0 Then S:=$73 Else S:=$4B;
    skMiddle: S:=$4C;
    skRight:  If (Mods And ModCtrl)<>0 Then S:=$74 Else S:=$4D;
    skEnd:    If (Mods And ModCtrl)<>0 Then S:=$75 Else S:=$4F;
    skDown:   If (Mods And ModCtrl)<>0 Then S:=$91 Else S:=$50;
    skPgDn:   If (Mods And ModCtrl)<>0 Then S:=$76 Else S:=$51;
    skInsert: If (Mods And ModCtrl)<>0 Then S:=$92 Else S:=$52;
    skDelete: If (Mods And ModCtrl)<>0 Then S:=$93 Else S:=$53;
  End;
  If S=0 Then
    Exit;
  If (K=skInsert) And ((Mods And (ModShift Or ModCtrl))=0) Then
    InsertOn:=Not InsertOn;
  LastShift:=0;
  If (Mods And ModShift)<>0 Then
    LastShift:=LastShift Or KBLShift;
  If (Mods And ModCtrl)<>0 Then
    LastShift:=LastShift Or KBCtrl;
  If (Mods And ModAlt)<>0 Then
    LastShift:=LastShift Or KBAlt;
  QueueKey(0,S);
End;

{ a plain character, possibly with Alt held down }
Procedure QueueChar(C:Char; Alt:Boolean);
Begin
  LastShift:=0;
  If Alt Then
    Begin
      LastShift:=KBAlt;
      If UpCase(C) In ['A'..'Z'] Then
        Begin
          QueueKey(0,AltLetter[UpCase(C)]);
          Exit;
        End;
      If C In ['0'..'9'] Then
        Begin
          QueueKey(0,AltDigit[C]);
          Exit;
        End;
      QueueKey(27,0);     {no BIOS code for it, so it's just Esc then the key}
    End;
  If C In ['A'..'Z'] Then
    LastShift:=LastShift Or KBLShift;
  QueueKey(Byte(C),0);
End;

{$IFDEF UNIX}

{----------------------------------------------------------------------}
{ unix terminals send keys as bytes and escape sequences, which we     }
{ decode here.  (the Keyboard unit treats a lone Esc as the start of   }
{ an Alt key and waits for another key, which is no good for hexed     }
{ where Esc means cancel.)                                              }
{----------------------------------------------------------------------}

Const
  EscTimeout=40;            {ms to wait for the rest of an escape sequence}

Var
  InFD:CInt;                {where keys come from, normally stdin}
  SavedTio:Termios;
  RawModeOn:Boolean;
  InBuf:Array [0..1023] Of Byte;
  InLen:Integer;
  MouseOn:Boolean;

Procedure SetRawMode(On:Boolean);
Var Tio:Termios;
Begin
  If On=RawModeOn Then
    Exit;
  If On Then
    Begin
      If TCGetAttr(InFD,SavedTio)<>0 Then
        Exit;
      Tio:=SavedTio;
      CFMakeRaw(Tio);
      TCSetAttr(InFD,TCSANOW,Tio);
    End
  Else
    TCSetAttr(InFD,TCSANOW,SavedTio);
  RawModeOn:=On;
End;

{ read whatever is waiting on stdin, waiting up to Timeout ms (-1 for
  ever) for something to show up.  returns true if anything was read. }
Function FillInput(Timeout:LongInt):Boolean;
Var
  FDs:TFDSet;
  N:TSSize;
Begin
  FillInput:=False;
  If InLen>=SizeOf(InBuf) Then
    Exit;
  fpFD_ZERO(FDs);
  fpFD_SET(InFD,FDs);
  If Timeout<0 Then
    N:=fpSelect(InFD+1,@FDs,Nil,Nil,Nil)
  Else
    N:=fpSelect(InFD+1,@FDs,Nil,Nil,Timeout);
  If N<=0 Then
    Exit;
  N:=fpRead(InFD,InBuf[InLen],SizeOf(InBuf)-InLen);
  If N<=0 Then
    Exit;
  Inc(InLen,N);
  FillInput:=True;
End;

Procedure Consume(N:Integer);
Begin
  If N>=InLen Then
    InLen:=0
  Else
    Begin
      Move(InBuf[N],InBuf[0],InLen-N);
      Dec(InLen,N);
    End;
End;

{ xterm style "1;5" parameters: the second number is 1 + modifier bits }
Procedure ParseParams(Const P:String; Var P1,P2:Integer);
Var I:Integer;
Begin
  P1:=0;  P2:=0;
  I:=1;
  While (I<=Length(P)) And (P[I] In ['0'..'9']) Do
    Begin
      P1:=P1*10+Ord(P[I])-Ord('0');
      Inc(I);
    End;
  If (I<=Length(P)) And (P[I]=';') Then
    Begin
      Inc(I);
      While (I<=Length(P)) And (P[I] In ['0'..'9']) Do
        Begin
          P2:=P2*10+Ord(P[I])-Ord('0');
          Inc(I);
        End;
    End;
End;

Function XtermMods(P2:Integer):Byte;
Begin
  If P2>1 Then
    XtermMods:=(P2-1) And (ModShift Or ModAlt Or ModCtrl)
  Else
    XtermMods:=NoMods;
End;

Procedure MouseReport(B,X,Y:Integer; Press:Boolean);
Var Btn:Integer;
Begin
  MouseCol:=X-1;
  MouseRow:=Y-1;
  If (B And 64)<>0 Then
    Exit;                                   {wheel}
  If (B And 32)<>0 Then
    Exit;                                   {motion}
  Case B And 3 Of
    0 : Btn:=0;                             {left}
    1 : Btn:=2;                             {middle is the DOS "center"}
    2 : Btn:=1;                             {right}
  Else
    Exit;
  End;
  If Press Then
    Begin
      Inc(MousePress[Btn]);
      MouseDown[Btn]:=True;
    End
  Else
    Begin
      Inc(MouseRelease[Btn]);
      MouseDown[Btn]:=False;
    End;
End;

{ ESC [ ... : returns the number of bytes used, 0 if incomplete }
Function ParseCSI:Integer;
Var
  I,P1,P2,MB,MX,MY,Code:Integer;
  P:String;
  F:Char;
  M:Byte;
Begin
  ParseCSI:=0;
  {linux console F1-F5: ESC [ [ A..E}
  If (InLen>=3) And (InBuf[2]=Ord('[')) Then
    Begin
      If InLen<4 Then
        Exit;
      If Char(InBuf[3]) In ['A'..'E'] Then
        QueueSpecial(SpecialKey(Ord(skF1)+InBuf[3]-Ord('A')),NoMods);
      ParseCSI:=4;
      Exit;
    End;
  I:=2;
  While (I<InLen) And Not (InBuf[I] In [$40..$7E]) Do
    Inc(I);
  If I>=InLen Then
    Begin
      If InLen>=32 Then
        ParseCSI:=InLen;                 {garbage, throw it away}
      Exit;
    End;
  ParseCSI:=I+1;
  SetLength(P,I-2);
  If I>2 Then
    Move(InBuf[2],P[1],I-2);
  F:=Char(InBuf[I]);

  {SGR mouse: ESC [ < b ; x ; y M/m}
  If (P<>'') And (P[1]='<') Then
    Begin
      Delete(P,1,1);
      MB:=0;  MX:=0;  MY:=0;
      Val(Copy(P,1,Pos(';',P)-1),MB,Code);
      Delete(P,1,Pos(';',P));
      Val(Copy(P,1,Pos(';',P)-1),MX,Code);
      Delete(P,1,Pos(';',P));
      Val(P,MY,Code);
      If F In ['M','m'] Then
        MouseReport(MB,MX,MY,F='M');
      Exit;
    End;

  ParseParams(P,P1,P2);
  M:=XtermMods(P2);
  Case F Of
    'A' : QueueSpecial(skUp,M);
    'B' : QueueSpecial(skDown,M);
    'C' : QueueSpecial(skRight,M);
    'D' : QueueSpecial(skLeft,M);
    'E' : QueueSpecial(skMiddle,M);
    'H' : QueueSpecial(skHome,M);
    'F' : QueueSpecial(skEnd,M);
    'P' : QueueSpecial(skF1,M);
    'Q' : QueueSpecial(skF2,M);
    'R' : QueueSpecial(skF3,M);
    'S' : QueueSpecial(skF4,M);
    'Z' : Begin
            LastShift:=KBLShift;
            QueueKey(0,$0F);           {shift-tab}
          End;
    '~' : Case P1 Of
            1,7  : QueueSpecial(skHome,M);
            2    : QueueSpecial(skInsert,M);
            3    : QueueSpecial(skDelete,M);
            4,8  : QueueSpecial(skEnd,M);
            5    : QueueSpecial(skPgUp,M);
            6    : QueueSpecial(skPgDn,M);
            11..15 : QueueSpecial(SpecialKey(Ord(skF1)+P1-11),M);
            17..21 : QueueSpecial(SpecialKey(Ord(skF6)+P1-17),M);
            23   : QueueSpecial(skF11,M);
            24   : QueueSpecial(skF12,M);
            25,26 : QueueSpecial(SpecialKey(Ord(skF3)+P1-25),M Or ModShift);
            28,29 : QueueSpecial(SpecialKey(Ord(skF5)+P1-28),M Or ModShift);
            31..34 : QueueSpecial(SpecialKey(Ord(skF7)+P1-31),M Or ModShift);
          End;
  End;
End;

{ ESC O x : returns the number of bytes used, 0 if incomplete }
Function ParseSS3:Integer;
Var
  I,M:Integer;
Begin
  ParseSS3:=0;
  {some terminals send modifiers as ESC O 5 P}
  I:=2;
  M:=0;
  While (I<InLen) And (InBuf[I] In [Ord('0')..Ord('9')]) Do
    Begin
      M:=M*10+InBuf[I]-Ord('0');
      Inc(I);
    End;
  If I>=InLen Then
    Exit;
  ParseSS3:=I+1;
  Case Char(InBuf[I]) Of
    'A' : QueueSpecial(skUp,XtermMods(M));
    'B' : QueueSpecial(skDown,XtermMods(M));
    'C' : QueueSpecial(skRight,XtermMods(M));
    'D' : QueueSpecial(skLeft,XtermMods(M));
    'E' : QueueSpecial(skMiddle,XtermMods(M));
    'H' : QueueSpecial(skHome,XtermMods(M));
    'F' : QueueSpecial(skEnd,XtermMods(M));
    'P' : QueueSpecial(skF1,XtermMods(M));
    'Q' : QueueSpecial(skF2,XtermMods(M));
    'R' : QueueSpecial(skF3,XtermMods(M));
    'S' : QueueSpecial(skF4,XtermMods(M));
    'M' : QueueKey(13,0);                 {keypad enter}
  End;
End;

Function CP437Of(CodePoint:LongInt):Char; forward;

{ a UTF-8 character: returns bytes used, 0 if incomplete }
Function ParseUTF8:Integer;
Var
  N,I:Integer;
  CP:LongInt;
Begin
  ParseUTF8:=1;
  Case InBuf[0] Of
    $C0..$DF : N:=2;
    $E0..$EF : N:=3;
    $F0..$F7 : N:=4;
  Else
    Exit;                                  {stray byte, drop it}
  End;
  If InLen<N Then
    Begin
      ParseUTF8:=0;
      Exit;
    End;
  CP:=InBuf[0] And ($7F Shr N);
  For I:=1 To N-1 Do
    CP:=(CP Shl 6) Or (InBuf[I] And $3F);
  QueueChar(CP437Of(CP),False);
  ParseUTF8:=N;
End;

{ decode as much of InBuf as we can.  when Final is set an escape that is
  still incomplete is taken to be the Esc key (possibly with Alt). }
Procedure DecodeInput(Final:Boolean);
Var
  Used:Integer;
  B:Byte;
Begin
  While InLen>0 Do
    Begin
      B:=InBuf[0];
      Used:=1;
      If B=27 Then
        Begin
          If InLen=1 Then
            Used:=0
          Else If InBuf[1]=Ord('[') Then
            Used:=ParseCSI
          Else If InBuf[1]=Ord('O') Then
            Used:=ParseSS3
          Else If InBuf[1]=27 Then
            Begin
              QueueKey(27,0);
              Used:=1;
            End
          Else If InBuf[1]<$80 Then
            Begin
              {meta sends escape: Alt+key}
              QueueChar(Char(InBuf[1]),True);
              Used:=2;
            End
          Else
            Begin
              QueueKey(27,0);
              Used:=1;
            End;
          If (Used=0) And Final Then
            Begin
              QueueKey(27,0);
              Used:=1;
            End;
        End
      Else If B>=$80 Then
        Used:=ParseUTF8
      Else If B=127 Then
        QueueKey(8,0)                        {backspace}
      Else
        QueueChar(Char(B),False);
      If Used=0 Then
        Exit;
      Consume(Used);
    End;
End;

{ collect and decode input; Wait is how long to wait for the first byte }
Procedure PumpInput(Wait:LongInt);
Begin
  If Not FillInput(Wait) Then
    Begin
      DecodeInput(InLen>0);
      Exit;
    End;
  {read the rest of a burst so escape sequences arrive in one piece}
  While FillInput(0) Do
    ;
  DecodeInput(False);
  If (InLen>0) And (InBuf[0]=27) Then
    Begin
      {the start of an escape sequence; give the rest a moment to arrive}
      While FillInput(EscTimeout) Do
        DecodeInput(False);
      DecodeInput(True);
    End;
End;

Procedure MouseTracking(On:Boolean);
Begin
  If On Then
    RawOut(#27'[?1000h'#27'[?1006h')
  Else
    RawOut(#27'[?1006l'#27'[?1000l');
End;

{ hexed -i reads file names from stdin; DOS read the keyboard through
  the BIOS whatever stdin was, so do the same with the terminal }
Procedure OpenInput;
Begin
  If InFD>0 Then
    Exit;
  InFD:=0;
  If IsATTY(0)<>1 Then
    Begin
      InFD:=fpOpen('/dev/tty',O_RDWR);
      If InFD<0 Then
        InFD:=0;
    End;
End;

{ the Video unit only sets up the terminal when stdin is one, so when it
  isn't lend it the terminal while it looks }
Var
  LentStdin:CInt;

Procedure BorrowStdin;
Begin
  OpenInput;
  LentStdin:=-1;
  If InFD<>0 Then
    Begin
      LentStdin:=fpDup(0);
      fpDup2(InFD,0);
    End;
End;

Procedure ReturnStdin;
Begin
  If LentStdin>=0 Then
    Begin
      fpDup2(LentStdin,0);
      fpClose(LentStdin);
      LentStdin:=-1;
    End;
End;

Procedure StartInput;
Begin
  InLen:=0;
  OpenInput;
  SetRawMode(True);
  If MouseOn Then
    MouseTracking(True);
End;

Procedure StopInput;
Begin
  If MouseOn Then
    MouseTracking(False);
  SetRawMode(False);
End;

Procedure EnableMouse;
Begin
  If Not MouseOn Then
    Begin
      MouseOn:=True;
      MouseTracking(True);
    End;
End;

{$ELSE}

{----------------------------------------------------------------------}
{ everywhere else the Keyboard and Mouse units hand us key events      }
{----------------------------------------------------------------------}

Var
  MouseOn:Boolean;

Function FPCKeyToSpecial(Code:Word):SpecialKey;
Begin
  Case Code Of
    kbdF1..kbdF10 : FPCKeyToSpecial:=SpecialKey(Ord(skF1)+Code-kbdF1);
    kbdF11    : FPCKeyToSpecial:=skF11;
    kbdF12    : FPCKeyToSpecial:=skF12;
    kbdHome   : FPCKeyToSpecial:=skHome;
    kbdUp     : FPCKeyToSpecial:=skUp;
    kbdPgUp   : FPCKeyToSpecial:=skPgUp;
    kbdLeft   : FPCKeyToSpecial:=skLeft;
    kbdMiddle : FPCKeyToSpecial:=skMiddle;
    kbdRight  : FPCKeyToSpecial:=skRight;
    kbdEnd    : FPCKeyToSpecial:=skEnd;
    kbdDown   : FPCKeyToSpecial:=skDown;
    kbdPgDn   : FPCKeyToSpecial:=skPgDn;
    kbdInsert : FPCKeyToSpecial:=skInsert;
    kbdDelete : FPCKeyToSpecial:=skDelete;
  Else
    FPCKeyToSpecial:=skNone;
  End;
End;

Procedure QueueKeyEvent(K:TKeyEvent);
Var
  Code:Word;
  C:Char;
  Shift,M:Byte;
Begin
  If GetKeyEventFlags(K)=kbPhys Then
    Begin
      {already in BIOS form}
      Code:=GetKeyEventCode(K);
      If (Lo(Code)=0) And (Hi(Code)=$52) Then
        InsertOn:=Not InsertOn;
      QueueKey(Lo(Code),Hi(Code));
      Exit;
    End;
  K:=TranslateKeyEvent(K);
  Shift:=GetKeyEventShiftState(K);
  M:=NoMods;
  If (Shift And kbShift)<>0 Then
    M:=M Or ModShift;
  If (Shift And Keyboard.kbCtrl)<>0 Then
    M:=M Or ModCtrl;
  If (Shift And Keyboard.kbAlt)<>0 Then
    M:=M Or ModAlt;
  Code:=GetKeyEventCode(K);
  C:=GetKeyEventChar(K);
  If (Code And $FF00)=$FF00 Then
    QueueSpecial(FPCKeyToSpecial(Code),M)
  Else If (C=#9) And ((M And ModShift)<>0) Then
    QueueKey(0,$0F)
  Else If C<>#0 Then
    QueueChar(C,(M And ModAlt)<>0)
  Else If Hi(Code)<>0 Then
    QueueKey(0,Hi(Code));
End;

Procedure PumpMouseEvents;
Var
  E:TMouseEvent;
  I:Integer;
Const
  Mask:Array [0..2] Of Word=(MouseLeftButton,MouseRightButton,
                             MouseMiddleButton);
Begin
  While PollMouseEvent(E) Do
    Begin
      GetMouseEvent(E);
      MouseCol:=E.X;
      MouseRow:=E.Y;
      For I:=0 To 2 Do
        If ((E.Buttons And Mask[I])<>0) And Not MouseDown[I] Then
          Begin
            Inc(MousePress[I]);
            MouseDown[I]:=True;
          End
        Else If ((E.Buttons And Mask[I])=0) And MouseDown[I] Then
          Begin
            Inc(MouseRelease[I]);
            MouseDown[I]:=False;
          End;
    End;
End;

Procedure PumpInput(Wait:LongInt);
Var
  K:TKeyEvent;
  Waited:LongInt;
Begin
  Waited:=0;
  Repeat
    If MouseOn Then
      PumpMouseEvents;
    K:=PollKeyEvent;
    If K<>0 Then
      Begin
        QueueKeyEvent(GetKeyEvent);
        Exit;
      End;
    If (Wait>=0) And (Waited>=Wait) Then
      Exit;
    Sleep(10);
    Inc(Waited,10);
  Until KeyHead<>KeyTail;
End;

Procedure StartInput;
Begin
  InitKeyboard;
  If MouseOn Then
    InitMouse;
End;

Procedure StopInput;
Begin
  If MouseOn Then
    DoneMouse;
  DoneKeyboard;
End;

Procedure EnableMouse;
Begin
  If Not MouseOn Then
    Begin
      InitMouse;
      MouseOn:=DetectMouse>0;
    End;
End;

{$ENDIF}

Function PollKey:Boolean;
Begin
  If KeyHead=KeyTail Then
    PumpInput(0);
  PollKey:=KeyHead<>KeyTail;
End;

Function KeyPressed:Boolean;
Var Now:QWord;
Begin
  Now:=GetTickCount64;
  {a full graphics frame is a lot of escape codes, don't send it as often}
  If (GraphMode And (Now-LastFlush>=250)) Or
     (Not GraphMode And (Now-LastFlush>=30)) Then
    FlushScreen;
  KeyPressed:=PollKey;
End;

Function ReadKey:Char;
Var W:Word;
Begin
  If PendingScan<>#0 Then
    Begin
      ReadKey:=PendingScan;
      PendingScan:=#0;
      Exit;
    End;
  FlushScreen;
  While KeyHead=KeyTail Do
    PumpInput(-1);
  W:=KeyQ[KeyHead];
  KeyHead:=(KeyHead+1) Mod KeyQSize;
  If Lo(W)=0 Then
    PendingScan:=Char(Hi(W));
  ReadKey:=Char(Lo(W));
End;

Function ShiftFlags:Byte;
Begin
  PollKey;
  If InsertOn Then
    ShiftFlags:=LastShift Or KBInsert
  Else
    ShiftFlags:=LastShift;
End;

Procedure IdleWait;
Begin
  FlushScreen;
  If KeyHead=KeyTail Then
    PumpInput(10);
End;

Procedure Delay(MS:Word);
Begin
  FlushScreen;
  Sleep(MS);
End;

Procedure Sound(Hz:Word);
Begin
End;

Procedure NoSound;
Begin
End;

{----------------------------------------------------------------------}
{ mouse                                                                 }
{----------------------------------------------------------------------}

{DOS mouse driver button numbers: 0 left, 1 right, 2 center}
Function MousePressCount(Button:Word):Word;
Begin
  MousePressCount:=0;
  If Not MouseOn Or (Button>2) Then
    Exit;
  PollKey;
  MousePressCount:=MousePress[Button];
  MousePress[Button]:=0;
End;

Function MouseReleaseCount(Button:Word):Word;
Begin
  MouseReleaseCount:=0;
  If Not MouseOn Or (Button>2) Then
    Exit;
  PollKey;
  MouseReleaseCount:=MouseRelease[Button];
  MouseRelease[Button]:=0;
End;

Function MouseInstalled:Boolean;
Begin
  MouseInstalled:=MouseOn;
End;

Function MousePixelX:Word;
Begin
  PollKey;
  MousePixelX:=MouseCol*8;
End;

Function MousePixelY:Word;
Begin
  PollKey;
  MousePixelY:=MouseRow*8;
End;

{----------------------------------------------------------------------}
{ memory                                                                }
{----------------------------------------------------------------------}

Function MemAvail:LongInt;
Begin
  MemAvail:=MaxLongInt;
End;

Function MaxAvail:LongInt;
Begin
  MaxAvail:=MaxLongInt;
End;

{----------------------------------------------------------------------}
{ start up and shut down                                                }
{----------------------------------------------------------------------}

Const
  {code page 437 as UTF-8, used for the parting screen dump}
  CP437:Array [0..255] Of String[3]=(
    ' ','☺','☻','♥','♦','♣','♠','•','◘','○','◙','♂','♀','♪','♫','☼',
    '►','◄','↕','‼','¶','§','▬','↨','↑','↓','→','←','∟','↔','▲','▼',
    ' ','!','"','#','$','%','&','''','(',')','*','+',',','-','.','/',
    '0','1','2','3','4','5','6','7','8','9',':',';','<','=','>','?',
    '@','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O',
    'P','Q','R','S','T','U','V','W','X','Y','Z','[','\',']','^','_',
    '`','a','b','c','d','e','f','g','h','i','j','k','l','m','n','o',
    'p','q','r','s','t','u','v','w','x','y','z','{','|','}','~','⌂',
    'Ç','ü','é','â','ä','à','å','ç','ê','ë','è','ï','î','ì','Ä','Å',
    'É','æ','Æ','ô','ö','ò','û','ù','ÿ','Ö','Ü','¢','£','¥','₧','ƒ',
    'á','í','ó','ú','ñ','Ñ','ª','º','¿','⌐','¬','½','¼','¡','«','»',
    '░','▒','▓','│','┤','╡','╢','╖','╕','╣','║','╗','╝','╜','╛','┐',
    '└','┴','┬','├','─','┼','╞','╟','╚','╔','╩','╦','╠','═','╬','╧',
    '╨','╤','╥','╙','╘','╒','╓','╫','╪','┘','┌','█','▄','▌','▐','▀',
    'α','ß','Γ','π','Σ','σ','µ','τ','Φ','Θ','Ω','δ','∞','φ','ε','∩',
    '≡','±','≥','≤','⌠','⌡','÷','≈','°','∙','·','√','ⁿ','²','■',' ');

{ typed characters come in as unicode; find the code page 437 one }
Function CP437Of(CodePoint:LongInt):Char;
Var
  I:Integer;
  U:String[4];
Begin
  CP437Of:='?';
  If CodePoint<128 Then
    Begin
      CP437Of:=Char(CodePoint);
      Exit;
    End;
  {encode as UTF-8 and look it up in the table}
  If CodePoint<$800 Then
    U:=Char($C0 Or (CodePoint Shr 6))+Char($80 Or (CodePoint And $3F))
  Else If CodePoint<$10000 Then
    U:=Char($E0 Or (CodePoint Shr 12))+Char($80 Or ((CodePoint Shr 6) And $3F))+
       Char($80 Or (CodePoint And $3F))
  Else
    Exit;
  For I:=128 To 255 Do
    If CP437[I]=U Then
      Begin
        CP437Of:=Char(I);
        Exit;
      End;
End;

{ when a DOS program exits, whatever it last wrote stays on the screen.
  hexed relies on that for its help text and the parting message, so
  once the terminal is back to normal print the rows above the cursor. }
Procedure DumpScreen;
Var
  X,Y,Last:Integer;
  S:AnsiString;
Begin
  For Y:=0 To CurY Do
    Begin
      Last:=-1;
      For X:=0 To ScreenCols-1 Do
        If TextScreen^[Cell(X,Y)]<>32 Then
          Last:=X;
      S:='';
      For X:=0 To Last Do
        S:=S+CP437[TextScreen^[Cell(X,Y)]];
      {the cursor line only counts if something is on it}
      If (Y<CurY) Or (Last>=0) Then
        RawOut(S+LineEnding);
    End;
End;

Procedure StartConsole;
Begin
  {$IFDEF UNIX}
  {work on the alternate screen so the shell's screen comes back after}
  RawOut(#27'[?1049h');
  BorrowStdin;
  {$ENDIF}
  InitVideo;
  {$IFDEF UNIX}
  ReturnStdin;
  {$ENDIF}
  {$IFDEF WINDOWS}
  EnableVTOutput;
  {$ENDIF}
  StartInput;
  VideoUp:=True;
  WasGraph:=True;   {forces a full redraw}
End;

Procedure StopConsole;
Begin
  If Not VideoUp Then
    Exit;
  VideoUp:=False;
  SetCursorType(crUnderLine);
  StopInput;
  {$IFDEF UNIX}
  BorrowStdin;
  {$ENDIF}
  DoneVideo;
  {$IFDEF UNIX}
  ReturnStdin;
  RawOut(#27'[?1049l');
  {$ENDIF}
  DumpScreen;
End;

{ give the terminal back, e.g. to run a shell.  anything written to the
  screen beforehand is left on the terminal like DOS would have. }
Procedure SuspendConsole;
Begin
  StopConsole;
End;

Procedure ResumeConsole;
Begin
  If Not VideoUp Then
    StartConsole;
End;

Initialization
  New(TextScreen);
  New(GraphFrame);
  New(ShadowFrame);
  FillChar(VGAPal,SizeOf(VGAPal),0);
  TextAttr:=NormAttr;
  CheckBreak:=True;
  DirectVideo:=True;
  LastMode:=3;
  CursorShape:=crUnderLine;
  PendingScan:=#0;
  InsertOn:=False;       {the BIOS starts with insert off}
  SetScreenRows(25);
  ClrScr;

  StartConsole;

  AssignCrt(Output);
  Rewrite(Output);
  AssignCrt(Input);
  Reset(Input);

Finalization
  StopConsole;
End.
