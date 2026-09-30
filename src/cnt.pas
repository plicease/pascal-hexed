(*============================================================================
| cnt.pas
|   procedure to write contact message to the screen.  this gives my e-mail
|   address out and the like.  oh joy.
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$PACKRECORDS 1}

Unit CNT;

INTERFACE

Procedure WriteContactMsg;

IMPLEMENTATION

Uses
  Ollis,VCrt,Header,CFG,Cursor;

Procedure WriteContactMsg;
Begin
  HideMC;
  TextAttr:=SaveTextAttr;
  TextAttr:=Black * $10 or LightGray;
  Window(1,1,80,25);
  ClrScr;
  TextColor(Green);
  Write('Graham ');
  TextColor(White);
  Write(':');
  TextColor(LightGray);
  Write(' Thanks for using ');
  TextColor(White);
  Write('HEXED ');
  TextColor(LightGray);
  Write('(');
  TextColor(Brown);
  Write('HEX');
  TextColor(LightGray);
  Write('adecimal ');
  TextColor(Brown);
  Write('ED');
  TextColor(LightGray);
  Writeln('itor) by Graham Ollis.');
  Writeln('version ',versionnumber,'.  If you have any questions, coments, bugs, etc.');
  Write('you can contact me by e-mail.  You are incouraged to register ');
  TextColor(White);
  Write('HEXED');
  TextColor(LightGray);
  Writeln('.');
  Writeln('At the DOS prompt type "type readme.doc | more" for more info.');
  Writeln;
  TextColor(White);
  Writeln('INTERNET:');
  TextColor(Magenta);
  Writeln('ollisg@ns.arizona.edu');
  Writeln('ollisg@idea-bank.com');
  Writeln('ollisg@lanl.gov');
  TextAttr:=SaveTextAttr;
  ShowCursor;
End;

End.
