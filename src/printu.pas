(*============================================================================
| printu.pas
|     printer module for printing out bianry data.
|     NOTE: this is printer as in LINE printer.
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$I-}
{$PACKRECORDS 1}

Unit PrintU;

INTERFACE

Uses
  Header;

{++PROCEDURES++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Procedure PrintPage(Var D:DataType;  Start:LongInt; Var Printer:TEXT);
Procedure Print(Var D:DataType);

{++FUNCTIONS+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Function Byte2Bin(B:Byte):BinString;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

IMPLEMENTATION

Uses
  ViewU,OutCRT,VConvert,CFG,VCrt,UModify;

{----------------------------------------------------------------------}

Function Byte2Bin(B:Byte):BinString;
Var
  Answer:BinString;
Begin
 Answer:='';
 If Boolean(Bit8 And B) Then
   Answer:=Answer+'1'
 Else
   Answer:=Answer+'0';
 If Boolean(Bit7 And B) Then
   Answer:=Answer+'1'
 Else
   Answer:=Answer+'0';
 If Boolean(Bit6 And B) Then
   Answer:=Answer+'1'
 Else
   Answer:=Answer+'0';
 If Boolean(Bit5 And B) Then
   Answer:=Answer+'1'
 Else
   Answer:=Answer+'0';
 If Boolean(Bit4 And B) Then
   Answer:=Answer+'1'
 Else
   Answer:=Answer+'0';
 If Boolean(Bit3 And B) Then
   Answer:=Answer+'1'
 Else
   Answer:=Answer+'0';
 If Boolean(Bit2 And B) Then
   Answer:=Answer+'1'
 Else
   Answer:=Answer+'0';
 If Boolean(Bit1 And B) Then
   Answer:=Answer+'1'
 Else
   Answer:=Answer+'0';
 Byte2Bin:=Answer;
End;

{------------------------------------------------------------------------}

Procedure PrintPage(Var D:DataType;  Start:LongInt; Var Printer:TEXT);
Const
  LineStart = 4;
  LineFinish = 60;
Type
  PrintBuffType = Array [LineStart..LineFinish,1..4] Of Byte;
  PrintBuffPointer = ^PrintBuffType;
Var
  PrintBuff : PrintBuffPointer;
  Count     : Word;
  Error     : Integer;
  X,Y       : Integer;
Begin
  If SizeOf(PrintBuffType)>MaxAvail Then
    Begin
      CloseWindow;
      ErrorMsg('Not enough memory for print buffer');
      Exit;
    End;
  New(PrintBuff);
  FillChar(PrintBuff^,SizeOf(PrintBuffType),0);
  Seek(D.stream,Start-1);
  BlockRead(D.stream,PrintBuff^,SizeOf(PrintBuffType),Count);

  Writeln(Printer,'print out from HEXED version ',versionnumber,' by Graham Ollis');
  Writeln(Printer,'Data File : ',Path2File(D.FN),
          ' Offset : ',Start:11,' $',Long2Str(Start));
  For X:=1 To 80 Do
    Write(Printer,#205);
  Writeln(Printer);
  For Y:=LineStart To LineFinish Do
    Begin
      For X:=1 To 4 Do
        Write(Printer,Byte2Bin(PrintBuff^[Y,X]),' ');
      For X:=1 To 4 Do
        Write(Printer,'$',Byte2Str(PrintBuff^[Y,X]),' ');
      For X:=1 To 4 Do
        Write(Printer,PrintBuff^[Y,X]:3,' ');
      For X:=1 To 4 Do
        If PrintBuff^[Y,X]>31 Then
          Write(Printer,Chr(PrintBuff^[Y,X]))
        Else
          Write(Printer,'.');
      Writeln(Printer);
      If IOResult<>0  Then
        ;
    End;
  Dispose(PrintBuff);
End;

{------------------------------------------------------------------------}

Procedure Print(Var D:DataType);
Var
  Printer:TEXT;
  S:String;
  l:LongInt;
Begin
  OpenWindow(10,10,70,11,ICFG.MsgColor);
  Writeln('Enter file to write to or PRN for printer.');
  Write('> ');
  S:=StringEdit('PRN',58,FileSet);
  CloseWindow;

  If EscExit Then
    Exit;

  Assign(Printer,S);
  Rewrite(Printer);

  OpenWindow(10,10,70,11,ICFG.MsgColor);
  Case Choice(2,'Print page only','Print all file','','','','',10,10,70) Of
    $01 : PrintPage(D,D.X+D.offset,Printer);
    $02 : For l:=0 To FileSize(D.stream) div 224 Do
            PrintPage(D,l*224+1,Printer);
  End;
  CloseWindow;

  Close(Printer);
End;

{======================================================================}

End.
