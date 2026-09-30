(*============================================================================
| res.pas
|   figure out the resoloun of the current text mode.
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$I-}
{$PACKRECORDS 1}

Unit Res;

INTERFACE

{++PROCEDURES++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{++FUNCTIONS+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Var
  Resolution:Byte;

IMPLEMENTATION

Uses
  VConvert,DOS,VCrt;

{----------------------------------------------------------------------}

Function Figure:Byte;  {figure out if there are 50 or 25 lines.}
Var
  S:String;
  I:Integer;
  Num:String;
Begin
  S:=UpString(GetEnv('GRAHAM'));
  If Pos('Y-',S)=0 Then
    Begin
      Figure:=25;
      Exit;
    End;

  Num:='';
  I:=Pos('Y-',S)+2;
  While (S[I]>='0') And (S[I]<='9') Do
    Begin
      Num:=Num+S[I];
      Inc(I);
    End;

  Figure:=StrToInt(Num);
End;

{======================================================================}

Begin
  Resolution:=Figure;
  SetScreenRows(Resolution);
End.
