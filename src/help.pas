(*============================================================================
| help.pas
|    display the helpful help window.
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$I-}
{$PACKRECORDS 1}

Unit Help;

INTERFACE

Uses
  Header;

{++PROCEDURES++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Procedure WriteHelp(Var hp:HelpPointer);
Procedure WriteHelpWindow;

{++FUNCTIONS+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Function LoadHelp(Var hp:HelpPointer):Boolean;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

IMPLEMENTATION

Uses
  CFG,VCrt,OUTCRT;

{----------------------------------------------------------------------}

Procedure WriteHelpWindow;
Var index,index2:Integer;
Begin
  TextAttr:=ICFG.HelpWindow;
  Window(1,HelpY1-1,80,HelpY2+1);
  Write(#201);
  For index:=2 To 79 Do
    Write(#205);
  Write(#187);
  For index:=HelpY1 To HelpY2-1 Do
    Begin
      Write(#186);
      For index2:=2 To 79 Do
        Write(' ');
      Write(#186);
    End;
  Write(#200);
  For index:=2 To 79 Do
    Write(#205);
  Write(#188);
  Window(1,1,80,25);
End;

{----------------------------------------------------------------------}

Function LoadHelp(Var hp:HelpPointer):Boolean;
Var F:Text; index:Integer;
Begin
  LoadHelp:=False;
  If MaxAvail<SizeOf(HelpType) Then
    Exit;
  New(hp);
  If HelpDir='' Then
    Assign(F,HelpFile)
  Else
    Assign(F,HelpDir+DirectorySeparator+HelpFile);
  Reset(F);
  If IOResult<>0 Then
    Begin
      GoToXY(1,HelpY1-1);
      If HelpDir='' Then
        Writeln('Could not find help file ',HelpFile)
      Else
        Writeln('Could not find help file ',HelpDir+DirectorySeparator+HelpFile);
      Exit;
    End;
  For index:=1 To MaxHelp-1 Do
    hp^.S[index]:=' ~';
  hp^.S[MaxHelp]:=' END OF HELP';
  index:=1;
  While (Not EOF(F)) And (index<=MaxHelp) Do
    Begin
      Readln(F,hp^.S[index]);
      index:=index+1;
    End;
  Close(F);

  WriteHelpWindow;

  LoadHelp:=True;
  Hp^.Y:=1;
End;

{------------------------------------------------------------------------}

Procedure WriteHelp(Var hp:HelpPointer);
Var index:Integer;  I:Integer;
Begin
  If hp=Nil Then
    If Not LoadHelp(hp) Then
      Exit;
  Window(2,HelpY1,79,HelpY2-1);
  TextAttr:=ICFG.HelpColor;
  Window(2,HelpY1,79,HelpY2);
  I:=0;
  For index:=hp^.Y To hp^.Y+HelpY2-HelpY1-1 Do
    If index<MaxHelp+1 Then
      Begin
        Write(hp^.S[index]);
        ClrEol;
        Writeln;
        I:=I+1;
      End;
  Window(1,1,80,25);
End;

{======================================================================}

End.
