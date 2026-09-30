(*============================================================================
| mousein.pas
|   handle the mouse input.  supposed to be like keyin is to the keyboard,
|   but last time i tested it, didn't work.  *sigh*
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$I-}
{$PACKRECORDS 1}

Unit MouseIN;

INTERFACE

Uses
  Header;

{++PROCEDURES++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Procedure MInput(Var D:DataType; Var hp:HelpPointer; wb:Byte);

{++FUNCTIONS+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

IMPLEMENTATION

Uses
  Ollis,CFG,VCrt,OutCRT,UModify,BinED,Help,KeyIn;

{----------------------------------------------------------------------}

Procedure MInput(Var D:DataType; Var hp:HelpPointer; wb:Byte);
Var X,Y:Integer;   First:Boolean;
Begin
  HideMC;
  X:=GetMouseX div 8+1;  Y:=GetMouseY div 8+1;
  First:=True;
  If (wb=LeftButton) And (Y>0) And (Y<4) And (X<76) Then
    Repeat
      If First Then
        Begin
          Delay(75);
          First:=False;
        End;
      X:=GetMouseX div 8+1;  Y:=GetMouseY div 8+1;
      Delay(15);
      D.X:=D.X+(X div 3)-12;
      DefaultOutPut;
    Until MouseButtonReleased(LeftButton);
    If wb=RightButton Then
      If (D.X+(X div 3)-12>=1) And (D.X+(X div 3)-12<D.EOF) And
         (Y<4) Then
        If (Y=1) Or (Y=2) Then
          HexModify(D.D^[D.X+(X div 3)-12],D.X+(X div 3)-12,D)
        Else
          CharModify(D.D^[D.X+(X div 3)-12],D.X+(X div 3)-12,D);
    If wb=CenterButton Then
      If (D.X+(X div 3)-12>=1) And (D.X+(X div 3)-12<ImageSize-1) And
         (Y<4) Then
        BinaryEditor(D.D^[D.X+(X div 3)-12],D);
    If (hp<>Nil) And (wb=LeftButton) And (Y=11) Then
      Repeat
        hp^.Y:=hp^.Y-1;
        If hp^.Y<1 Then
          hp^.Y:=1;
        WriteHelp(hp);
        Delay(25);
      Until MouseButtonReleased(LeftButton);
    If (hp<>Nil) And (wb=LeftButton) And (Y=24) Then
      Repeat
        hp^.Y:=hp^.Y+1;
        If hp^.Y>MaxHelp-12 Then
          hp^.Y:=MaxHelp-12;
        WriteHelp(hp);
        Delay(25);
      Until MouseButtonReleased(LeftButton);
    If (wb=LeftButton) And (Y=5) Then
      Begin
        C1:=' ';
        Commands(D,hp);
        C1:=#0;
      End;
    If (wb=LeftButton) And (Y>=6) And (Y<=9) Then
      Begin
        C1:='P';
        Commands(D,hp);
        C1:=#0;
      End;
    If (wb=RightButton) And (Y>=6) And (Y<=9) Then
      Begin
        C1:='D';
        Commands(D,hp);
        C1:=#0;
      End;
    If (wb=RightButton) And (Y=5) Then
      Begin
        C1:=#13;
        Commands(D,hp);
        C1:=#0;
      End;
    If (wb=CenterButton) And (Y=5) Then
      Begin
        C1:='A';
        Commands(D,hp);
        C1:=#0;
      End;
  ShowMC;
  DefaultOutPut;
End;

{======================================================================}

End.
